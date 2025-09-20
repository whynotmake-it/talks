import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:motor/motor.dart';

class SpringVisualizer extends HookWidget {
  const SpringVisualizer({
    required this.duration,
    required this.bounce,
    required this.showSpring,
    super.key,
  });

  final Duration duration;
  final double bounce;
  final bool showSpring;

  @override
  Widget build(BuildContext context) {
    final target = useState(Offset.zero);
    final playing = useState(false);

    void setPosition(Offset position, BoxConstraints constraints) {
      final localPosition = position - constraints.biggest.center(Offset.zero);
      target.value = localPosition;
    }

    return SequenceMotionBuilder<int, Offset>(
      playing: playing.value,
      sequence: StepSequence.withMotions([
        (
          target.value,
          CupertinoMotion(
            bounce: bounce,
            duration: duration,
          ),
        ),
      ]),

      converter: MotionConverter.offset,
      builder: (context, value, _, child) => Stack(
        fit: StackFit.expand,
        children: [
          if (showSpring)
            Positioned.fill(
              child: CustomPaint(
                painter: SpringPainter(
                  start: target.value.copyWith(dy: 0),
                  end: value.copyWith(dy: 0),
                  thickness: 24,
                  wireThickness: 4,
                  coils: 12,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
          Center(
            child: Transform.translate(
              offset: value.copyWith(dy: 0),
              child: SizedBox.square(
                dimension: 64,
                child: Container(
                  decoration: ShapeDecoration(
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                        width: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Transform.translate(
              offset: target.value.copyWith(dy: 0),
              child: SizedBox.square(
                dimension: 32,
                child: Container(
                  decoration: ShapeDecoration(
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                        width: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox.expand(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (details) {
                      if (details.buttons == kPrimaryMouseButton) {
                        playing.value = false;
                      }
                      setPosition(details.localPosition, constraints);
                    },
                    onPointerUp: (details) => playing.value = true,
                    onPointerMove: (details) {
                      setPosition(details.localPosition, constraints);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SpringPainter extends CustomPainter {
  const SpringPainter({
    required this.start,
    required this.end,
    this.thickness = 20.0,
    this.wireThickness = 3.0,
    this.coils = 8,
    this.minVisibleLength = 100.0,
    this.minFullLength = 200.0,
    this.color = Colors.grey,
  });

  final Offset start;
  final Offset end;
  final double thickness;
  final double wireThickness;

  final double minVisibleLength;
  final double minFullLength;

  final int coils;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the center of the canvas
    final center = Offset(size.width / 2, size.height / 2);

    // Convert relative offsets to absolute positions
    final startPoint = center + start;
    final endPoint = center + end;

    // Calculate the direction and length of the spring
    final direction = endPoint - startPoint;
    final length = direction.distance;

    // Fade out opacity so it's 0 at minVisibleLength and 1 at minFullLength
    final centerOpacity =
        (length - minVisibleLength) / (minFullLength - minVisibleLength);

    if (length == 0) return;

    // Normalize the direction vector
    final normalizedDirection = direction / length;

    // Calculate gradient alignment based on the spring direction
    // Scale the direction to use the full rectangular alignment space
    // We want to map the direction to the corners of the -1,-1 to 1,1 rectangle
    final maxComponent = math.max(
      normalizedDirection.dx.abs(),
      normalizedDirection.dy.abs(),
    );
    final scaledDirection = normalizedDirection / maxComponent;

    final gradientBegin = Alignment(
      -scaledDirection.dx,
      -scaledDirection.dy,
    );
    final gradientEnd = Alignment(
      scaledDirection.dx,
      scaledDirection.dy,
    );

    final gradient = LinearGradient(
      begin: gradientBegin,
      end: gradientEnd,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: centerOpacity),
        color.withValues(alpha: 0),
      ],
      stops: const [0.05, .5, .95],
    );

    // Create a shader from the gradient
    final gradientShader = gradient.createShader(
      Rect.fromPoints(startPoint, endPoint),
    );

    final paint = Paint()
      ..shader = gradientShader
      ..strokeWidth = wireThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Calculate perpendicular vector for spring width
    final perpendicular = Offset(
      -normalizedDirection.dy,
      normalizedDirection.dx,
    );

    // Create the spring path
    final path = Path()..moveTo(startPoint.dx, startPoint.dy);

    // Number of segments for smooth curves
    const segmentsPerCoil = 16;
    final totalSegments = coils * segmentsPerCoil;

    for (var i = 0; i <= totalSegments; i++) {
      final t = i / totalSegments;

      // Position along the spring length
      final alongSpring = startPoint + direction * t;

      // Calculate the spring oscillation
      final angle = t * coils * 2 * math.pi;
      final springOffset = perpendicular * (math.sin(angle) * thickness / 2);

      final point = alongSpring + springOffset;

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    // Draw the spring
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SpringPainter oldDelegate) {
    return start != oldDelegate.start ||
        end != oldDelegate.end ||
        thickness != oldDelegate.thickness ||
        wireThickness != oldDelegate.wireThickness ||
        coils != oldDelegate.coils ||
        color != oldDelegate.color;
  }
}
