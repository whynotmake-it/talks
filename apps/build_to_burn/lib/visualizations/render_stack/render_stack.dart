import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

/// The render stack: widget code at the bottom, pixels at the top, each tier
/// an isometric plane, grouped into bands. Draws [view].
///
/// Changing [view] animates bands, tiers, lighting, borders, loop arcs,
/// spotlights and the frame token from where they are. Drive it from deck
/// steps with a list of [RenderStackStep]s (see render_stack_content.dart).
/// The widget scales to its box, keeping [designSize]'s aspect ratio, and
/// reads its colors from [Palette].
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

class _RenderStackState extends State<RenderStack> {
  final _bandPresence = <String, Track<double>>{};
  final _tierExpand = <int, Track<double>>{};
  final _tierLight = <int, Track<double>>{};
  final _borders = {
    for (final border in StackBorder.values)
      border: Track<double>(.single, initial: 0, debugLabel: '$border'),
  };
  final _pixels = Track<double>(.single, initial: 0, debugLabel: 'Pixels');
  final _token = Track<double>(.single, initial: 0, debugLabel: 'Token');
  final _dim = Track<double>(.single, initial: 0, debugLabel: 'Hook phone');
  final _tiles = Track<double>(.single, initial: 0, debugLabel: 'Tiles');
  final _dram = Track<double>(.single, initial: 0, debugLabel: 'DRAM');
  final _feedback = Track<double>(.single, initial: 0, debugLabel: 'Feedback');

  /// The last phone and tile phase shown, kept so they can fade out.
  HookPhone? _lastPhone;
  TilePhase? _lastTiles;

  static const _motion = Motion.smoothSpring();
  static const _tokenRun = Motion.linear(Duration(milliseconds: 3200));
  static const _tileRun = Motion.linear(Duration(milliseconds: 1400));

  Track<double> _presenceOf(String band) => _bandPresence.putIfAbsent(
    band,
    () => Track(.single, initial: 0, debugLabel: 'Band $band'),
  );

  Track<double> _expandOf(int tier) => _tierExpand.putIfAbsent(
    tier,
    () => Track(.single, initial: 0, debugLabel: 'Tier $tier expanded'),
  );

  Track<double> _lightOf(int tier) => _tierLight.putIfAbsent(
    tier,
    () => Track(.single, initial: 0, debugLabel: 'Tier $tier light'),
  );

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    _lastPhone = view.phone ?? _lastPhone;
    _lastTiles = view.tiles ?? _lastTiles;
    final light = {...view.light, ...?view.spotlight?.tiers};
    final bandOrder = [
      for (final band in widget.bands)
        if (widget.tiers.any((tier) => tier.band == band.id)) band.id,
    ];

    return FittedBox(
      child: SizedBox.fromSize(
        size: RenderStack.designSize,
        child: TrackBuilder(
          debugLabel: 'Render stack',
          animations: [
            for (final (index, band) in bandOrder.indexed)
              view.showsBand(band)
                  ? _presenceOf(band)([
                      .hold(Duration(milliseconds: 160 * index)),
                      const .to(1, motion: _motion),
                    ])
                  : _presenceOf(band).to(0, motion: _motion),
            for (final tier in widget.tiers) ...[
              _expandOf(tier.number).to(
                view.expanded.contains(tier.number) ? 1 : 0,
                motion: _motion,
              ),
              _lightOf(tier.number).to(
                light[tier.number] ?? TierLight.off,
                motion: _motion,
              ),
            ],
            for (final MapEntry(key: border, value: track) in _borders.entries)
              track.to(view.borders.contains(border) ? 1 : 0, motion: _motion),
            _pixels.to(view.showPixels ? 1 : 0, motion: _motion),
            _token.to(view.token ? 1 : 0, motion: _tokenRun),
            _dim.to(view.phone != null ? 1 : 0, motion: _motion),
            _tiles.to(view.tiles != null ? 1 : 0, motion: _tileRun),
            _dram.to(
              view.tiles == null || view.tiles == TilePhase.fill ? 0 : 1,
              motion: _motion,
            ),
            _feedback.to(view.feedback ? 1 : 0, motion: _motion),
          ],
          builder: (context, value, _) => _StackPicture(
            tiers: widget.tiers,
            bands: widget.bands,
            view: view,
            presence: {
              for (final band in bandOrder) band: value(_presenceOf(band)),
            },
            expand: {
              for (final tier in widget.tiers)
                tier.number: value(_expandOf(tier.number)),
            },
            light: {
              for (final tier in widget.tiers)
                tier.number: value(_lightOf(tier.number)),
            },
            borders: {
              for (final MapEntry(key: border, value: track)
                  in _borders.entries)
                border: value(track),
            },
            pixels: value(_pixels),
            token: value(_token),
            dim: value(_dim),
            tiles: value(_tiles),
            dram: value(_dram),
            feedback: value(_feedback),
            phone: _lastPhone,
            tilePhase: view.tiles ?? _lastTiles,
            caption: widget.caption,
          ),
        ),
      ),
    );
  }
}

// Geometry, in design pixels.
const _plane = 280.0;
const _cos30 = 0.8660254;
const _halfWidth = _plane * _cos30;
const _centerX = 720.0;
const _baseY = 590.0;
const _topMargin = 56.0;
const _tierGap = 14.0;
const _bandGap = 70.0;
const _connectorGap = 44.0;
const _expandGap = 190.0;
const _capGap = 18.0;
const _labelsLeft = 1010.0;
const _labelsRight = 1580.0;

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
  final Map<String, double> presence;
  final Map<int, double> expand;

  late final List<double> offsets;
  late final double cap;

  StackBand _band(String id) => bands.firstWhere((band) => band.id == id);

  double _presenceOf(StackTier tier) =>
      (presence[tier.band] ?? 0).clamp(0.0, 1.0);

  double _gapBetween(StackTier below, StackTier above) {
    if (below.band == above.band) return _tierGap;
    if (_band(below.band).connector || _band(above.band).connector) {
      return _connectorGap;
    }
    return _bandGap;
  }

  /// Top vertex y of the tier at [index], including its rise.
  double top(int index) =>
      _baseY - offsets[index] + (1 - _presenceOf(tiers[index])) * 90;

  /// Center y of the tier at [index].
  double center(int index) => top(index) + _plane / 2;

  int indexOf(int number) => tiers.indexWhere((tier) => tier.number == number);
}

class _StackPicture extends StatelessWidget {
  const _StackPicture({
    required this.tiers,
    required this.bands,
    required this.view,
    required this.presence,
    required this.expand,
    required this.light,
    required this.borders,
    required this.pixels,
    required this.token,
    required this.dim,
    required this.tiles,
    required this.dram,
    required this.feedback,
    required this.phone,
    required this.tilePhase,
    required this.caption,
  });

  final List<StackTier> tiers;
  final List<StackBand> bands;
  final RenderStackView view;
  final Map<String, double> presence;
  final Map<int, double> expand;
  final Map<int, double> light;
  final Map<StackBorder, double> borders;
  final double pixels;
  final double token;
  final double dim;
  final double tiles;
  final double dram;
  final double feedback;
  final HookPhone? phone;
  final TilePhase? tilePhase;
  final String? caption;

  StackBand _band(String id) => bands.firstWhere((band) => band.id == id);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final layout = _Layout(tiers, bands, presence, expand);
    final lowestExpanded = [
      for (final (index, tier) in tiers.indexed)
        if (expand[tier.number]! > .05) index,
    ].fold<int?>(null, (lowest, index) => lowest ?? index);

    final stackOpacity = 1 - .82 * dim.clamp(0.0, 1.0);
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
                children: _stackChildren(p, layout, lowestExpanded),
              ),
            ),
          ),
          if (dim > .01 && phone != null)
            _HookPhoneOverlay(phone: phone!, presence: dim.clamp(0.0, 1.0)),
          if (caption case final caption?)
            Positioned(
              left: 60,
              top: 740,
              width: 380,
              child: Text(
                caption,
                style: archivo(26, height: 1.3, color: p.text),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _stackChildren(
    Palette p,
    _Layout layout,
    int? lowestExpanded,
  ) => [
    if (view.spotlight case final spotlight?)
      _Spotlight(spotlight: spotlight, layout: layout),
    for (final (index, tier) in tiers.indexed)
      if (layout._presenceOf(tier) > .005)
        _TierPlane(
          tier: tier,
          band: _band(tier.band),
          top: layout.top(index),
          presence: layout._presenceOf(tier),
          expand: expand[tier.number]!.clamp(0.0, 1.0),
          light: light[tier.number]!.clamp(0.0, 1.0),
          translucent: lowestExpanded != null && index > lowestExpanded,
          emphasis: view.emphasis,
          pixels: _pixelsFor(tier),
          tiles: tier.number == 8 ? tiles.clamp(0.0, 1.0) : 0,
          tilePhase: tilePhase,
        ),
    if (tiers.isNotEmpty) _cap(p, layout),
    ..._borders(p, layout),
    _Labels(
      tiers: tiers,
      bands: bands,
      layout: layout,
      expand: expand,
      light: light,
    ),
    for (final (index, arc) in view.arcs.indexed)
      if (layout.indexOf(arc.startTier) >= 0 &&
          layout.indexOf(arc.endTier) >= 0)
        _ArcOverlay(
          key: ValueKey(arc.id),
          arc: arc,
          slot: index,
          slotCount: view.arcs.length,
          fromY: layout.center(layout.indexOf(arc.startTier)),
          toY: layout.center(layout.indexOf(arc.endTier)),
          slowdown: view.arcSlowdown,
          activeY: switch (arc.activeFromTier) {
            final tier? when layout.indexOf(tier) >= 0 => layout.center(
              layout.indexOf(tier),
            ),
            _ => null,
          },
        ),
    if (token > .001 && token < .999) _token(p, layout),
    if (_cardTier() case final index?)
      _DetailCard(
        tier: tiers[index],
        emphasis: view.emphasis,
        presence: expand[tiers[index].number]!.clamp(0.0, 1.0),
        anchor: Offset(_centerX - _halfWidth, layout.center(index)),
        color: _lightColors(
          p,
          math.max(light[tiers[index].number]!, TierLight.dim),
        ).text,
      ),
    if (dram > .01 && tilePhase != null && layout.indexOf(8) >= 0)
      _DramOverlay(
        phase: tilePhase!,
        presence: dram.clamp(0.0, 1.0),
        tierCenter: layout.center(layout.indexOf(8)),
      ),
    if (feedback > .01 && layout.indexOf(6) >= 0 && layout.indexOf(8) >= 0)
      _FeedbackArrows(
        presence: feedback.clamp(0.0, 1.0),
        gpuY: layout.center(layout.indexOf(8)),
        rasterY: layout.center(layout.indexOf(6)),
        encodeY: layout.center(layout.indexOf(7)),
      ),
  ];

  /// The expanded tier whose detail card is shown: the most expanded one
  /// with a text detail.
  int? _cardTier() {
    int? best;
    for (final (index, tier) in tiers.indexed) {
      if (tier.detail == null || tier.detail is ScreenDetail) continue;
      final value = expand[tier.number]!;
      if (value < .01) continue;
      if (best == null || value > expand[tiers[best].number]!) best = index;
    }
    return best;
  }

  /// The demo screen fades in once the token has arrived, or with [pixels].
  double _pixelsFor(StackTier tier) {
    if (tier.detail is! ScreenDetail) return 0;
    if (view.token) return ((token - .9) * 10).clamp(0.0, 1.0);
    return pixels.clamp(0.0, 1.0);
  }

  Widget _cap(Palette p, _Layout layout) {
    final opacity = layout._presenceOf(tiers.last);
    return Positioned.fill(
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

  List<Widget> _borders(Palette p, _Layout layout) {
    Widget line(
      double y,
      double t, {
      required bool bold,
      required Color color,
      String above = '',
      String below = '',
    }) => Positioned(
      left: 40,
      width: _labelsLeft - 70,
      top: y - 40,
      height: 80,
      child: Opacity(
        opacity: t,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 39,
              height: bold ? 4 : 2,
              child: _Dashes(color: color),
            ),
            if (above.isNotEmpty)
              Positioned(
                left: 0,
                top: 10,
                child: Text(above, style: mono(17, weight: 600, color: color)),
              ),
            if (below.isNotEmpty)
              Positioned(
                left: 0,
                top: 48,
                child: Text(below, style: mono(17, weight: 600, color: color)),
              ),
          ],
        ),
      ),
    );

    double between(int a, int b) =>
        (layout.center(layout.indexOf(a)) + layout.center(layout.indexOf(b))) /
        2;
    final thread = borders[StackBorder.thread]!.clamp(0.0, 1.0);
    final gpu = borders[StackBorder.gpu]!.clamp(0.0, 1.0);
    final present = borders[StackBorder.present]!.clamp(0.0, 1.0);
    return [
      if (thread > .01 && layout.indexOf(5) >= 0 && layout.indexOf(6) >= 0)
        line(
          between(5, 6),
          thread,
          bold: false,
          color: p.textSecondary,
          below: 'UI → RASTER THREAD · same CPU',
        ),
      if (gpu > .01 && layout.indexOf(7) >= 0)
        line(
          layout.center(layout.indexOf(7)),
          gpu,
          bold: true,
          color: heat,
          above: 'GPU EXECUTES ↑',
          below: thread > .01 || feedback > .01 ? '' : 'CPU ENCODES ↓ · commit',
        ),
      if (present > .01 && layout.indexOf(8) >= 0 && layout.indexOf(9) >= 0)
        line(
          between(8, 9),
          present,
          bold: false,
          color: p.textSecondary,
          above: 'PRESENT → SYSTEM COMPOSITOR',
        ),
    ];
  }

  Widget _token(Palette p, _Layout layout) {
    final position = token * (tiers.length - 1);
    final below = position.floor().clamp(0, tiers.length - 1);
    final above = position.ceil().clamp(0, tiers.length - 1);
    final y = lerpDouble(
      layout.center(below),
      layout.center(above),
      position - below,
    )!;
    final label = tiers[position.round().clamp(0, tiers.length - 1)].token;
    return Positioned(
      left: _centerX - 110,
      width: 220,
      top: y - 26,
      height: 52,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: p.accent,
            boxShadow: [
              BoxShadow(color: p.accent.withValues(alpha: .5), blurRadius: 24),
            ],
          ),
          child: Text(label, style: mono(20, weight: 600, color: p.onAccent)),
        ),
      ),
    );
  }
}

class _TierPlane extends StatelessWidget {
  const _TierPlane({
    required this.tier,
    required this.band,
    required this.top,
    required this.presence,
    required this.expand,
    required this.light,
    required this.translucent,
    required this.emphasis,
    required this.pixels,
    required this.tiles,
    required this.tilePhase,
  });

  final StackTier tier;
  final StackBand band;
  final double top;
  final double presence;
  final double expand;
  final double light;
  final bool translucent;
  final Set<String> emphasis;
  final double pixels;
  final double tiles;
  final TilePhase? tilePhase;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final colors = _lightColors(p, light);
    final base = band.connector ? p.inset : p.surface;
    final fill = Color.lerp(base, colors.fill, light > 0 ? 1 : 0)!;
    return Positioned(
      left: _centerX,
      top: top,
      child: Opacity(
        opacity: presence,
        child: Transform(
          transform: _isometric,
          child: SizedBox.square(
            dimension: _plane,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill.withValues(alpha: translucent ? .3 : .95),
                border: Border.all(
                  color: colors.edge,
                  width: lerpDouble(2, 4, light)!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.text.withValues(alpha: .07),
                    offset: const Offset(8, 8),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (tiles > .001)
                    CustomPaint(
                      painter: _TilePainter(
                        progress: tiles,
                        color: tilePhase == TilePhase.flush ? heat : p.accent,
                        empty: p.control,
                      ),
                    ),
                  if (tier.detail is ScreenDetail && pixels > .01)
                    Opacity(opacity: pixels, child: const _DemoScreen()),
                  if (expand > .01 && tier.detail is! ScreenDetail)
                    Opacity(
                      opacity: expand,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _Schematic(
                          detail: tier.detail,
                          emphasis: emphasis,
                          color: colors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colors for a tier lit at [light]: neutral, then accent (dim), then heat.
({Color fill, Color edge, Color text}) _lightColors(Palette p, double light) {
  if (light <= TierLight.dim) {
    final t = light / TierLight.dim;
    return (
      fill: Color.lerp(p.surface, p.accentSoft, t)!,
      edge: Color.lerp(p.borderStrong, p.accent, t)!,
      text: Color.lerp(p.textSecondary, p.accent, t)!,
    );
  }
  final t = (light - TierLight.dim) / (TierLight.hot - TierLight.dim);
  return (
    fill: Color.lerp(p.accentSoft, Color.lerp(p.surface, heat, .16), t)!,
    edge: Color.lerp(p.accent, heat, t)!,
    text: Color.lerp(p.accent, heat, t)!,
  );
}

/// What an expanded plane shows in 3D: the shape of its detail, not its text.
/// The readable text is in [_DetailCard].
class _Schematic extends StatelessWidget {
  const _Schematic({
    required this.detail,
    required this.emphasis,
    required this.color,
  });

  final TierDetail? detail;
  final Set<String> emphasis;
  final Color color;

  bool _emphasized(String text) => emphasis.any(text.contains);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget bar(String text, {double height = 14}) => Container(
      width: (text.trim().length * 8.0).clamp(40.0, 220.0),
      height: height,
      margin: EdgeInsets.only(
        left: (text.length - text.trimLeft().length) * 7.0,
        bottom: 10,
      ),
      color: _emphasized(text) ? heat : color.withValues(alpha: .55),
    );
    return switch (detail) {
      null || ScreenDetail() => const SizedBox.shrink(),
      LinesDetail(:final lines) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in lines) bar(line)],
      ),
      ChipsDetail(:final items) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in items)
            Container(
              width: (item.length * 6.0).clamp(50.0, 150.0),
              height: 34,
              decoration: BoxDecoration(
                color: p.inset,
                border: Border.all(
                  color: _emphasized(item) ? heat : color,
                  width: 2,
                ),
              ),
            ),
        ],
      ),
      TrayDetail(:final slots) => Row(
        children: [
          for (var slot = 0; slot < slots; slot++)
            Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: slot == 0 ? color.withValues(alpha: .3) : p.surface,
                border: Border.all(color: color, width: 3),
              ),
            ),
        ],
      ),
      PassesDetail(:final passes) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final pass in passes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 110,
                    height: 24,
                    color: (pass.hot ? heat : color).withValues(alpha: .6),
                  ),
                  const SizedBox(width: 8),
                  for (var call = 0; call < pass.drawCalls; call++)
                    Container(
                      width: 9,
                      height: 24,
                      margin: const EdgeInsets.only(right: 4),
                      color: pass.hot ? heat : p.accent,
                    ),
                ],
              ),
            ),
        ],
      ),
    };
  }
}

/// The readable version of an expanded tier's detail, flat at the bottom
/// left, with a leader line to its plane.
class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.tier,
    required this.emphasis,
    required this.presence,
    required this.anchor,
    required this.color,
  });

  final StackTier tier;
  final Set<String> emphasis;
  final double presence;
  final Offset anchor;
  final Color color;

  static const rect = Rect.fromLTWH(50, 540, 400, 330);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: presence,
          child: Stack(
            children: [
              CustomPaint(
                size: RenderStack.designSize,
                painter: _LeaderPainter(
                  from: anchor,
                  to: Offset(rect.right + 30, rect.top + 24),
                  color: color,
                ),
              ),
              Positioned(
                left: rect.left,
                width: rect.width,
                bottom: RenderStack.designSize.height - rect.bottom,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${tier.number}  ${tier.title}'.toUpperCase(),
                        style: mono(15, weight: 700, color: color),
                      ),
                      const SizedBox(height: 10),
                      _Detail(
                        detail: tier.detail,
                        emphasis: emphasis,
                        color: color,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.detail,
    required this.emphasis,
    required this.color,
  });

  final TierDetail? detail;
  final Set<String> emphasis;
  final Color color;

  bool _emphasized(String text) => emphasis.any(text.contains);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    TextStyle line(String text) => mono(
      18,
      weight: _emphasized(text) ? 700 : 450,
      height: 1.4,
      color: _emphasized(text) ? heat : p.text,
    );
    return switch (detail) {
      null || ScreenDetail() => const SizedBox.shrink(),
      ChipsDetail(:final items) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: p.inset,
              child: Text(item, style: line(item).copyWith(height: 1.1)),
            ),
        ],
      ),
      LinesDetail(:final lines) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final text in lines)
            Text(text, maxLines: 1, softWrap: false, style: line(text)),
        ],
      ),
      TrayDetail(:final slots, :final label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: mono(13, color: p.textTertiary)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var slot = 0; slot < slots; slot++)
                Container(
                  width: 96,
                  height: 64,
                  margin: const EdgeInsets.only(right: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: slot == 0 ? p.accentSoft : p.surface,
                    border: Border.all(
                      color: slot == 0 ? color : p.border,
                      width: 2,
                    ),
                  ),
                  child: slot == 0
                      ? Text(
                          'Scene',
                          style: mono(15, weight: 600, color: color),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ),
      PassesDetail(:final passes) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final pass in passes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      pass.name,
                      style: mono(
                        15,
                        weight: 700,
                        color: pass.hot ? heat : p.text,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 136,
                    child: Text(
                      pass.label,
                      maxLines: 1,
                      softWrap: false,
                      style: mono(14, color: pass.hot ? heat : p.textSecondary),
                    ),
                  ),
                  for (var call = 0; call < pass.drawCalls; call++)
                    Container(
                      width: 8,
                      height: 14,
                      margin: const EdgeInsets.only(right: 3),
                      color: pass.hot ? heat : p.accent,
                    ),
                ],
              ),
            ),
        ],
      ),
    };
  }
}

/// The spec's demo: a frosted card with a caret over a blue page.
class _DemoScreen extends StatelessWidget {
  const _DemoScreen();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF2563EB)),
        Positioned(
          left: 30,
          top: 40,
          child: Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFF93C5FD),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 26,
          bottom: 36,
          child: Container(
            width: 110,
            height: 60,
            color: const Color(0xFF1E3A8A),
          ),
        ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 200,
                height: 80,
                color: const Color(0x33FFFFFF),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.centerLeft,
                child: Container(width: 3, height: 30, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Band headers and one line per tier on the right, spread so they never
/// overlap, with leader lines to the planes.
class _Labels extends StatelessWidget {
  const _Labels({
    required this.tiers,
    required this.bands,
    required this.layout,
    required this.expand,
    required this.light,
  });

  final List<StackTier> tiers;
  final List<StackBand> bands;
  final _Layout layout;
  final Map<int, double> expand;
  final Map<int, double> light;

  static const _lineHeight = 50.0;
  static const _headerHeight = 26.0;
  static const _detailHeight = 78.0;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final entries = <({int index, double y, double height, bool header})>[];
    // Top of the screen first, so higher tiers claim their spot first.
    for (var index = tiers.length - 1; index >= 0; index--) {
      final tier = tiers[index];
      final presence = layout._presenceOf(tier);
      if (presence < .005) continue;
      final header =
          index == tiers.length - 1 || tiers[index + 1].band != tier.band;
      final height =
          _lineHeight +
          (header ? _headerHeight : 0) +
          expand[tier.number]!.clamp(0.0, 1.0) * _detailHeight;
      entries.add((
        index: index,
        y: layout.center(index) - height / 2,
        height: height,
        header: header,
      ));
    }
    final placed = <double>[];
    var next = _topMargin - 30;
    for (final entry in entries) {
      final y = math.max(entry.y, next);
      placed.add(y);
      next = y + entry.height + 4;
    }
    final overflow = next - (RenderStack.designSize.height - 10);
    if (overflow > 0) {
      for (var i = 0; i < placed.length; i++) {
        placed[i] -= overflow;
      }
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (i, entry) in entries.indexed)
              ..._label(p, entry.index, placed[i], entry.header),
          ],
        ),
      ),
    );
  }

  List<Widget> _label(Palette p, int index, double y, bool header) {
    final tier = tiers[index];
    final band = bands.firstWhere((band) => band.id == tier.band);
    final presence = layout._presenceOf(tier);
    final expanded = expand[tier.number]!.clamp(0.0, 1.0);
    final colors = _lightColors(p, light[tier.number]!.clamp(0.0, 1.0));
    final titleY = y + (header ? _headerHeight : 0);
    return [
      CustomPaint(
        size: RenderStack.designSize,
        painter: _LeaderPainter(
          from: Offset(_centerX + _halfWidth, layout.center(index)),
          to: Offset(_labelsLeft - 12, titleY + 16),
          color: p.borderStrong.withValues(alpha: presence),
        ),
      ),
      Positioned(
        left: _labelsLeft,
        top: y,
        width: _labelsRight - _labelsLeft,
        child: Opacity(
          opacity: presence,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header)
                SizedBox(
                  height: _headerHeight,
                  child: Text(
                    [band.title, band.subtitle]
                        .where((part) => part.isNotEmpty)
                        .join(' · ')
                        .toUpperCase(),
                    style: mono(15, weight: 600, color: p.textTertiary),
                  ),
                ),
              Text(
                '${tier.number}  ${tier.title}',
                style: archivo(
                  24,
                  weight: 500,
                  height: 1.15,
                  color: colors.text,
                ),
              ),
              Text(
                '${tier.inputs}  →  ${tier.outputs}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono(14, color: p.textSecondary),
              ),
              if (expanded > .01)
                Opacity(
                  opacity: expanded,
                  child: SizedBox(
                    height: _detailHeight * expanded,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        [
                          tier.where.toUpperCase(),
                          tier.note,
                        ].where((part) => part.isNotEmpty).join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.fade,
                        style: archivo(17, height: 1.3, color: p.textSecondary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

/// The x of the arc in [slot], counted outward from the stack.
double _arcX(int slot) => _centerX - _halfWidth - 50 - slot * 52;

/// A loop as an arc on the left of the stack, pulsing upward at its rate.
class _ArcOverlay extends StatefulWidget {
  const _ArcOverlay({
    required this.arc,
    required this.slot,
    required this.fromY,
    required this.toY,
    required this.slowdown,
    required this.slotCount,
    this.activeY,
    super.key,
  });

  final LoopArc arc;
  final int slot;

  /// How many arcs are drawn; labels sit left of the outermost one.
  final int slotCount;
  final double fromY;
  final double toY;
  final double slowdown;

  /// Where the arc turns from dim to full, if it has a dim part.
  final double? activeY;

  @override
  State<_ArcOverlay> createState() => _ArcOverlayState();
}

class _ArcOverlayState extends State<_ArcOverlay> {
  final _phase = Track<double>(.single, initial: 0, debugLabel: 'Arc phase');

  static const _travel = Duration(milliseconds: 1200);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final arc = widget.arc;
    final prominent = arc.prominent;
    final width = prominent ? 8.0 : 3.0;
    final x = _arcX(widget.slot);
    final labelRight = _arcX(widget.slotCount - 1) - 12;
    final top = widget.toY;
    final bottom = widget.fromY;
    final activeY = (widget.activeY ?? bottom)
        .clamp(math.min(top, bottom), math.max(top, bottom))
        .toDouble();
    final color = arc.endTier >= 6 ? heat : p.accent;
    final interval = arc.perSecond > 0
        ? Duration(
            microseconds: (widget.slowdown * 1000000 / arc.perSecond).round(),
          )
        : Duration.zero;
    final rate =
        arc.rateLabel ??
        (arc.perSecond == 0
            ? ''
            : '${arc.perSecond % 1 == 0 ? arc.perSecond.toInt() : arc.perSecond}/s');
    final labelStyle = mono(
      prominent ? 20 : 15,
      weight: prominent ? 700 : 500,
      height: 1.3,
      color: prominent ? color : color.withValues(alpha: .8),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Below activeY the frame passes through with nothing dirty.
            if (activeY < bottom)
              Positioned(
                left: x + width / 2 - 1.5,
                top: activeY,
                width: 3,
                height: bottom - activeY,
                child: ColoredBox(
                  key: ValueKey('arc-dim-${arc.id}'),
                  color: color.withValues(alpha: .25),
                ),
              ),
            Positioned(
              left: x,
              top: top,
              width: width,
              height: math.max(activeY - top, 0),
              child: ColoredBox(
                key: ValueKey('arc-line-${arc.id}'),
                color: color.withValues(alpha: .6),
              ),
            ),
            for (final y in [top, if (activeY < bottom) activeY, bottom])
              Positioned(
                left: x,
                top: y - width / 2,
                width: _centerX - _halfWidth * .5 - x,
                height: math.min(width, 4),
                child: ColoredBox(
                  color: color.withValues(alpha: y == bottom ? .2 : .35),
                ),
              ),
            if (interval > Duration.zero)
              TrackBuilder(
                debugLabel: 'Loop ${arc.id}',
                loop: .loop,
                animations: [
                  _phase([
                    const .to(0, motion: .linear(Duration(milliseconds: 1))),
                    .to(1, motion: .linear(interval)),
                  ]),
                ],
                builder: (context, value, _) => CustomPaint(
                  size: RenderStack.designSize,
                  painter: _PulsePainter(
                    x: x + width / 2,
                    bottom: bottom,
                    top: top,
                    activeY: activeY,
                    phase: value(_phase).clamp(0.0, 1.0),
                    interval: interval,
                    travel: _travel,
                    color: color,
                    radius: prominent ? 10 : 5,
                  ),
                ),
              ),
            Positioned(
              left: labelRight - 310,
              width: 310,
              top: bottom - (prominent ? 26 : 18),
              child: Text(
                [
                  '${arc.id} · ${arc.label}',
                  if (rate.isNotEmpty) rate,
                  if (arc.origin.isNotEmpty) arc.origin,
                ].join('\n'),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            if (arc.cutNote.isNotEmpty)
              Positioned(
                left: labelRight - 310,
                width: 310,
                top: top - 52,
                child: Text(
                  '✂ ${arc.cutNote}',
                  textAlign: TextAlign.right,
                  style: mono(17, weight: 700, color: p.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.x,
    required this.bottom,
    required this.top,
    required this.activeY,
    required this.phase,
    required this.interval,
    required this.travel,
    required this.color,
    required this.radius,
  });

  final double x;
  final double bottom;
  final double top;
  final double activeY;
  final double phase;
  final Duration interval;
  final Duration travel;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final ratio = interval.inMicroseconds / travel.inMicroseconds;
    final count = (1 / ratio).ceil() + 1;
    for (var k = 0; k < count; k++) {
      final progress = (phase + k) * ratio;
      if (progress > 1) continue;
      final y = lerpDouble(bottom, top, progress)!;
      final active = y <= activeY + .5;
      canvas.drawCircle(
        Offset(x, y),
        active ? radius : radius * .6,
        Paint()..color = color.withValues(alpha: active ? 1 : .35),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      phase != oldDelegate.phase ||
      bottom != oldDelegate.bottom ||
      top != oldDelegate.top ||
      activeY != oldDelegate.activeY ||
      color != oldDelegate.color;
}

/// A tool's light cone onto the tiers it can see.
class _Spotlight extends StatelessWidget {
  const _Spotlight({required this.spotlight, required this.layout});

  final ToolSpotlight spotlight;
  final _Layout layout;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final indices = [
      for (final tier in spotlight.tiers.keys)
        if (layout.indexOf(tier) >= 0) layout.indexOf(tier),
    ]..sort();
    if (indices.isEmpty) return const SizedBox.shrink();
    final highest = layout.center(indices.last) - _plane / 2;
    final lowest = layout.center(indices.first) + _plane / 2;
    const box = Rect.fromLTWH(60, 60, 320, 120);
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            CustomPaint(
              size: RenderStack.designSize,
              painter: _ConePainter(
                from: box,
                toTop: Offset(_centerX, highest),
                toBottom: Offset(_centerX, lowest),
                color: p.accent,
              ),
            ),
            Positioned.fromRect(
              rect: box,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border.all(color: p.accent, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spotlight.tool,
                      style: archivo(24, weight: 600, color: p.accent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spotlight.shows,
                      maxLines: 2,
                      style: archivo(16, height: 1.25, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConePainter extends CustomPainter {
  _ConePainter({
    required this.from,
    required this.toTop,
    required this.toBottom,
    required this.color,
  });

  final Rect from;
  final Offset toTop;
  final Offset toBottom;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(from.right, from.top + 10)
      ..lineTo(toTop.dx, toTop.dy)
      ..lineTo(toBottom.dx, toBottom.dy)
      ..lineTo(from.right, from.bottom - 10)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .22), color.withValues(alpha: .04)],
        ).createShader(Rect.fromPoints(from.centerRight, toTop)),
    );
  }

  @override
  bool shouldRepaint(_ConePainter oldDelegate) =>
      from != oldDelegate.from ||
      toTop != oldDelegate.toTop ||
      toBottom != oldDelegate.toBottom ||
      color != oldDelegate.color;
}

class _RhombusPainter extends CustomPainter {
  _RhombusPainter({
    required this.top,
    required this.stroke,
    this.dashed = false,
  });

  final Offset top;
  final Color stroke;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final corners = [
      top,
      Offset(top.dx + _halfWidth, top.dy + _plane / 2),
      Offset(top.dx, top.dy + _plane),
      Offset(top.dx - _halfWidth, top.dy + _plane / 2),
    ];
    final paint = Paint()
      ..color = stroke
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      if (!dashed) {
        canvas.drawLine(a, b, paint);
        continue;
      }
      final length = (b - a).distance;
      for (var d = 0.0; d < length; d += 16) {
        canvas.drawLine(
          Offset.lerp(a, b, d / length)!,
          Offset.lerp(a, b, math.min(d + 9, length) / length)!,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RhombusPainter oldDelegate) =>
      top != oldDelegate.top ||
      stroke != oldDelegate.stroke ||
      dashed != oldDelegate.dashed;
}

class _LeaderPainter extends CustomPainter {
  _LeaderPainter({required this.from, required this.to, required this.color});

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final elbow = Offset(to.dx - 30, to.dy);
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(to.dx, to.dy),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_LeaderPainter oldDelegate) =>
      from != oldDelegate.from ||
      to != oldDelegate.to ||
      color != oldDelegate.color;
}

class _Dashes extends StatelessWidget {
  const _Dashes({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashPainter(color), size: Size.infinite);
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 10, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => color != oldDelegate.color;
}

/// The hook: the demo on a phone in front of the dimmed stack, with a vote.
class _HookPhoneOverlay extends StatelessWidget {
  const _HookPhoneOverlay({required this.phone, required this.presence});

  final HookPhone phone;
  final double presence;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Positioned.fill(
      child: Opacity(
        opacity: presence,
        child: Transform.translate(
          offset: Offset(0, (1 - presence) * 40),
          child: Stack(
            children: [
              Positioned(
                left: _centerX - 180,
                top: 70,
                width: 360,
                height: 760,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(52),
                    border: Border.all(color: p.text, width: 10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(52),
                    child: const _HookScreen(),
                  ),
                ),
              ),
              Positioned(
                left: _centerX + 260,
                top: 250,
                width: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phone.question,
                      style: archivo(40, weight: 500, color: p.text),
                    ),
                    const SizedBox(height: 28),
                    for (final option in phone.options)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: p.surface,
                          border: Border.all(color: p.border, width: 2),
                        ),
                        child: Text(
                          option,
                          style: archivo(28, color: p.text),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The spec's demo at phone size: a blue page, a frosted card with a white
/// field and hairline border, and a fading iOS caret.
class _HookScreen extends StatelessWidget {
  const _HookScreen();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF2563EB)),
        for (final (left, top, size) in [
          (40.0, 170.0, 150.0),
          (200.0, 470.0, 120.0),
        ])
          Positioned(
            left: left,
            top: top,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Color(0xFF93C5FD),
                shape: BoxShape.circle,
              ),
            ),
          ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.4, sigmaY: 8.4),
              child: Container(
                width: 252,
                height: 101,
                color: const Color(0x33FFFFFF),
                alignment: Alignment.center,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0x33000000),
                      width: .5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  child: const _FadingCaret(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An iOS-style caret: holds, fades out, holds, fades in, once a second.
class _FadingCaret extends StatelessWidget {
  const _FadingCaret();

  static final _opacity = Track<double>(
    .single,
    initial: 1,
    debugLabel: 'Hook caret',
  );

  static const _fade = Motion.linear(Duration(milliseconds: 150));

  @override
  Widget build(BuildContext context) => TrackBuilder(
    debugLabel: 'Hook caret',
    loop: .loop,
    animations: [
      _opacity(const [
        .hold(Duration(milliseconds: 500)),
        .to(0, motion: _fade),
        .hold(Duration(milliseconds: 200)),
        .to(1, motion: _fade),
      ]),
    ],
    builder: (context, value, child) =>
        Opacity(opacity: value(_opacity).clamp(0, 1), child: child),
    child: Container(width: 2, height: 17, color: const Color(0xFF007AFF)),
  );
}

/// The GPU tier's tile memory: tiles light up as the pass renders.
class _TilePainter extends CustomPainter {
  _TilePainter({
    required this.progress,
    required this.color,
    required this.empty,
  });

  final double progress;
  final Color color;
  final Color empty;

  static const _grid = 7;
  static const _margin = 14.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final tile = (size.width - 2 * _margin - (_grid - 1) * _gap) / _grid;
    final lit = (progress * _grid * _grid).floor();
    for (var row = 0; row < _grid; row++) {
      for (var column = 0; column < _grid; column++) {
        final index = row * _grid + column;
        canvas.drawRect(
          Rect.fromLTWH(
            _margin + column * (tile + _gap),
            _margin + row * (tile + _gap),
            tile,
            tile,
          ),
          Paint()
            ..color = index < lit
                ? color.withValues(alpha: .85)
                : empty.withValues(alpha: .6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TilePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      empty != oldDelegate.empty;
}

/// DRAM next to the GPU band, with the frame streaming out (flush) or back
/// in (re-seed).
class _DramOverlay extends StatefulWidget {
  const _DramOverlay({
    required this.phase,
    required this.presence,
    required this.tierCenter,
  });

  final TilePhase phase;
  final double presence;
  final double tierCenter;

  @override
  State<_DramOverlay> createState() => _DramOverlayState();
}

class _DramOverlayState extends State<_DramOverlay> {
  final _flow = Track<double>(.single, initial: 0, debugLabel: 'DRAM flow');

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final box = Rect.fromLTWH(60, widget.tierCenter - 240, 370, 140);
    final plane = Offset(_centerX - _halfWidth, widget.tierCenter);
    final port = Offset(box.right, box.bottom - 20);
    final outward = widget.phase == TilePhase.flush;
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: widget.presence,
          child: Stack(
            children: [
              TrackBuilder(
                debugLabel: 'DRAM flow',
                loop: .loop,
                animations: [
                  _flow(const [
                    .to(0, motion: .linear(Duration(milliseconds: 1))),
                    .to(1, motion: .linear(Duration(milliseconds: 700))),
                  ]),
                ],
                builder: (context, value, _) => CustomPaint(
                  size: RenderStack.designSize,
                  painter: _FlowPainter(
                    from: outward ? plane : port,
                    to: outward ? port : plane,
                    phase: value(_flow).clamp(0.0, 1.0),
                    color: heat,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: box,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(color: heat, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DRAM', style: mono(22, weight: 700, color: heat)),
                      const SizedBox(height: 6),
                      Text(
                        outward
                            ? 'store T0: 1179×2556 RGBA8 ≈ 12 MB'
                            : 're-seed: full-screen redraw from T0',
                        style: archivo(17, height: 1.3, color: p.text),
                      ),
                      Text(
                        '× 120/s ≈ 3–4 GB/s [estimate]',
                        style: mono(14, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.from,
    required this.to,
    required this.phase,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: .35)
        ..strokeWidth = 3,
    );
    final dot = Paint()..color = color;
    for (var k = 0; k < 4; k++) {
      final t = (phase + k / 4) % 1;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.lerp(from, to, t)!,
          width: 14,
          height: 14,
        ),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_FlowPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      from != oldDelegate.from ||
      to != oldDelegate.to ||
      color != oldDelegate.color;
}

/// The two arrows that cross the CPU/GPU border downward: back-pressure
/// (the raster thread waits for a drawable) and completion.
class _FeedbackArrows extends StatelessWidget {
  const _FeedbackArrows({
    required this.presence,
    required this.gpuY,
    required this.rasterY,
    required this.encodeY,
  });

  final double presence;
  final double gpuY;
  final double rasterY;
  final double encodeY;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    const completionX = _centerX - _halfWidth - 40;
    const pressureX = _centerX - _halfWidth - 90;
    Widget label(String title, String body, Color color, double top) =>
        Positioned(
          left: 40,
          width: pressureX - 54,
          top: top,
          child: Text(
            '$title\n$body',
            textAlign: TextAlign.right,
            style: mono(15, weight: 600, height: 1.35, color: color),
          ),
        );
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: presence,
          child: Stack(
            children: [
              CustomPaint(
                size: RenderStack.designSize,
                painter: _ArrowsPainter([
                  (Offset(pressureX, gpuY), Offset(pressureX, rasterY), heat),
                  (
                    Offset(completionX, gpuY),
                    Offset(completionX, encodeY),
                    p.accent,
                  ),
                ]),
              ),
              label(
                'BACK-PRESSURE',
                '3 drawables in flight:\nraster waits for one',
                heat,
                rasterY + 8,
              ),
              label(
                'COMPLETION',
                'frees resources,\nfeeds FrameTimeMS',
                p.accent,
                gpuY - 84,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowsPainter extends CustomPainter {
  _ArrowsPainter(this.arrows);

  final List<(Offset, Offset, Color)> arrows;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to, color) in arrows) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(from, to, paint)
        ..drawPath(
          Path()
            ..moveTo(to.dx - 10, to.dy - 14)
            ..lineTo(to.dx, to.dy)
            ..lineTo(to.dx + 10, to.dy - 14),
          paint,
        )
        ..drawCircle(from, 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ArrowsPainter oldDelegate) => true;
}
