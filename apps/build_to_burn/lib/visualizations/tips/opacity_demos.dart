import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/tips/tip_kit.dart';
import 'package:flutter/widgets.dart';

/// Two overlapping circles faded with `Opacity` (a layer, one even shape),
/// next to the same circles with alpha in each paint (no layer, but the
/// overlap shows).
class AlphaInPaintDemo extends StatelessWidget {
  const AlphaInPaintDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        LayerOutline(
          child: Opacity(opacity: .45, child: _Circles(color: p.accent)),
        ),
        _Circles(color: p.accent.withValues(alpha: .45)),
      ],
    );
  }
}

class _Circles extends StatelessWidget {
  const _Circles({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget circle() => Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return SizedBox(
      width: 170,
      height: 280,
      child: Stack(
        children: [
          Positioned(top: 0, child: circle()),
          Positioned(top: 110, child: circle()),
        ],
      ),
    );
  }
}

/// Switches the demo background to stripes and back, to show which tricks
/// only work on a solid color.
class _RevealBackground extends StatelessWidget {
  const _RevealBackground({required this.builder});

  final Widget Function(BuildContext context, double t) builder;

  @override
  Widget build(BuildContext context) {
    return Loop(
      period: const Duration(seconds: 9),
      builder: (context, t) {
        final stripes = phase(t, .45, .55) - phase(t, .88, .98);
        return Stack(
          children: [
            Positioned.fill(
              child: Opacity(opacity: stripes, child: const Stripes()),
            ),
            Positioned.fill(child: builder(context, t)),
          ],
        );
      },
    );
  }
}

/// A card faded with `Opacity` (a layer), next to the same card under a
/// translucent overlay in the background color (no layer). On stripes, the
/// overlay shows.
class ColorOverlayDemo extends StatelessWidget {
  const ColorOverlayDemo({super.key});

  static const _opacity = .4;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return _RevealBackground(
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const LayerOutline(
            child: Opacity(opacity: _opacity, child: AbstractCard()),
          ),
          Stack(
            children: [
              const AbstractCard(),
              Positioned.fill(
                child: ColoredBox(
                  color: p.surface.withValues(alpha: 1 - _opacity),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A scrolling list with faded edges: with `ShaderMask` (a layer the size of
/// the list), and with gradients in the background color on top (no layer).
/// On stripes, the gradients show.
class GradientFadeDemo extends StatelessWidget {
  const GradientFadeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return _RevealBackground(
      builder: (context, t) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          LayerOutline(
            inset: 0,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0xFF000000),
                  Color(0xFF000000),
                  Color(0x00000000),
                ],
                stops: [0, .25, .75, 1],
              ).createShader(rect),
              child: _List(t: t),
            ),
          ),
          Stack(
            children: [
              _List(t: t),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        p.surface,
                        p.surface.withValues(alpha: 0),
                        p.surface.withValues(alpha: 0),
                        p.surface,
                      ],
                      stops: const [0, .25, .75, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rows scrolling up forever, at [t] of one loop.
class _List extends StatelessWidget {
  const _List({required this.t});

  final double t;

  static const _row = 76.0;
  static const _rows = 9;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    // Scrolls two rows per loop, so the loop is seamless.
    final offset = (t * 2 * _row) % _row;
    return SizedBox(
      width: 260,
      height: 520,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(0, -offset),
            child: Column(
              children: [
                for (var i = 0; i < _rows; i++)
                  Container(
                    height: _row - 20,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: i.isEven ? p.accent : p.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A layer's outline shrinks from the whole area to the shape it is for.
class TightLayerDemo extends StatelessWidget {
  const TightLayerDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Loop(
      period: const Duration(seconds: 6),
      builder: (context, t) {
        final tight = phase(t, .2, .45) - phase(t, .75, .95);
        return CustomPaint(
          painter: _ShrinkingOutline(tight: tight),
          child: Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShrinkingOutline extends CustomPainter {
  const _ShrinkingOutline({required this.tight});

  final double tight;

  @override
  void paint(Canvas canvas, Size size) {
    final loose = (Offset.zero & size).deflate(24);
    final snug = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 172,
      height: 172,
    );
    dashedRect(canvas, Rect.lerp(loose, snug, tight)!, heat);
  }

  @override
  bool shouldRepaint(_ShrinkingOutline old) => old.tight != tight;
}
