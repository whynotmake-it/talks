import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

/// The validation scenes. The model predicts each one in a widget test
/// (test/predict_test.dart) and the app renders it on a device
/// (lib/main.dart) so a GPU trace can be compared with the prediction.
///
/// Each scene makes one distinct claim about Impeller's pass structure.
/// They avoid text, images and platform-dependent widgets except where the
/// claim is about such a widget, so test and device draw the same thing.
final Map<String, Scene> scenes = {
  for (final s in <Scene>[
    Scene(
      'plain',
      'A full-screen color and two circles: one render pass.',
      (_) => const _Circles(),
    ),
    Scene(
      'opacity_single',
      'Opacity over one child: the opacity peephole avoids a layer.',
      (_) => const Opacity(
        opacity: 0.5,
        child: ColoredBox(color: Color(0xFF2563EB)),
      ),
    ),
    Scene(
      'opacity_overlap',
      'Opacity over overlapping children: one saveLayer.',
      (_) => const Opacity(
        opacity: 0.5,
        child: Stack(
          children: [
            Positioned(left: 40, top: 100, child: _Dot(200, 0xFF93C5FD)),
            Positioned(left: 120, top: 180, child: _Dot(200, 0xFFF59E0B)),
          ],
        ),
      ),
    ),
    Scene(
      'clip_savelayer',
      'ClipRRect with Clip.antiAliasWithSaveLayer over overlapping '
          'children: one saveLayer.',
      (_) => Center(
        child: ClipRRect(
          clipBehavior: Clip.antiAliasWithSaveLayer,
          borderRadius: BorderRadius.circular(40),
          child: const SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              children: [
                Positioned(left: -20, top: -20, child: _Dot(200, 0xFF93C5FD)),
                Positioned(left: 100, top: 100, child: _Dot(200, 0xFFF59E0B)),
              ],
            ),
          ),
        ),
      ),
    ),
    Scene(
      'backdrop_blur',
      'One BackdropFilter blur: the frame starts offscreen, flips to the '
          'screen at the blur, blur = 3 passes.',
      (_) => _OverCircles(
        Positioned(
          left: 60,
          top: 200,
          width: 280,
          height: 200,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
    Scene(
      'backdrop_sigma0',
      'A BackdropFilter blur with sigma 0 (a blur animated to 0): the '
          'engine drops the filter, leaving a plain saveLayer that the '
          'opacity peephole removes. One pass.',
      (_) => _OverCircles(
        Positioned(
          left: 60,
          top: 200,
          width: 280,
          height: 200,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(),
            child: const ColoredBox(color: Color(0x332563EB)),
          ),
        ),
      ),
    ),
    Scene(
      'backdrop_in_layer',
      'A BackdropFilter blur inside a saveLayer (a ClipRRect with '
          'Clip.antiAliasWithSaveLayer): only the layer flips. The root '
          'has no backdrop of its own, so it stays on screen.',
      (_) => _OverCircles(
        Center(
          child: ClipRRect(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            borderRadius: BorderRadius.circular(32),
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                children: [
                  const Positioned(
                    left: -40,
                    top: -40,
                    child: _Dot(200, 0xFFF59E0B),
                  ),
                  Positioned(
                    left: 40,
                    top: 40,
                    width: 220,
                    height: 220,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    Scene(
      'two_backdrops',
      'Two sibling BackdropFilter blurs: two flips, two blurs.',
      (_) => _OverCircles(
        Stack(
          children: [
            for (final top in [120.0, 460.0])
              Positioned(
                left: 60,
                top: top,
                width: 280,
                height: 200,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    ),
    Scene(
      'backdrop_group',
      'The same two blurs in a BackdropGroup: one flip, one shared blur.',
      (_) => BackdropGroup(
        child: _OverCircles(
          Stack(
            children: [
              for (final top in [120.0, 460.0])
                Positioned(
                  left: 60,
                  top: top,
                  width: 280,
                  height: 200,
                  child: BackdropFilter.grouped(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    Scene(
      'image_filtered_blur',
      'ImageFiltered blur: a saveLayer plus 3 blur passes, no flip.',
      (_) => ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: const _Circles(),
      ),
    ),
    Scene(
      'box_shadow',
      'BoxShadow on a rounded box: the shadow fast path, one pass.',
      (_) => _OverCircles(
        Center(
          child: Container(
            width: 240,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(blurRadius: 30, color: Color(0x66000000)),
              ],
            ),
          ),
        ),
      ),
    ),
    Scene(
      'saturation_blend',
      'A full-screen BlendMode.saturation draw: free with framebuffer '
          'fetch, an offscreen frame + emulated blend without it.',
      (_) => _OverCircles(
        const Positioned.fill(child: CustomPaint(painter: _BlendPainter())),
      ),
    ),
    Scene(
      'savelayer_blend',
      'A canvas.saveLayer composited with BlendMode.saturation: the layer '
          'is already a texture, so framebuffer fetch blends it for free.',
      (_) => _OverCircles(
        const Positioned.fill(
          child: CustomPaint(painter: _SaveLayerBlendPainter()),
        ),
      ),
    ),
    Scene(
      'cupertino_alert',
      "The talk's hook: a CupertinoAlertDialog over the page. Its backdrop "
          'is a blur composed with a color filter.',
      (_) => const _AlertScene(),
    ),
  ])
    s.name: s,
};

class Scene {
  const Scene(this.name, this.description, this.build);
  final String name;
  final String description;
  final WidgetBuilder build;
}

class _Circles extends StatelessWidget {
  const _Circles();

  @override
  Widget build(BuildContext context) => const Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(color: Color(0xFF2563EB)),
      Positioned(left: 40, top: 170, child: _Dot(150, 0xFF93C5FD)),
      Positioned(right: 50, top: 470, child: _Dot(120, 0xFF93C5FD)),
    ],
  );
}

class _OverCircles extends StatelessWidget {
  const _OverCircles(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Stack(fit: StackFit.expand, children: [const _Circles(), child]);
}

class _Dot extends StatelessWidget {
  const _Dot(this.size, this.color);
  final double size;
  final int color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
  );
}

class _BlendPainter extends CustomPainter {
  const _BlendPainter();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..color = const Color(0xFF808080)
      ..blendMode = BlendMode.saturation,
  );

  @override
  bool shouldRepaint(_BlendPainter oldDelegate) => false;
}

class _SaveLayerBlendPainter extends CustomPainter {
  const _SaveLayerBlendPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..saveLayer(null, Paint()..blendMode = BlendMode.saturation)
      ..drawCircle(
        size.center(Offset.zero),
        120,
        Paint()..color = const Color(0xFF808080),
      )
      ..drawCircle(
        size.center(const Offset(60, 60)),
        120,
        Paint()..color = const Color(0xFFA0A0A0),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SaveLayerBlendPainter oldDelegate) => false;
}

/// The dialog is shown directly (not pushed), without text, so the widget
/// test and the device draw the same layers.
class _AlertScene extends StatelessWidget {
  const _AlertScene();

  @override
  Widget build(BuildContext context) => const _OverCircles(
    Center(
      child: SizedBox(
        width: 270,
        child: CupertinoAlertDialog(
          content: SizedBox(height: 60),
          actions: [
            CupertinoDialogAction(child: SizedBox(width: 40, height: 20)),
            CupertinoDialogAction(child: SizedBox(width: 40, height: 20)),
          ],
        ),
      ),
    ),
  );
}
