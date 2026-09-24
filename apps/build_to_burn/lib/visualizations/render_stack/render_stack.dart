import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:example_design/example_design.dart' show ExampleTheme;
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

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
    this.tiers = renderStackTiers,
    this.bands = renderStackBands,
    this.caption,
    super.key,
  });

  final RenderStackView view;

  /// The tiers, bottom to top.
  final List<StackTier> tiers;

  final List<StackBand> bands;

  /// Shown at the bottom left, if set.
  final String? caption;

  static const designSize = Size(1600, 900);

  @override
  State<RenderStack> createState() => _RenderStackState();
}

class _TierTracks {
  _TierTracks(int tier)
    : presence = Track(.single, initial: 0, debugLabel: 'Tier $tier'),
      expand = Track(.single, initial: 0, debugLabel: 'Tier $tier expanded'),
      light = Track(.single, initial: 0, debugLabel: 'Tier $tier light'),
      card = Track(.single, initial: 0, debugLabel: 'Stage $tier slide'),
      morph = Track(.single, initial: 0, debugLabel: 'Stage $tier landing');

  final Track<double> presence;
  final Track<double> expand;
  final Track<double> light;

  /// The stage slide's visibility.
  final Track<double> card;

  /// 0 while the stage slide is flat, 1 once it has landed as a plane.
  final Track<double> morph;
}

class _RenderStackState extends State<RenderStack> {
  final _tiers = <int, _TierTracks>{};
  final _borders = {
    for (final border in StackBorder.values)
      border: Track<double>(.single, initial: 0, debugLabel: '$border'),
  };
  final _pixels = Track<double>(.single, initial: 0, debugLabel: 'Pixels');
  final _dim = Track<double>(.single, initial: 0, debugLabel: 'Hook phone');
  final _tiles = Track<double>(.single, initial: 0, debugLabel: 'Tiles');
  final _dram = Track<double>(.single, initial: 0, debugLabel: 'DRAM');
  final _feedback = Track<double>(.single, initial: 0, debugLabel: 'Feedback');
  final _frames = Track<double>(.single, initial: 0, debugLabel: 'Frames');
  final _bands = Track<double>(.single, initial: 0, debugLabel: 'Bands');

  /// The last phone, tile phase and frames shown, kept so they can fade out.
  HookPhone? _lastPhone;
  TilePhase? _lastTiles;
  FramesInFlight? _lastFrames;

  /// The first build jumps straight to its view: a slide that starts with
  /// part of the stack built shouldn't replay the build-up.
  bool _first = true;

  static const _motion = Motion.smoothSpring();
  static const _landing = Motion.curved(
    Duration(milliseconds: 1400),
    easeInOut,
  );
  static const _instant = Motion.linear(Duration(milliseconds: 1));
  static const _tileRun = Motion.linear(Duration(milliseconds: 1400));

  _TierTracks _tracksOf(int tier) =>
      _tiers.putIfAbsent(tier, () => _TierTracks(tier));

  @override
  void didUpdateWidget(RenderStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _first = false;
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    _lastPhone = view.phone ?? _lastPhone;
    _lastTiles = view.tiles ?? _lastTiles;
    _lastFrames = view.frames ?? _lastFrames;
    final light = {...view.light, ...?view.spotlight?.tiers};
    Motion m(Motion motion) => _first ? _instant : motion;

    return FittedBox(
      child: SizedBox.fromSize(
        size: RenderStack.designSize,
        child: TrackBuilder(
          debugLabel: 'Render stack',
          animations: [
            for (final tier in widget.tiers) ...[
              _tracksOf(tier.number).presence.to(
                view.showsTier(tier.number, tier.band) ? 1 : 0,
                motion: m(_motion),
              ),
              _tracksOf(tier.number).expand.to(
                view.expanded.contains(tier.number) ? 1 : 0,
                motion: m(_motion),
              ),
              _tracksOf(tier.number).light.to(
                light[tier.number] ?? TierLight.off,
                motion: m(_motion),
              ),
              _tracksOf(tier.number).card.to(
                view.focus == tier.number ? 1 : 0,
                motion: m(_motion),
              ),
              _tracksOf(tier.number).morph.to(
                _morphTarget(tier.number, view),
                motion: m(_landing),
              ),
            ],
            for (final MapEntry(key: border, value: track) in _borders.entries)
              track.to(
                view.borders.contains(border) ? 1 : 0,
                motion: m(_motion),
              ),
            _pixels.to(view.showPixels ? 1 : 0, motion: m(_motion)),
            _dim.to(view.phone != null ? 1 : 0, motion: m(_motion)),
            _tiles.to(view.tiles != null ? 1 : 0, motion: m(_tileRun)),
            _dram.to(
              view.tiles == null || view.tiles == TilePhase.fill ? 0 : 1,
              motion: m(_motion),
            ),
            _feedback.to(view.feedback ? 1 : 0, motion: m(_motion)),
            _frames.to(view.frames != null ? 1 : 0, motion: m(_motion)),
            _bands.to(view.showBands ? 1 : 0, motion: m(_motion)),
          ],
          builder: (context, value, _) {
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
                    morph: v(_tracksOf(tier.number).morph),
                  ),
              },
              borders: {
                for (final MapEntry(key: border, value: track)
                    in _borders.entries)
                  border: v(track),
              },
              pixels: v(_pixels),
              dim: v(_dim),
              tiles: v(_tiles),
              dram: v(_dram),
              feedback: v(_feedback),
              frames: v(_frames),
              bandsSummary: v(_bands),
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

  /// Tiers below the focus have landed; the focus lands once `landed`.
  static double _morphTarget(int tier, RenderStackView view) {
    final focus = view.focus;
    if (focus == null) return 1;
    if (tier < focus) return 1;
    if (tier == focus) return view.landed ? 1 : 0;
    return 0;
  }
}

@immutable
class _TierValues {
  const _TierValues({
    required this.presence,
    required this.expand,
    required this.light,
    required this.card,
    required this.morph,
  });

  final double presence;
  final double expand;
  final double light;
  final double card;
  final double morph;
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
const _rowsRight = 1330.0;
const _gutterLeft = 1346.0;
const _slotWidth = 24.0;

/// The stage slide, flat.
const _cardRect = Rect.fromLTWH(30, 10, 1540, 870);

/// Center y of list row [row]: row 0 is the vsync, rows 1-9 the tiers.
double _rowY(double row) => 818 - row * 78;

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
  _Layout(this.tiers, this.bands, this.presence, this.expand) {
    var offset = 0.0;
    final raw = <double>[];
    for (final (index, tier) in tiers.indexed) {
      if (index > 0) {
        final below = tiers[index - 1];
        final gap = _gapBetween(below, tier);
        offset += gap * _presenceOf(tier) + expand[below.number]! * _expandGap;
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
    required this.tiles,
    required this.dram,
    required this.feedback,
    required this.frames,
    required this.bandsSummary,
    required this.phone,
    required this.tilePhase,
    required this.framesInFlight,
    required this.caption,
  });

  final List<StackTier> tiers;
  final List<StackBand> bands;
  final RenderStackView view;
  final Map<int, _TierValues> values;
  final Map<StackBorder, double> borders;
  final double pixels;
  final double dim;
  final double tiles;
  final double dram;
  final double feedback;
  final double frames;
  final double bandsSummary;
  final HookPhone? phone;
  final TilePhase? tilePhase;
  final FramesInFlight? framesInFlight;
  final String? caption;

  StackBand _band(String id) => bands.firstWhere((band) => band.id == id);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final layout = _Layout(
      tiers,
      bands,
      {
        for (final tier in tiers) tier.number: values[tier.number]!.presence,
      },
      {for (final tier in tiers) tier.number: values[tier.number]!.expand},
    );
    // Where a landing slide goes: its plane, as if it were already there.
    final target = _Layout(
      tiers,
      bands,
      {
        for (final tier in tiers)
          tier.number: math.max(
            values[tier.number]!.presence,
            values[tier.number]!.card,
          ),
      },
      {for (final tier in tiers) tier.number: values[tier.number]!.expand},
    );
    final lowestExpanded = [
      for (final (index, tier) in tiers.indexed)
        if (values[tier.number]!.expand > .05) index,
    ].fold<int?>(null, (lowest, index) => lowest ?? index);
    final stackOpacity = 1 - .9 * dim;

    return DefaultTextStyle(
      style: archivo(22, color: p.textSecondary),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
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
                  if (dram > .01 && tilePhase != null && layout.indexOf(8) >= 0)
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
                    frames: frames,
                    opacity: 1 - dim,
                  ),
                  _Gutter(
                    tiers: tiers,
                    bands: bands,
                    view: view,
                    values: values,
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
          for (final (index, tier) in tiers.indexed)
            if (_cardVisible(tier))
              _StageCard(
                tier: tier,
                previous: index > 0 ? tiers[index - 1] : null,
                card: values[tier.number]!.card,
                morph: values[tier.number]!.morph,
                planeTop: target.top(index),
              ),
          if (dim > .01 && phone != null)
            _HookPhoneOverlay(phone: phone!, presence: dim),
          if (caption case final caption?)
            Positioned(
              left: 40,
              top: 760,
              width: 300,
              child: Text(
                caption,
                style: archivo(24, height: 1.3, color: p.text),
              ),
            ),
        ],
      ),
    );
  }

  /// A stage slide covers its plane until it has landed.
  bool _cardVisible(StackTier tier) {
    final v = values[tier.number]!;
    return v.card > .01 && v.morph < .97;
  }

  bool _planeVisible(StackTier tier) {
    final v = values[tier.number]!;
    if (v.presence < .005) return false;
    return !(v.card > .01 && v.morph < .97);
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
