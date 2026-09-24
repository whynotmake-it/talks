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

  static const _motion = Motion.smoothSpring();
  static const _tokenRun = Motion.linear(Duration(milliseconds: 3200));

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
const _expandGap = 150.0;
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

    return DefaultTextStyle(
      style: archivo(22, color: p.textSecondary),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                fromY: layout.center(layout.indexOf(arc.startTier)),
                toY: layout.center(layout.indexOf(arc.endTier)),
                slowdown: view.arcSlowdown,
              ),
          if (token > .001 && token < .999) _token(p, layout),
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
      required String above,
      required String below,
      Color? color,
    }) {
      final c = color ?? p.textSecondary;
      return Positioned(
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
                child: _Dashes(color: c),
              ),
              Positioned(
                left: 0,
                top: 8,
                child: Text(above, style: mono(17, weight: 600, color: c)),
              ),
              Positioned(
                left: 0,
                top: 50,
                child: Text(below, style: mono(17, weight: 600, color: c)),
              ),
            ],
          ),
        ),
      );
    }

    final result = <Widget>[];
    double between(int a, int b) =>
        (layout.center(layout.indexOf(a)) + layout.center(layout.indexOf(b))) /
        2;
    final thread = borders[StackBorder.thread]!.clamp(0.0, 1.0);
    if (thread > .01 && layout.indexOf(5) >= 0 && layout.indexOf(6) >= 0) {
      result.add(
        line(
          between(5, 6),
          thread,
          bold: false,
          above: 'RASTER THREAD ↑',
          below: 'UI THREAD ↓  · same CPU',
        ),
      );
    }
    final gpu = borders[StackBorder.gpu]!.clamp(0.0, 1.0);
    if (gpu > .01 && layout.indexOf(7) >= 0) {
      result.add(
        line(
          layout.center(layout.indexOf(7)),
          gpu,
          bold: true,
          color: heat,
          above: 'GPU EXECUTES ↑',
          below: 'CPU ENCODES ↓  · commit',
        ),
      );
    }
    final present = borders[StackBorder.present]!.clamp(0.0, 1.0);
    if (present > .01 && layout.indexOf(8) >= 0 && layout.indexOf(9) >= 0) {
      result.add(
        line(
          between(8, 9),
          present,
          bold: false,
          above: 'SYSTEM ↑',
          below: 'FLUTTER ↓  · present',
        ),
      );
    }
    return result;
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
                color: fill.withValues(alpha: translucent ? .5 : .95),
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
                  if (tier.detail is ScreenDetail && pixels > .01)
                    Opacity(opacity: pixels, child: const _DemoScreen()),
                  if (expand > .01 && tier.detail is! ScreenDetail)
                    Opacity(
                      opacity: expand,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _Detail(
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
      15,
      weight: _emphasized(text) ? 700 : 450,
      height: 1.5,
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

/// A loop as an arc on the left of the stack, pulsing upward at its rate.
class _ArcOverlay extends StatefulWidget {
  const _ArcOverlay({
    required this.arc,
    required this.slot,
    required this.fromY,
    required this.toY,
    required this.slowdown,
    super.key,
  });

  final LoopArc arc;
  final int slot;
  final double fromY;
  final double toY;
  final double slowdown;

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
    final x = _centerX - _halfWidth - 44 - widget.slot * 46;
    final top = widget.toY;
    final bottom = widget.fromY;
    final color = arc.endTier >= 6 ? heat : p.accent;
    final interval = arc.perSecond > 0
        ? Duration(
            microseconds: (widget.slowdown * 1000000 / arc.perSecond).round(),
          )
        : Duration.zero;

    final rate = arc.perSecond == 0
        ? ''
        : '${arc.perSecond % 1 == 0 ? arc.perSecond.toInt() : arc.perSecond}/s';

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: x,
              top: top,
              width: 4,
              height: math.max(bottom - top, 0),
              child: ColoredBox(color: color.withValues(alpha: .55)),
            ),
            for (final y in [top, bottom])
              Positioned(
                left: x,
                top: y - 2,
                width: _centerX - _halfWidth * .5 - x,
                height: 4,
                child: ColoredBox(color: color.withValues(alpha: .35)),
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
                    x: x + 2,
                    bottom: bottom,
                    top: top,
                    phase: value(_phase).clamp(0.0, 1.0),
                    interval: interval,
                    travel: _travel,
                    color: color,
                  ),
                ),
              ),
            Positioned(
              left: x - 210,
              width: 200,
              top: bottom - 20,
              child: Text(
                '${arc.id} · ${arc.label}\n$rate',
                textAlign: TextAlign.right,
                style: mono(16, weight: 600, height: 1.3, color: color),
              ),
            ),
            if (arc.cutNote.isNotEmpty)
              Positioned(
                left: x - 210,
                width: 200,
                top: top - 48,
                child: Text(
                  '✂ ${arc.cutNote}',
                  textAlign: TextAlign.right,
                  style: mono(16, weight: 600, color: p.text),
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
    required this.phase,
    required this.interval,
    required this.travel,
    required this.color,
  });

  final double x;
  final double bottom;
  final double top;
  final double phase;
  final Duration interval;
  final Duration travel;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ratio = interval.inMicroseconds / travel.inMicroseconds;
    final count = (1 / ratio).ceil() + 1;
    final paint = Paint()..color = color;
    for (var k = 0; k < count; k++) {
      final progress = (phase + k) * ratio;
      if (progress > 1) continue;
      final y = lerpDouble(bottom, top, progress)!;
      canvas.drawCircle(Offset(x, y), 7, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      phase != oldDelegate.phase ||
      bottom != oldDelegate.bottom ||
      top != oldDelegate.top ||
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
