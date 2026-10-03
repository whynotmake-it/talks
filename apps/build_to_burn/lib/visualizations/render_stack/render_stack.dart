import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:example_design/example_design.dart' show ExampleTheme;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:qr_flutter/qr_flutter.dart';

part 'render_stack_cards.dart';
part 'render_stack_list.dart';
part 'render_stack_overlays.dart';
part 'render_stack_planes.dart';

/// The render stack: widget code at the bottom, pixels at the top, each tier
/// an isometric plane, with a label list on the right. Draws [view].
///
/// The stack builds up one stage at a time: a stage appears as its own flat
/// slide ([RenderStackView.focus]) and then lands on the stack as its plane.
/// Everything that marks tiers (loops, borders, tool spotlights, frames in
/// flight) is drawn beside the label list; the planes light up in sync.
///
/// Changing [view] animates from where everything is. The widget scales to
/// its box, keeping [designSize]'s aspect ratio, and reads its colors from
/// [Palette].
class RenderStack extends StatefulWidget {
  const RenderStack({
    required this.view,
    this.initialView,
    this.tiers = renderStackTiers,
    this.bands = renderStackBands,
    this.caption,
    super.key,
  });

  final RenderStackView view;

  /// When set, the first build jumps to this view and animates to [view]
  /// from there: a slide continuing where the previous slide left off.
  final RenderStackView? initialView;

  /// The tiers, bottom to top.
  final List<StackTier> tiers;

  final List<StackBand> bands;

  /// Shown at the bottom left, if set.
  final String? caption;

  static const designSize = Size(2000, 900);

  @override
  State<RenderStack> createState() => _RenderStackState();
}

class _TierTracks {
  _TierTracks(int tier)
    : presence = Track(.single, initial: 0, debugLabel: 'Tier $tier'),
      expand = Track(.single, initial: 0, debugLabel: 'Tier $tier expanded'),
      light = Track(.single, initial: 0, debugLabel: 'Tier $tier light'),
      card = Track(.single, initial: 0, debugLabel: 'Stage $tier slide'),
      shrink = Track(.single, initial: 0, debugLabel: 'Stage $tier shrink'),
      flights = [
        for (var slot = 0; slot < 4; slot++)
          Track(.single, initial: 0, debugLabel: 'Stage $tier corner $slot'),
      ];

  final Track<double> presence;
  final Track<double> expand;
  final Track<double> light;

  /// The stage slide's visibility.
  final Track<double> card;

  /// Landing, part one: 0 flat, 1 shrunk to the compact square (and
  /// simplified to the plane face).
  final Track<double> shrink;

  /// Landing, part two: each corner's flight from the compact square (0) to
  /// its plane vertex (1), by the order the corners leave in, which
  /// [_StageCard] picks.
  final List<Track<double>> flights;
}

/// Where a [RenderStack] left off, so the next one, on the neighbouring deck
/// slide, picks up mid-motion instead of restarting.
class _Handoff {
  _Handoff(this.owner);

  final Object owner;

  /// Each track's value and velocity (per second), by key.
  final values = <String, ({double value, double velocity})>{};
  Duration stamp = Duration.zero;
  HookPhone? phone;
  TilePhase? tiles;
  FramesInFlight? frames;

  /// A handoff older than this came from a stack that is long gone.
  static const maxAge = Duration(milliseconds: 500);
}

class _RenderStackState extends State<RenderStack> {
  final _tiers = <int, _TierTracks>{};
  final _borders = {
    for (final border in StackBorder.values)
      border: Track<double>(.single, initial: 0, debugLabel: '$border'),
  };
  final _pixels = Track<double>(.single, initial: 0, debugLabel: 'Pixels');
  final _dim = Track<double>(.single, initial: 0, debugLabel: 'Hook phone');
  final _compress = Track<double>(
    .single,
    initial: 0,
    debugLabel: 'Stack compressed',
  );
  final _wide = Track<double>(.single, initial: 0, debugLabel: 'Card wide');
  final _colors = Track<double>(
    .single,
    initial: 0,
    debugLabel: 'Widget colors',
  );
  final _tiles = Track<double>(.single, initial: 0, debugLabel: 'Tiles');
  final _dram = Track<double>(.single, initial: 0, debugLabel: 'DRAM');
  final _feedback = Track<double>(.single, initial: 0, debugLabel: 'Feedback');
  final _frames = Track<double>(.single, initial: 0, debugLabel: 'Frames');
  final _bands = Track<double>(.single, initial: 0, debugLabel: 'Bands');
  final _docs = Track<double>(.single, initial: 0, debugLabel: 'Docs dialog');

  /// The last phone, tile phase and frames shown, kept so they can fade out.
  HookPhone? _lastPhone;
  TilePhase? _lastTiles;
  FramesInFlight? _lastFrames;

  /// The first build starts every track from [_start] (or jumps straight to
  /// its view): a slide that starts with part of the stack built shouldn't
  /// replay the build-up.
  bool _first = true;

  /// Where each track starts on the first build, by key. Null jumps to the
  /// view.
  Map<String, ({double value, double velocity})>? _start;

  /// Every track's value as last drawn, by key.
  final _seen = <String, double>{};

  /// The most recently created stack: the only one that writes [_handoff].
  static _RenderStackState? _newest;
  static _Handoff? _handoff;

  static const _motion = Motion.smoothSpring();
  static const _snappy = Motion.snappySpring();

  /// The landing: the card snaps to the compact square, then its corners
  /// snap onto the plane one after another.
  static const _shrink = Motion.snappySpring(
    duration: Duration(milliseconds: 380),
  );
  static const _flight = Motion.snappySpring(
    duration: Duration(milliseconds: 420),
    extraBounce: .05,
  );

  /// When the first corner leaves the compact square, and how far apart
  /// the corners leave.
  static const _flightDelay = Duration(milliseconds: 300);
  static const _flightStagger = Duration(milliseconds: 75);

  /// How long the next stage's card waits while the previous one lands:
  /// until the last corner has arrived, then a beat more.
  static const _cardInDelay = Duration(milliseconds: 1350);

  /// How long a card unlanding waits for its corners to get back to the
  /// compact square before it unfolds.
  static const _unshrinkDelay = Duration(milliseconds: 220);

  _TierTracks _tracksOf(int tier) =>
      _tiers.putIfAbsent(tier, () => _TierTracks(tier));

  /// Every track with its key, shared between stacks for the handoff.
  late final Map<String, Track<double>> _keyed = {
    for (final tier in widget.tiers) ...{
      'presence ${tier.number}': _tracksOf(tier.number).presence,
      'expand ${tier.number}': _tracksOf(tier.number).expand,
      'light ${tier.number}': _tracksOf(tier.number).light,
      'card ${tier.number}': _tracksOf(tier.number).card,
      'shrink ${tier.number}': _tracksOf(tier.number).shrink,
      for (var slot = 0; slot < 4; slot++)
        'flight ${tier.number} $slot': _tracksOf(tier.number).flights[slot],
    },
    for (final MapEntry(key: border, value: track) in _borders.entries)
      'border ${border.name}': track,
    'pixels': _pixels,
    'dim': _dim,
    'compress': _compress,
    'wide': _wide,
    'colors': _colors,
    'tiles': _tiles,
    'dram': _dram,
    'feedback': _feedback,
    'frames': _frames,
    'bands': _bands,
    'docs': _docs,
  };

  /// Each track's resting value in [view], by key.
  Map<String, double> _targets(RenderStackView view) {
    final light = {...view.light, ...?view.spotlight?.tiers};
    return {
      for (final tier in widget.tiers) ...{
        'presence ${tier.number}': view.showsTier(tier.number, tier.band)
            ? 1.0
            : 0.0,
        'expand ${tier.number}': view.expanded.contains(tier.number)
            ? 1.0
            : 0.0,
        'light ${tier.number}': light[tier.number] ?? TierLight.off,
        'card ${tier.number}': _cardTarget(view, tier),
        // A tier on the stack has landed; any other card waits flat.
        for (final key in [
          'shrink ${tier.number}',
          for (var slot = 0; slot < 4; slot++) 'flight ${tier.number} $slot',
        ])
          key: view.showsTier(tier.number, tier.band) ? 1.0 : 0.0,
      },
      for (final border in _borders.keys)
        'border ${border.name}': view.borders.contains(border) ? 1.0 : 0.0,
      'pixels': view.showPixels ? 1.0 : 0.0,
      'dim': view.phone != null ? 1.0 : 0.0,
      'compress': view.focus != null ? 1.0 : 0.0,
      // Plane 1's card is the whole picture until a phone or plane 2 joins.
      'wide': view.focus == 1 && view.phone == null ? 1.0 : 0.0,
      'colors': view.widgetColors ? 1.0 : 0.0,
      'tiles': view.tiles != null ? 1.0 : 0.0,
      'dram': view.tiles == null || view.tiles == TilePhase.fill ? 0.0 : 1.0,
      'feedback': view.feedback ? 1.0 : 0.0,
      'frames': view.frames != null ? 1.0 : 0.0,
      'bands': view.showBands ? 1.0 : 0.0,
      'docs': view.docs ? 1.0 : 0.0,
    };
  }

  static final _clock = Stopwatch()..start();

  /// The focus card shows. So does a card still landing on a plane that
  /// stays on the stack: skipped past mid-flight, it finishes its flight
  /// and hands over to the plane instead of fading out in the air.
  double _cardTarget(RenderStackView view, StackTier tier) {
    if (view.focus == tier.number) return 1;
    if (!view.showsTier(tier.number, tier.band)) return 0;
    double? now(String key) {
      if (!_first) return _seen[key];
      final start = _start?[key];
      return start?.value;
    }

    final card = now('card ${tier.number}') ?? 0;
    final landed = [
      'shrink ${tier.number}',
      for (var slot = 0; slot < 4; slot++) 'flight ${tier.number} $slot',
    ].every((key) => ((now(key) ?? 1) - 1).abs() < .005);
    return card > .01 && !landed ? 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialView case final entry?) {
      final handoff = _handoff;
      final now = _clock.elapsed;
      if (handoff != null &&
          handoff.owner != this &&
          now - handoff.stamp < _Handoff.maxAge) {
        // Continue exactly where the previous slide's stack is right now.
        _start = Map.of(handoff.values);
        _lastPhone = handoff.phone;
        _lastTiles = handoff.tiles;
        _lastFrames = handoff.frames;
      } else {
        // No live stack to continue: start from the entry view at rest.
        _start = {
          for (final MapEntry(:key, :value) in _targets(entry).entries)
            key: (value: value, velocity: 0.0),
        };
        _lastPhone = entry.phone;
        _lastTiles = entry.tiles;
        _lastFrames = entry.frames;
      }
    }
    _newest = this;
  }

  @override
  void didUpdateWidget(RenderStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _first = false;
  }

  @override
  void dispose() {
    if (_newest == this) _newest = null;
    super.dispose();
  }

  /// Records this frame's values for the next slide's stack, with velocities
  /// from the change since the last frame.
  void _record(TrackValueReader value) {
    for (final MapEntry(:key, value: track) in _keyed.entries) {
      _seen[key] = value(track);
    }
    if (_newest != this) return;
    final now = _clock.elapsed;
    final previous = _handoff?.owner == this ? _handoff : null;
    final dt = previous == null
        ? 0.0
        : (now - previous.stamp).inMicroseconds / 1e6;
    // A second build in the same frame: refresh the values, keep the
    // velocities and the stamp they were measured against.
    final sameFrame = previous != null && dt < .004;
    final handoff = _Handoff(this)
      ..stamp = sameFrame ? previous.stamp : now
      ..phone = _lastPhone
      ..tiles = _lastTiles
      ..frames = _lastFrames;
    for (final MapEntry(:key, value: track) in _keyed.entries) {
      final x = value(track);
      final last = previous?.values[key];
      final velocity = last == null
          ? 0.0
          : sameFrame
          ? last.velocity
          : (x - last.value) / dt;
      handoff.values[key] = (value: x, velocity: velocity);
    }
    _handoff = handoff;
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    _lastPhone = view.phone ?? _lastPhone;
    _lastTiles = view.tiles ?? _lastTiles;
    _lastFrames = view.frames ?? _lastFrames;
    final targets = _targets(view);
    // A card other than the focus still showing is landing on its plane.
    final landing = widget.tiers.any(
      (tier) =>
          view.focus != tier.number && targets['card ${tier.number}'] == 1,
    );
    final start = _first ? _start : null;

    /// Animates [key] to its target. [delay] holds it first, but only for a
    /// track at rest at the far end, so a retarget never stalls one that's
    /// already moving.
    TrackAnimation<double> animate(
      String key,
      Motion motion, {
      Duration delay = Duration.zero,
    }) {
      final track = _keyed[key]!;
      final target = targets[key]!;
      final from = _first ? (start ?? const {})[key] : null;
      if (_first && from == null) {
        return track.to(target, from: target, motion: const Motion.none());
      }
      final current = from?.value ?? _seen[key] ?? target;
      final wait =
          delay > Duration.zero &&
          (current - (1 - target)).abs() < .01 &&
          (from?.velocity ?? 0).abs() < .01;
      return track(
        [if (wait) TrackStep.hold(delay), TrackStep.to(target, motion: motion)],
        from: from?.value,
        withVelocity: from?.velocity,
      );
    }

    return FittedBox(
      child: SizedBox.fromSize(
        size: RenderStack.designSize,
        child: TrackBuilder(
          debugLabel: 'Render stack',
          animations: [
            for (final tier in widget.tiers) ...[
              animate('presence ${tier.number}', _motion),
              animate('expand ${tier.number}', _motion),
              animate('light ${tier.number}', _motion),
              animate(
                'card ${tier.number}',
                _snappy,
                delay: view.focus == tier.number && landing
                    ? _cardInDelay
                    : Duration.zero,
              ),
              animate(
                'shrink ${tier.number}',
                _shrink,
                delay: targets['shrink ${tier.number}'] == 0
                    ? _unshrinkDelay
                    : Duration.zero,
              ),
              for (var slot = 0; slot < 4; slot++)
                animate(
                  'flight ${tier.number} $slot',
                  _flight,
                  delay: targets['flight ${tier.number} $slot'] == 1
                      ? _flightDelay + _flightStagger * slot
                      : Duration.zero,
                ),
            ],
            for (final border in _borders.keys)
              animate('border ${border.name}', _motion),
            for (final key in [
              'pixels',
              'dim',
              'compress',
              'wide',
              'colors',
              'tiles',
              'dram',
              'feedback',
              'frames',
              'bands',
              'docs',
            ])
              animate(key, _motion),
          ],
          builder: (context, value, _) {
            _record(value);
            double v(Track<double> track) => value(track).clamp(0.0, 1.0);
            return _StackPicture(
              tiers: widget.tiers,
              bands: widget.bands,
              view: view,
              values: {
                for (final tier in widget.tiers)
                  tier.number: _TierValues(
                    presence: v(_tracksOf(tier.number).presence),
                    expand: v(_tracksOf(tier.number).expand),
                    light: v(_tracksOf(tier.number).light),
                    card: v(_tracksOf(tier.number).card),
                    // Unclamped, so the snappy springs can overshoot.
                    shrink: value(_tracksOf(tier.number).shrink),
                    flights: [
                      for (final flight in _tracksOf(tier.number).flights)
                        value(flight),
                    ],
                  ),
              },
              borders: {
                for (final MapEntry(key: border, value: track)
                    in _borders.entries)
                  border: v(track),
              },
              pixels: v(_pixels),
              dim: v(_dim),
              compress: v(_compress),
              wide: v(_wide),
              widgetColors: v(_colors),
              tiles: v(_tiles),
              dram: v(_dram),
              feedback: v(_feedback),
              frames: v(_frames),
              bandsSummary: v(_bands),
              docs: v(_docs),
              phone: _lastPhone,
              tilePhase: view.tiles ?? _lastTiles,
              framesInFlight: view.frames ?? _lastFrames,
              caption: widget.caption,
            );
          },
        ),
      ),
    );
  }
}

@immutable
class _TierValues {
  const _TierValues({
    required this.presence,
    required this.expand,
    required this.light,
    required this.card,
    required this.shrink,
    required this.flights,
  });

  final double presence;
  final double expand;
  final double light;
  final double card;
  final double shrink;
  final List<double> flights;

  /// Whether the card sits on its plane: shrunk, every corner arrived.
  bool get landed =>
      (shrink - 1).abs() < .005 &&
      flights.every((flight) => (flight - 1).abs() < .005);
}

// Geometry, in design pixels.
const _plane = 280.0;
const _cos30 = 0.8660254;
const _halfWidth = _plane * _cos30;
const _centerX = 540.0;
const _baseY = 590.0;
const _topMargin = 56.0;
const _tierGap = 14.0;
const _bandGap = 70.0;
const _connectorGap = 44.0;
const _expandGap = 190.0;
const _capGap = 18.0;

/// The label list and the gutter beside it.
const _rowsLeft = 1040.0;
const _rowsRight = 1440.0;
const _gutterLeft = 1456.0;
const _slotWidth = 24.0;

/// The stage slide, flat.
const _cardRect = Rect.fromLTWH(30, 10, 1940, 870);

/// The stage slide's left column while the compressed stack fills the right
/// (also shared with the hook's phone and vote).
const _focusCardRect = Rect.fromLTWH(30, 10, 1140, 870);

/// The side of the compact square a landing card shrinks to before its
/// corners fly to the plane.
const _compactSide = 420.0;

/// The whole stack, compressed into the right column while a stage slide is
/// up: scaled about [_compressPivot], then shifted right by [_compressDX].
const _compressScale = .55;
const _compressDX = 660.0;
const _compressPivot = Offset(960, 430);

/// Maps stack coordinates to slide coordinates at [compress] 0..1 and
/// vertical [shift]. Compose: shift down first, then scale about the pivot,
/// then shift right.
Matrix4 _stackTransform(double compress, double shift) => Matrix4.identity()
  ..translateByDouble(lerpDouble(0, _compressDX, compress)!, 0, 0, 1)
  ..translateByDouble(_compressPivot.dx, _compressPivot.dy, 0, 1)
  ..scaleByDouble(
    lerpDouble(1, _compressScale, compress)!,
    lerpDouble(1, _compressScale, compress)!,
    1,
    1,
  )
  ..translateByDouble(-_compressPivot.dx, -_compressPivot.dy, 0, 1)
  ..translateByDouble(0, shift, 0, 1);

/// A plane's rhombus on the slide (top, right, bottom, left vertices, which
/// are its face's topLeft, topRight, bottomRight and bottomLeft) for a plane
/// at [top] in the stack.
List<Offset> _planeQuad(double top, double compress, double shift) {
  final transform = _stackTransform(compress, shift);
  Offset map(double x, double y) =>
      MatrixUtils.transformPoint(transform, Offset(x, y));
  return [
    map(_centerX, top),
    map(_centerX + _halfWidth, top + _plane / 2),
    map(_centerX, top + _plane),
    map(_centerX - _halfWidth, top + _plane / 2),
  ];
}

/// Maps a [src]-sized rect at the origin onto the quad [dst] (topLeft,
/// topRight, bottomRight, bottomLeft) as a projective transform, so the four
/// corners can move independently.
Matrix4 _quadMatrix(Size src, List<Offset> dst) {
  final (x0, y0) = (dst[0].dx, dst[0].dy);
  final (x1, y1) = (dst[1].dx, dst[1].dy);
  final (x2, y2) = (dst[2].dx, dst[2].dy);
  final (x3, y3) = (dst[3].dx, dst[3].dy);
  // Unit-square → quad homography; the src rect is pre-scaled to the unit
  // square by dividing its dimensions into the coefficients.
  final sx = x0 - x1 + x2 - x3;
  final sy = y0 - y1 + y2 - y3;
  final ux = x1 - x2;
  final vx = x3 - x2;
  final uy = y1 - y2;
  final vy = y3 - y2;
  final den = ux * vy - vx * uy;
  var g = 0.0;
  var h = 0.0;
  if (den.abs() > 1e-9) {
    g = (sx * vy - vx * sy) / den;
    h = (ux * sy - sx * uy) / den;
  }
  final a = (x1 - x0 + g * x1) / src.width;
  final b = (x3 - x0 + h * x3) / src.height;
  final d = (y1 - y0 + g * y1) / src.width;
  final e = (y3 - y0 + h * y3) / src.height;
  return Matrix4(
    a,
    d,
    0,
    g / src.width, //
    b,
    e,
    0,
    h / src.height,
    0,
    0,
    1,
    0,
    x0,
    y0,
    0,
    1,
  );
}

/// Center y of list row [row] with no focus: row 0 is the vsync, rows 1-9
/// the tiers.
double _rowY(double row) => 818 - row * 78;

@immutable
class _Rows {
  const _Rows();

  double y(double row) => _rowY(row);
}

/// Moves the stack and the list together so their visible extent is
/// centered vertically. Weighted by [presenceOf], so it glides as planes
/// land.
double _centerShift(
  _Layout layout,
  _Rows rows,
  double Function(StackTier) presenceOf, {
  bool arcOrigin = false,
}) {
  double? top;
  double? bottom;
  double? rowsTop;
  for (final (index, tier) in layout.tiers.indexed) {
    final p = presenceOf(tier);
    if (p < .01) continue;
    final planeTop = layout.top(index);
    top = top == null ? planeTop : math.min(top, planeTop);
    bottom = math.max(bottom ?? 0, planeTop + _plane);
    final rowTop = rows.y(tier.number.toDouble()) - 30;
    rowsTop = rowsTop == null
        ? rowTop
        : lerpDouble(rowsTop, math.min(rowsTop, rowTop), p);
  }
  if (top == null || bottom == null || rowsTop == null) return 0;
  top = math.min(top, rowsTop);
  final lowestRow = layout.tiers.firstWhere((tier) => presenceOf(tier) > .01);
  var rowsBottom = rows.y(lowestRow.number.toDouble()) + 30;
  if (arcOrigin) {
    rowsBottom = math.max(rowsBottom, rows.y(0) + 20);
  }
  bottom = math.max(bottom, rowsBottom);
  final height = RenderStack.designSize.height;
  final ideal = height / 2 - (top + bottom) / 2;
  return ideal.clamp(20 - top, math.max(20 - top, height - 20 - bottom));
}

/// Maps a flat square onto an isometric rhombus with its top vertex at the
/// origin.
final _isometric = Matrix4(
  _cos30,
  .5,
  0,
  0, //
  -_cos30,
  .5,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1,
);

/// Where every tier sits this frame.
class _Layout {
  _Layout(
    this.tiers,
    this.bands,
    this.presence,
    this.expand, {
    this.spread = 1,
  }) {
    var offset = 0.0;
    final raw = <double>[];
    for (final (index, tier) in tiers.indexed) {
      if (index > 0) {
        final below = tiers[index - 1];
        final gap = _gapBetween(below, tier);
        offset +=
            gap * spread * _presenceOf(tier) +
            expand[below.number]! * _expandGap;
      }
      raw.add(offset);
    }
    final capOffset = offset + _capGap * _presenceOf(tiers.last);
    const available = _baseY - _topMargin;
    final scale = capOffset > available ? available / capOffset : 1.0;
    offsets = [for (final value in raw) value * scale];
    cap = _baseY - capOffset * scale;
  }

  final List<StackTier> tiers;
  final List<StackBand> bands;
  final Map<int, double> presence;
  final Map<int, double> expand;

  /// Multiplies the gaps between planes, e.g. to give each band room.
  final double spread;

  late final List<double> offsets;
  late final double cap;

  StackBand _band(String id) => bands.firstWhere((band) => band.id == id);

  double _presenceOf(StackTier tier) => presence[tier.number] ?? 0;

  double _gapBetween(StackTier below, StackTier above) {
    if (below.band == above.band) return _tierGap;
    if (_band(below.band).connector || _band(above.band).connector) {
      return _connectorGap;
    }
    return _bandGap;
  }

  /// Top vertex y of the tier at [index].
  double top(int index) => _baseY - offsets[index];

  /// Center y of the tier at [index].
  double center(int index) => top(index) + _plane / 2;

  int indexOf(int number) => tiers.indexWhere((tier) => tier.number == number);
}

class _StackPicture extends StatelessWidget {
  const _StackPicture({
    required this.tiers,
    required this.bands,
    required this.view,
    required this.values,
    required this.borders,
    required this.pixels,
    required this.dim,
    required this.compress,
    required this.widgetColors,
    required this.tiles,
    required this.dram,
    required this.feedback,
    required this.frames,
    required this.bandsSummary,
    required this.docs,
    required this.phone,
    required this.tilePhase,
    required this.framesInFlight,
    required this.wide,
    required this.caption,
  });

  final List<StackTier> tiers;
  final List<StackBand> bands;
  final RenderStackView view;
  final Map<int, _TierValues> values;
  final Map<StackBorder, double> borders;
  final double pixels;
  final double dim;

  /// 0 full size stack, 1 compressed into the right column.
  final double compress;
  final double widgetColors;
  final double tiles;
  final double dram;
  final double feedback;
  final double frames;
  final double bandsSummary;

  /// The docs dialog's presence, 0..1.
  final double docs;
  final HookPhone? phone;
  final TilePhase? tilePhase;
  final FramesInFlight? framesInFlight;

  /// 0 the focused card rests in the left column, 1 across the slide.
  final double wide;
  final String? caption;

  StackBand _band(String id) => bands.firstWhere((band) => band.id == id);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final spread = 1 + 1.6 * frames;
    final layout = _Layout(
      tiers,
      bands,
      {
        for (final tier in tiers) tier.number: values[tier.number]!.presence,
      },
      {for (final tier in tiers) tier.number: values[tier.number]!.expand},
      spread: spread,
    );
    final rows = _rowsFor();
    final shift = _centerShift(
      layout,
      rows,
      (tier) => values[tier.number]!.presence,
      arcOrigin: view.arcs.any((arc) => arc.origin.isNotEmpty),
    );
    final lowestExpanded = [
      for (final (index, tier) in tiers.indexed)
        if (values[tier.number]!.expand > .05) index,
    ].fold<int?>(null, (lowest, index) => lowest ?? index);
    final stackOpacity = 1 - .9 * dim;
    final flat = Rect.lerp(_focusCardRect, _cardRect, wide)!;
    // Where a landing card goes: its plane, as if it were already there.
    // Only cards that have started landing count; a flat card waiting on
    // its slide claims no room, or the stack would shift under the plane
    // it's landing on.
    double targetPresence(StackTier tier) {
      final v = values[tier.number]!;
      return v.shrink > .001 ? 1 : v.presence;
    }

    final target = _Layout(
      tiers,
      bands,
      {for (final tier in tiers) tier.number: targetPresence(tier)},
      {for (final tier in tiers) tier.number: values[tier.number]!.expand},
      spread: spread,
    );
    final targetShift = _centerShift(
      target,
      rows,
      targetPresence,
      arcOrigin: view.arcs.any((arc) => arc.origin.isNotEmpty),
    );

    return DefaultTextStyle(
      style: archivo(32, color: p.textSecondary),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform(
              transform: _stackTransform(compress, shift),
              child: Opacity(
                opacity: stackOpacity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final (index, tier) in tiers.indexed)
                      if (_planeVisible(tier))
                        _TierPlane(
                          tier: tier,
                          band: _band(tier.band),
                          top: layout.top(index),
                          presence: values[tier.number]!.presence,
                          expand: values[tier.number]!.expand,
                          light: values[tier.number]!.light,
                          translucent:
                              lowestExpanded != null && index > lowestExpanded,
                          emphasis: view.emphasis,
                          pixels: tier.detail is ScreenDetail ? pixels : 0,
                          tiles: tier.number == 8 ? tiles : 0,
                          tilePhase: tilePhase,
                        ),
                    if (values[tiers.last.number]!.presence > .01)
                      _cap(p, layout, values[tiers.last.number]!.presence),
                    if (frames > .01 && framesInFlight != null)
                      _FrameTokens(
                        layout: layout,
                        presence: frames,
                        frames: framesInFlight!,
                      ),
                    if (frames > .01 &&
                        (framesInFlight?.limits ?? false) &&
                        layout.indexOf(5) >= 0)
                      _PipelineSlots(
                        presence: frames,
                        tierCenter: layout.center(layout.indexOf(5)),
                      ),
                    if (dram > .01 &&
                        tilePhase != null &&
                        layout.indexOf(8) >= 0)
                      _DramOverlay(
                        phase: tilePhase!,
                        presence: dram,
                        tierCenter: layout.center(layout.indexOf(8)),
                      ),
                    if (_detailCardTier() case final index?)
                      _DetailCard(
                        tier: tiers[index],
                        emphasis: view.emphasis,
                        presence: values[tiers[index].number]!.expand,
                        anchor: Offset(
                          _centerX - _halfWidth,
                          layout.center(index),
                        ),
                        color: _lightColors(
                          p,
                          math.max(
                            values[tiers[index].number]!.light,
                            TierLight.dim,
                          ),
                        ).text,
                      ),
                    _LabelList(
                      tiers: tiers,
                      bands: bands,
                      view: view,
                      values: values,
                      layout: layout,
                      rows: rows,
                      frames: frames,
                      opacity: 1 - dim,
                    ),
                    _Gutter(
                      tiers: tiers,
                      bands: bands,
                      view: view,
                      values: values,
                      rows: rows,
                      borders: borders,
                      feedback: feedback,
                      frames: frames,
                      bandsSummary: bandsSummary,
                      framesInFlight: framesInFlight,
                      opacity: 1 - dim,
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final (index, tier) in tiers.indexed)
            if (_cardVisible(tier))
              _StageCard(
                // The focus slide can show other content than its plane.
                tier: view.focus == tier.number && view.focusDetail != null
                    ? tier.withDetail(view.focusDetail)
                    : tier,
                band: _band(tier.band),
                card: values[tier.number]!.card,
                shrink: values[tier.number]!.shrink,
                flights: values[tier.number]!.flights,
                // Only the code card widens; the stage cards keep the column.
                flat: tier.number == 1 ? flat : _focusCardRect,
                plane: _planeQuad(target.top(index), compress, targetShift),
                translucent: lowestExpanded != null && index > lowestExpanded,
                expand: values[tier.number]!.expand,
                widgetColors: widgetColors,
                light: values[tier.number]!.light,
                emphasis: view.emphasis,
                pixels: tier.detail is ScreenDetail ? pixels : 0,
                tiles: tier.number == 8 ? tiles : 0,
                tilePhase: tilePhase,
              ),
          if (dim > .01 && phone != null)
            _HookPhoneOverlay(phone: phone!, presence: dim),
          if (docs > .01) _DocsOverlay(presence: docs),
          if (caption case final caption?)
            Positioned(
              left: 40,
              top: 760,
              width: 1920,
              child: Text(
                caption,
                style: archivo(32, weight: 500, height: 1.25, color: p.text),
              ),
            ),
        ],
      ),
    );
  }

  _Rows _rowsFor() => const _Rows();

  /// Whether the focused card has come to rest on its plane, where the
  /// plane below draws the identical picture.
  bool _settled(StackTier tier) {
    final v = values[tier.number]!;
    return v.card <= .01 || (v.landed && v.presence > .995);
  }

  /// A stage slide covers its plane until it has landed.
  bool _cardVisible(StackTier tier) {
    final v = values[tier.number]!;
    return v.card > .01 && !_settled(tier);
  }

  bool _planeVisible(StackTier tier) {
    final v = values[tier.number]!;
    if (v.presence < .005) return false;
    return !(v.card > .01 && !_settled(tier));
  }

  /// The expanded tier whose readable detail card is shown.
  int? _detailCardTier() {
    int? best;
    for (final (index, tier) in tiers.indexed) {
      if (tier.detail == null || tier.detail is ScreenDetail) continue;
      final value = values[tier.number]!.expand;
      if (value < .01) continue;
      if (best == null || value > values[tiers[best].number]!.expand) {
        best = index;
      }
    }
    return best;
  }

  Widget _cap(Palette p, _Layout layout, double opacity) => Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _RhombusPainter(
            top: Offset(_centerX, layout.cap),
            stroke: p.borderStrong,
            dashed: true,
          ),
        ),
      ),
    ),
  );
}
