part of 'render_stack.dart';

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
    return Positioned(
      left: _centerX,
      top: top,
      child: Opacity(
        opacity: presence,
        child: Transform(
          transform: _isometric,
          child: _PlaneFace(
            tier: tier,
            band: band,
            light: light,
            translucent: translucent,
            emphasis: emphasis,
            pixels: pixels,
            tiles: tiles,
            tilePhase: tilePhase,
            // Landed planes keep a faint trace of their stage.
            detailOpacity: lerpDouble(.3, 1, expand)!,
          ),
        ),
      ),
    );
  }
}

/// A plane's fill, border and shadow at the given light.
BoxDecoration _planeDecoration(
  Palette p,
  StackBand band,
  double light, {
  bool translucent = false,
  double? fillAlpha,
}) {
  final colors = _lightColors(p, light);
  final base = band.connector ? p.inset : p.surface;
  final fill = Color.lerp(base, colors.fill, light > 0 ? 1 : 0)!;
  return BoxDecoration(
    color: fill.withValues(alpha: fillAlpha ?? (translucent ? .3 : .95)),
    border: Border.all(color: colors.edge, width: lerpDouble(2, 4, light)!),
    boxShadow: [
      BoxShadow(
        color: p.text.withValues(alpha: .07),
        offset: const Offset(8, 8),
      ),
    ],
  );
}

/// What a plane shows at its native 280×280: frame, tile painter, demo
/// screen and schematic. Drawn by [_TierPlane] in 3D and by [_StageCard]
/// while it simplifies and lands.
class _PlaneFace extends StatelessWidget {
  const _PlaneFace({
    required this.tier,
    required this.band,
    required this.light,
    required this.emphasis,
    required this.detailOpacity,
    this.translucent = false,
    this.fillAlpha,
    this.pixels = 0,
    this.tiles = 0,
    this.tilePhase,
  });

  final StackTier tier;
  final StackBand band;
  final double light;
  final bool translucent;

  /// Overrides the fill's alpha — the landing card stays opaque until the
  /// tilt, so nothing behind it bleeds through.
  final double? fillAlpha;
  final Set<String> emphasis;
  final double pixels;
  final double tiles;
  final TilePhase? tilePhase;

  /// How strongly the schematic shows: 1 on the stage slide, .3 landed.
  final double detailOpacity;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox.square(
      dimension: _plane,
      child: DecoratedBox(
        decoration: _planeDecoration(
          p,
          band,
          light,
          translucent: translucent,
          fillAlpha: fillAlpha,
        ),
        child: _PlaneInner(
          tier: tier,
          light: light,
          emphasis: emphasis,
          pixels: pixels,
          tiles: tiles,
          tilePhase: tilePhase,
          detailOpacity: detailOpacity,
        ),
      ),
    );
  }
}

/// The inside of a plane face, without its frame.
class _PlaneInner extends StatelessWidget {
  const _PlaneInner({
    required this.tier,
    required this.light,
    required this.emphasis,
    required this.detailOpacity,
    this.pixels = 0,
    this.tiles = 0,
    this.tilePhase,
  });

  final StackTier tier;
  final double light;
  final Set<String> emphasis;
  final double pixels;
  final double tiles;
  final TilePhase? tilePhase;
  final double detailOpacity;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final colors = _lightColors(p, light);
    return Stack(
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
        if (tier.detail != null && tier.detail is! ScreenDetail)
          Opacity(
            opacity: detailOpacity,
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

  /// The [DemoWidget] whose `<label>(` call appears on this code line.
  static DemoWidget? _widgetOnLine(String line) {
    for (final widget in DemoWidget.values) {
      if (line.contains('${widget.label}(')) return widget;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget bar(
      String text, {
      double height = 14,
      double width = 8,
      double bottom = 10,
      Color? barColor,
    }) => Container(
      width: (text.trim().length * width).clamp(40.0, 220.0),
      height: height,
      margin: EdgeInsets.only(
        left: (text.length - text.trimLeft().length) * 7.0,
        bottom: bottom,
      ),
      color:
          barColor ?? (_emphasized(text) ? heat : color.withValues(alpha: .55)),
    );
    return switch (detail) {
      null || ScreenDetail() => const SizedBox.shrink(),
      CodeDetail(:final code) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in code.split('\n'))
            if (line.trim().isNotEmpty)
              bar(
                line,
                height: 4.5,
                width: 4.8,
                bottom: 4,
                barColor: switch (_widgetOnLine(line)) {
                  null => null,
                  DemoWidget(:final color?) => color.withValues(alpha: .8),
                  _ => p.textTertiary.withValues(alpha: .8),
                },
              ),
        ],
      ),
      RenderTreeDetail(:final root) => SizedBox.square(
        dimension: 240,
        child: CustomPaint(
          painter: _MiniRenderTreePainter(root: root, palette: p),
        ),
      ),
      PaintDetail(:final ops) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final op in ops)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    color: (op.widget.color ?? p.textTertiary).withValues(
                      alpha: .85,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (op.pushes != null)
                    Container(
                      width: 96,
                      height: 16,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: op.widget.color ?? p.textTertiary,
                          width: 2,
                        ),
                      ),
                    ),
                  if (op.picture != null)
                    Container(
                      width: 110,
                      height: 12,
                      color: color.withValues(alpha: .55),
                    ),
                ],
              ),
            ),
        ],
      ),
      LayerTreeDetail(:final root) => SizedBox.square(
        dimension: 240,
        child: CustomPaint(
          painter: _MiniLayerTreePainter(root: root, palette: p),
        ),
      ),
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
                ],
              ),
            ),
        ],
      ),
    };
  }
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

/// The render tree's staircase, miniaturized for a landed plane: small
/// colored node boxes and elbow connectors, no text.
class _MiniRenderTreePainter extends CustomPainter {
  _MiniRenderTreePainter({required this.root, required this.palette});

  final RenderNode root;
  final Palette palette;

  static const _indent = 22.0;
  static const _elbow = 11.0;
  static const _box = Size(22, 13);
  static const _pitch = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = <(RenderNode, int, List<bool>)>[];
    void walk(RenderNode node, int depth, List<bool> lasts) {
      rows.add((node, depth, lasts));
      for (var i = 0; i < node.children.length; i++) {
        walk(node.children[i], depth + 1, [
          ...lasts,
          i == node.children.length - 1,
        ]);
      }
    }

    walk(root, 0, const []);
    final maxDepth = rows.fold(0, (m, row) => math.max(m, row.$2));
    final content = Size(
      maxDepth * _indent + _box.width,
      rows.length * _pitch,
    );
    final scale = math.min(
      size.width / content.width,
      size.height / content.height,
    );
    canvas.scale(scale);
    final linePaint = Paint()
      ..color = palette.textSecondary.withValues(alpha: .55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < rows.length; i++) {
      final (node, depth, lasts) = rows[i];
      final y = i * _pitch;
      final mid = y + _box.height / 2;
      for (var a = 1; a < depth; a++) {
        if (lasts[a - 1]) continue;
        final x = a * _indent - _elbow;
        canvas.drawLine(Offset(x, y), Offset(x, y + _pitch), linePaint);
      }
      if (depth > 0) {
        final x = depth * _indent - _elbow;
        canvas
          ..drawLine(
            Offset(x, y),
            Offset(x, lasts.last ? mid : y + _pitch),
            linePaint,
          )
          ..drawLine(
            Offset(x, mid),
            Offset(depth * _indent, mid),
            linePaint,
          );
      }
      final box = Rect.fromLTWH(
        depth * _indent,
        y + (_pitch - _box.height) / 2 - 3,
        _box.width,
        _box.height,
      );
      final color = node.widget.color ?? palette.textTertiary;
      if (node.count > 1) {
        for (var deck = 2; deck >= 0; deck--) {
          canvas.drawRect(
            box.translate(deck * 3.0, -deck * 3.0),
            Paint()
              ..color = deck == 0
                  ? Color.alphaBlend(
                      color.withValues(alpha: .85),
                      palette.surface,
                    )
                  : color.withValues(alpha: .85),
          );
        }
      } else {
        canvas.drawRect(box, Paint()..color = color.withValues(alpha: .85));
      }
    }
  }

  @override
  bool shouldRepaint(_MiniRenderTreePainter oldDelegate) =>
      root != oldDelegate.root || palette != oldDelegate.palette;
}

/// The layer tree's nested boxes, miniaturized for a landed plane: outlined
/// boxes in each pusher's color, filled tiles for pictures.
class _MiniLayerTreePainter extends CustomPainter {
  _MiniLayerTreePainter({required this.root, required this.palette});

  final LayerNode root;
  final Palette palette;

  static const _pad = 8.0;
  static const _gap = 6.0;
  static const _tile = Size(40, 26);

  Size _measure(LayerNode node) {
    if (node.picture != null) return _tile;
    var width = 0.0;
    var height = 0.0;
    for (final child in node.children) {
      final s = _measure(child);
      width = math.max(width, s.width);
      height += s.height + _gap;
    }
    if (node.children.isNotEmpty) height -= _gap;
    return Size(width + 2 * _pad + 4, height + 2 * _pad + 4);
  }

  void _draw(Canvas canvas, LayerNode node, Rect rect) {
    final color = node.widget?.color ?? palette.textTertiary;
    if (node.picture != null) {
      canvas.drawRect(
        rect,
        Paint()..color = palette.text.withValues(alpha: .8),
      );
      var x = rect.left;
      for (final source in node.sources) {
        canvas.drawRect(
          Rect.fromLTWH(x, rect.top, 4, rect.height),
          Paint()..color = source.color ?? palette.textTertiary,
        );
        x += 4;
      }
      return;
    }
    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: .9)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    var y = rect.top + _pad + 2;
    for (final child in node.children) {
      final s = _measure(child);
      _draw(
        canvas,
        child,
        Rect.fromLTWH(rect.left + _pad + 2, y, s.width, s.height),
      );
      y += s.height + _gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final content = _measure(root);
    final scale = math.min(
      size.width / content.width,
      size.height / content.height,
    );
    canvas.scale(scale);
    _draw(canvas, root, Offset.zero & content);
  }

  @override
  bool shouldRepaint(_MiniLayerTreePainter oldDelegate) =>
      root != oldDelegate.root || palette != oldDelegate.palette;
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
