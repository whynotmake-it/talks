import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

class HapticStudioSlide extends FlutterDeckSlideWidget {
  const HapticStudioSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          title: 'Haptics Studio',
          route: '/haptic-studio',
          steps: 3,
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlideStepsBuilder(
      builder: (context, step) => SingleContentSlideTemplate(
        title: const Text('Haptic Feedback'),
        mainContent: AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          child: _buildContent(step),
        ),
      ),
    );
  }

  Widget _buildContent(int step) {
    switch (step) {
      case 1:
        return Center(
          key: ValueKey('studio'),
          child: Image.asset(
            'assets/studio.png',
            fit: BoxFit.contain,
          ),
        );
      case 2:
        return Center(
          key: ValueKey('export'),
          child: Image.asset(
            'assets/studio_export.png',
            fit: BoxFit.contain,
          ),
        );
      case 3:
        return const _VibratingDeviceWithVideo();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _VibratingDeviceWithVideo extends HookWidget {
  const _VibratingDeviceWithVideo();

  @override
  Widget build(BuildContext context) {
    final vibrationOffset = useState(Offset.zero);
    final vibrationEffects = useState<List<_VibrationEffect>>([]);
    final deviceKey = useState(GlobalKey());

    useEffect(() {
      // Timer for continuous vibration
      final vibrationTimer = Timer.periodic(
        const Duration(milliseconds: 80),
        (_) {
          final random = Random();
          vibrationOffset.value = Offset(
            (random.nextDouble() - 0.5) * 8, // -4 to 4 pixels
            (random.nextDouble() - 0.5) * 8,
          );
        },
      );

      // Timer for comic vibration effects around device
      final effectsTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) {
          final effects = <_VibrationEffect>[];

          // Generate effects around device corners/edges
          final deviceRect = _getDeviceRect(deviceKey.value);
          if (deviceRect != null) {
            final effectCount = Random().nextInt(4) + 2; // 2-5 effects
            for (int i = 0; i < effectCount; i++) {
              effects.add(_VibrationEffect.aroundDevice(deviceRect));
            }
          }

          vibrationEffects.value = effects;
        },
      );

      return () {
        vibrationTimer.cancel();
        effectsTimer.cancel();
      };
    }, []);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Main device with vibration
            Center(
              child: Transform.translate(
                offset: vibrationOffset.value,
                child: Container(
                  key: deviceKey.value,
                  child: DeviceFrame(
                    device: Devices.ios.iPhone16,
                    screen: const Center(
                      child: Video(
                        assetKey: 'assets/race.mov',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Comic vibration effects around device
            ...vibrationEffects.value.map(
              (effect) => Positioned(
                left: effect.position.dx,
                top: effect.position.dy,
                child: _VibrationEffectWidget(effect: effect),
              ),
            ),
          ],
        );
      },
    );
  }

  Rect? _getDeviceRect(GlobalKey? key) {
    if (key?.currentContext == null) return null;
    final RenderBox? renderBox =
        key!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }
}

class _VibrationEffect {
  final Offset position;
  final double rotation;
  final double scale;
  final Color color;

  const _VibrationEffect({
    required this.position,
    required this.rotation,
    required this.scale,
    required this.color,
  });

  factory _VibrationEffect.aroundDevice(Rect deviceRect) {
    final random = Random();

    // Define positions around the device (corners and edges)
    final positions = [
      // Top-left corner area
      Offset(
        deviceRect.left - 40 + random.nextDouble() * 60,
        deviceRect.top - 40 + random.nextDouble() * 60,
      ),
      // Top-right corner area
      Offset(
        deviceRect.right - 20 + random.nextDouble() * 60,
        deviceRect.top - 40 + random.nextDouble() * 60,
      ),
      // Bottom-left corner area
      Offset(
        deviceRect.left - 40 + random.nextDouble() * 60,
        deviceRect.bottom - 20 + random.nextDouble() * 60,
      ),
      // Bottom-right corner area
      Offset(
        deviceRect.right - 20 + random.nextDouble() * 60,
        deviceRect.bottom - 20 + random.nextDouble() * 60,
      ),
      // Left edge
      Offset(
        deviceRect.left - 30 + random.nextDouble() * 40,
        deviceRect.top +
            deviceRect.height * 0.3 +
            random.nextDouble() * deviceRect.height * 0.4,
      ),
      // Right edge
      Offset(
        deviceRect.right - 10 + random.nextDouble() * 40,
        deviceRect.top +
            deviceRect.height * 0.3 +
            random.nextDouble() * deviceRect.height * 0.4,
      ),
      // Top edge
      Offset(
        deviceRect.left +
            deviceRect.width * 0.3 +
            random.nextDouble() * deviceRect.width * 0.4,
        deviceRect.top - 30 + random.nextDouble() * 40,
      ),
      // Bottom edge
      Offset(
        deviceRect.left +
            deviceRect.width * 0.3 +
            random.nextDouble() * deviceRect.width * 0.4,
        deviceRect.bottom - 10 + random.nextDouble() * 40,
      ),
    ];

    final selectedPosition = positions[random.nextInt(positions.length)];

    return _VibrationEffect(
      position: selectedPosition,
      rotation: random.nextDouble() * 2 * pi,
      scale: 0.6 + random.nextDouble() * 0.4, // 0.6 to 1.0
      color: [
        Colors.yellow.withOpacity(0.9),
        Colors.orange.withOpacity(0.9),
        Colors.red.withOpacity(0.8),
        Colors.white.withOpacity(0.7),
      ][random.nextInt(4)],
    );
  }
}

class _VibrationEffectWidget extends StatelessWidget {
  const _VibrationEffectWidget({required this.effect});

  final _VibrationEffect effect;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: effect.rotation,
      child: Transform.scale(
        scale: effect.scale,
        child: CustomPaint(
          size: const Size(30, 30),
          painter: _VibrationLinePainter(color: effect.color),
        ),
      ),
    );
  }
}

class _VibrationLinePainter extends CustomPainter {
  final Color color;

  const _VibrationLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw main zigzag vibration lines
    final path = Path()
      ..moveTo(center.dx - 12, center.dy)
      ..lineTo(center.dx - 6, center.dy - 6)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + 6, center.dy + 6)
      ..lineTo(center.dx + 12, center.dy);

    canvas.drawPath(path, paint);

    // Draw radiating lines for more comic effect
    final radiatingPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Small radiating lines
    canvas.drawLine(
      Offset(center.dx - 10, center.dy - 10),
      Offset(center.dx - 6, center.dy - 6),
      radiatingPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 6, center.dy + 6),
      Offset(center.dx + 10, center.dy + 10),
      radiatingPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 10, center.dy + 10),
      Offset(center.dx - 6, center.dy + 6),
      radiatingPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 6, center.dy - 6),
      Offset(center.dx + 10, center.dy - 10),
      radiatingPaint,
    );

    // Small dots for extra comic effect
    final dotPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx - 14, center.dy - 2), 1, dotPaint);
    canvas.drawCircle(Offset(center.dx + 14, center.dy + 2), 1, dotPaint);
    canvas.drawCircle(Offset(center.dx - 2, center.dy - 14), 1, dotPaint);
    canvas.drawCircle(Offset(center.dx + 2, center.dy + 14), 1, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
