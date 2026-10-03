// Scratch book: two ways to turn the whole screen gray, and what each costs
// the GPU on Impeller. Not part of the deck.
//
//   flutter run -d macos -t scratch_book/blend_vs_backdrop.dart
//   flutter run --profile -d <iphone-id> -t scratch_book/blend_vs_backdrop.dart
//
// (This app has no ios/ folder yet. The iPhone run needs one first, for
// example from `flutter create --platforms=ios .`.)
//
// Tap "mode" to cycle:
//
//   none  the colorful page, nothing on top.
//
//   A     one full-screen gray rect, painted with BlendMode.saturation. That
//         is an "advanced" blend: the GPU has to read the pixel that is
//         already there. Impeller (display_list/canvas.cc) checks
//         SupportsFramebufferFetch(). On Metal that is any real iPhone
//         (Apple2+ GPU family) but not the simulator. With fetch, the blend
//         reads the pixel inside the current render pass: one extra draw
//         call ("Framebuffer Advanced Blend Filter"), no new pass. Without
//         fetch, Impeller ends the pass, copies, blends, and goes on.
//
//   B     a full-screen BackdropFilter whose filter is a grayscale
//         ColorFilter.matrix. A backdrop filter has to read everything drawn
//         so far, so Impeller ends the render pass at that point. Because
//         the scene has a backdrop filter, it also draws the page into an
//         offscreen texture from the start. At the filter it stores that
//         texture, then starts a new pass and draws the whole texture back
//         through the color matrix ("Color Matrix Filter"). With framebuffer
//         fetch that new pass can be the onscreen one; without it, one more
//         blit to the screen follows at the end.
//
// Hypothesis to measure: A stays at one render pass per frame, B needs at
// least two plus a full-screen texture read and redraw, so B costs more GPU
// time. Treat this as a guess until the captures say so.
//
// What to look at (iPhone, profile mode, "animate" on so every vsync draws):
//
//   Xcode GPU frame capture (Debug > Capture GPU Workload, or the camera
//   button in the debug bar). Count the render command encoders per frame
//   ("EntityPass Render Pass") in each mode. In A, look for the "Framebuffer
//   Advanced Blend Filter" draw in the same encoder as the page. In B, look
//   for the extra encoder and the "Color Matrix Filter" draw. There is no
//   blur here, so no "Gaussian Blur Filter" passes are expected.
//
//   Instruments, Metal System Trace. Record a few seconds per mode and
//   compare the GPU time per frame on the GPU track (and the number of
//   encoders per frame).
//
// On Android, Android GPU Inspector shows the same: render passes per frame
// and GPU time. Whether Vulkan has framebuffer fetch depends on the device.
//
// The two grays are close but not the same math. Impeller's saturation
// blend uses the W3C non-separable luminosity weights (0.3, 0.59, 0.11),
// and keeps the brightness of the page pixel. The matrix below uses the
// same weights, so the two modes should look almost alike. Rec. 709 weights
// (0.2126, 0.7152, 0.0722) would be the usual choice for a gray filter.

import 'package:flutter/widgets.dart';

void main() => runApp(const BlendVsBackdropApp());

enum _Mode {
  none('none'),
  blend('A: saturation blend rect'),
  backdrop('B: BackdropFilter grayscale matrix');

  const _Mode(this.label);

  final String label;

  _Mode get next => _Mode.values[(index + 1) % _Mode.values.length];
}

/// Gray from the same luminosity weights the saturation blend uses.
///
/// ColorFilter implements ImageFilter in dart:ui, so BackdropFilter takes it
/// as its filter directly.
const _grayscale = ColorFilter.matrix(<double>[
  0.3, 0.59, 0.11, 0, 0, //
  0.3, 0.59, 0.11, 0, 0, //
  0.3, 0.59, 0.11, 0, 0, //
  0, 0, 0, 1, 0, //
]);

class BlendVsBackdropApp extends StatefulWidget {
  const BlendVsBackdropApp({super.key});

  @override
  State<BlendVsBackdropApp> createState() => _BlendVsBackdropAppState();
}

class _BlendVsBackdropAppState extends State<BlendVsBackdropApp>
    with SingleTickerProviderStateMixin {
  // The only thing that asks for frames on its own. With it running, every
  // vsync makes a frame, so Instruments sees a steady stream.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  var _mode = _Mode.none;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleAnimate() {
    setState(() {
      if (_controller.isAnimating) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _BusyPage(turns: _controller),
          // The effect sits on top of the page and under the controls.
          switch (_mode) {
            _Mode.none => const SizedBox.shrink(),
            _Mode.blend => const CustomPaint(painter: _SaturationPainter()),
            // No ClipRect around it, so it filters the whole screen.
            _Mode.backdrop => const BackdropFilter(
              filter: _grayscale,
              child: SizedBox.expand(),
            ),
          },
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(_mode.label),
                  const Spacer(),
                  Row(
                    children: [
                      _Button(
                        label: 'mode',
                        onTap: () => setState(() => _mode = _mode.next),
                      ),
                      const SizedBox(width: 12),
                      _Button(
                        label: _controller.isAnimating
                            ? 'animate: on'
                            : 'animate: off',
                        onTap: _toggleAnimate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mode A: one rect over the whole screen with an advanced blend mode.
///
/// The gray has no saturation, so the result keeps each page pixel's
/// brightness and drops its color. Any gray works; mid-gray is just clear.
class _SaturationPainter extends CustomPainter {
  const _SaturationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFF808080)
        ..blendMode = BlendMode.saturation,
    );
  }

  @override
  bool shouldRepaint(_SaturationPainter oldDelegate) => false;
}

/// A loud, colorful page, so gray is easy to spot. The spinning square is
/// part of the page, so the effect has to process a changing picture.
class _BusyPage extends StatelessWidget {
  const _BusyPage({required this.turns});

  final Animation<double> turns;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C3AED),
            Color(0xFFDB2777),
            Color(0xFFF59E0B),
            Color(0xFF10B981),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Align(
            alignment: Alignment(-0.8, -0.6),
            child: _Blob(size: 220, color: Color(0xFF22D3EE)),
          ),
          const Align(
            alignment: Alignment(0.9, -0.2),
            child: _Blob(size: 180, color: Color(0xFFFACC15)),
          ),
          const Align(
            alignment: Alignment(-0.6, 0.7),
            child: _Blob(size: 260, color: Color(0xFFEF4444)),
          ),
          const Align(
            alignment: Alignment(0.7, 0.8),
            child: _Blob(size: 140, color: Color(0xFF3B82F6)),
          ),
          Align(
            alignment: const Alignment(0, -0.05),
            child: RotationTransition(
              turns: turns,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment(0, 0.45),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Build to Burn',
                  style: TextStyle(
                    color: Color(0xFFFDE047),
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'red  green  blue',
                  style: TextStyle(color: Color(0xFF4ADE80), fontSize: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft colored circle.
class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// The current mode, big enough to read in a screen recording.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC111827),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFF9FAFB),
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A plain button: no ink, no splash, so a tap makes one frame and no more.
class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC111827),
          border: Border.all(color: const Color(0xFF9CA3AF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFF3F4F6), fontSize: 16),
        ),
      ),
    );
  }
}
