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
      CodeDetail(:final code) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in code.split('\n').take(9))
            if (line.trim().isNotEmpty) bar(line, height: 10),
        ],
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
