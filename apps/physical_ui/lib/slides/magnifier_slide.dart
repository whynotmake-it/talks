import 'package:flutter/material.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

// Why a RenderObject (not CustomPainter)
// Backdrop sampling: only a render object can pushLayer(BackdropFilterLayer) to transform what’s already painted. A CustomPainter can’t read the backdrop.
// Correct anchor math: you need paint-time geometry (actual size+offset) to build the focal-point matrix.
// Performance: you mutate a tiny retained layer (the filter) instead of re-recording large pictures each frame.

class MagnifierSlide extends FlutterDeckSlideWidget {
  const MagnifierSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          title: 'RawMagnifier',
          route: '/magnifier',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  static const _magnifierPseudoCode = '''
class Magnifier extends RenderBox {
  Magnifier(this.center, this.radius, this.scale);
  
  Offset center; 
  double radius; 
  double scale;

  final _layer = BackdropFilterLayer(); // retained

  @override 
  bool get alwaysNeedsCompositing => true;

  @override 
  void performLayout() => size = constraints.biggest;

  @override
  void paint(PaintingContext ctx, Offset offset) {
    final c = offset + center;// lens center in global paint coords
    
    final m = Matrix4.identity()
      ..translate(c.dx, c.dy)
      ..scale(scale, scale, 1)
      ..translate(-c.dx, -c.dy);// zoom about c

    _layer.filter = ImageFilter.matrix(m.storage, filterQuality: FilterQuality.high);
    
    final lens = Path()..addOval(Rect.fromCircle(center: c, radius: radius));
    
    ctx.pushLayer(  // clip → magnify backdrop
      ClipPathLayer(clipPath: lens),
      (inner, _) => inner.pushLayer(_layer, (__, ___) {}, Offset.zero),
      Offset.zero,
    );
  }
}''';

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('Magnifier'),
      mainContent: const Row(
        children: [
          // Left Column: Interactive Demo
          Expanded(
            child: Center(
              child: MagnifierDemo(),
            ),
          ),

          // Right Column: Code Example
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 32),
              child: CodeHighlight(
                filename: 'magnifier_implementation.dart',
                code: _magnifierPseudoCode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MagnifierDemo extends StatefulWidget {
  const MagnifierDemo({super.key});

  @override
  State<MagnifierDemo> createState() => _MagnifierDemoState();
}

class _MagnifierDemoState extends State<MagnifierDemo> {
  static const double magnifierRadius = 120;
  Offset dragGesturePosition = const Offset(150, 150);
  bool showMagnifier = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Demo Area
        Expanded(
          child: RepaintBoundary(
            child: Stack(
              children: [
                // Draggable Flutter Logo
                Center(
                  child: GestureDetector(
                    onPanStart: (details) => setState(() {
                      showMagnifier = true;
                      dragGesturePosition = details.localPosition;
                    }),
                    onPanUpdate: (details) => setState(() {
                      dragGesturePosition = details.localPosition;
                    }),
                    onPanEnd: (details) => setState(() {
                      showMagnifier = false;
                    }),
                    onPanCancel: () => setState(() {
                      showMagnifier = false;
                    }),
                    child: const Center(
                      child: FlutterLogo(size: 800),
                    ),
                  ),
                ),

                // Magnifier
                if (showMagnifier)
                  Positioned(
                    left: dragGesturePosition.dx - magnifierRadius,
                    top: dragGesturePosition.dy - magnifierRadius,
                    child: RawMagnifier(
                      decoration: MagnifierDecoration(
                        shape: CircleBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                        shadows: [
                          BoxShadow(
                            color: Colors.blueGrey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      size: const Size(
                        magnifierRadius * 2,
                        magnifierRadius * 2,
                      ),
                      magnificationScale: 2.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
