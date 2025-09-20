import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

enum GradientEdge {
  bottom,
  top,
  left,
  right,
}

class DecorativeGradient extends StatelessWidget {
  const DecorativeGradient({
    required this.intensityFactor,
    this.colors,
    this.animationSpeed = 1.0,
    this.radiusFactor = 1.0,
    this.edge = GradientEdge.bottom,
    this.child,
    super.key,
  });

  final double intensityFactor;

  final double animationSpeed;

  final double radiusFactor;

  /// The edge along which the gradient balls will be positioned.
  final GradientEdge edge;

  /// The colors for this gradient.
  ///
  /// If null, the default ClickUp colors will be used.
  final List<Color>? colors;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors =
        this.colors ??
        [
          Colors.pinkAccent,
          const Color.fromARGB(255, 24, 197, 255),
          const Color.fromARGB(255, 255, 255, 137),
        ];

    return Stack(
      children: [
        Positioned.fill(
          child: SingleMotionBuilder(
            value: intensityFactor,
            motion: const CupertinoMotion.smooth(
              duration: Duration(milliseconds: 300),
            ),
            builder: (context, amplitude, child) {
              final speed = animationSpeed + amplitude;
              return SequenceMotionBuilder<int, double>(
                converter: MotionConverter.single,
                playing: speed > 0,
                sequence: StepSequence(
                  const [0.0, 1.0],
                  loop: LoopMode.seamless,
                  motion: Motion.linear(
                    switch (speed) {
                      0 => Duration(seconds: 20),
                      _ => const Duration(milliseconds: 8000) * (1 / speed),
                    },
                  ),
                ),
                builder: (context, movementValue, _, child) {
                  return ClipRect(
                    child: CustomPaint(
                      painter: _GradientPainter(
                        amplitude,
                        movementValue,
                        radiusFactor,
                        colors: colors,
                        edge: edge,
                        darkMode:
                            Theme.of(context).brightness == Brightness.dark,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Noise texture overlay
        Positioned.fill(
          child: ClipRect(
            child: ShaderMask(
              shaderCallback: (bounds) {
                final (begin, end) = switch (edge) {
                  GradientEdge.bottom => (
                    Alignment.bottomCenter,
                    Alignment.topCenter,
                  ),
                  GradientEdge.top => (
                    Alignment.topCenter,
                    Alignment.bottomCenter,
                  ),
                  GradientEdge.left => (
                    Alignment.centerLeft,
                    Alignment.centerRight,
                  ),
                  GradientEdge.right => (
                    Alignment.centerRight,
                    Alignment.centerLeft,
                  ),
                };

                final relativeExtent = switch (edge) {
                  GradientEdge.bottom ||
                  GradientEdge.top => bounds.width / bounds.height,
                  GradientEdge.left ||
                  GradientEdge.right => bounds.height / bounds.width,
                };

                final factor =
                    (radiusFactor - radiusFactor * intensityFactor) *
                    relativeExtent /
                    colors.length;

                return LinearGradient(
                  begin: begin,
                  end: end,
                  colors: [
                    Colors.white.withValues(alpha: .4),
                    Colors.transparent,
                  ],
                  stops: [factor * .1, factor * 1.0],
                ).createShader(bounds);
              },
              child: Image.asset(
                'assets/noise.png',
                fit: BoxFit.scaleDown,
                scale: 2,
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
        ),
        if (child case final child?) child,
      ],
    );
  }
}

class _GradientPainter extends CustomPainter {
  _GradientPainter(
    this.amplitude,
    this.animationValue,
    this.radiusFactor, {
    required this.colors,
    required this.edge,
    required this.darkMode,
  });

  final double amplitude;
  final double animationValue;
  final double radiusFactor;
  final List<Color> colors;
  final GradientEdge edge;
  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    final ballCount = colors.length;

    // Calculate ball diameter and radius based on edge orientation
    final ballDiameter = switch (edge) {
      GradientEdge.bottom || GradientEdge.top => size.width / ballCount,
      GradientEdge.left || GradientEdge.right => size.height / ballCount,
    };

    for (var i = 0; i < ballCount; i++) {
      final amplitudeEffect = 1.0 + (amplitude * 2.0);
      final radius = (ballDiameter / 2) * radiusFactor;

      // how far the balls are pushed off-screen
      final pushedOff = radius * (1 - amplitude);

      final (baseX, baseY) = switch (edge) {
        GradientEdge.bottom => (
          (size.width / ballCount) * i + (size.width / ballCount) / 2,
          size.height + pushedOff,
        ),
        GradientEdge.top => (
          (size.width / ballCount) * i + (size.width / ballCount) / 2,
          0 - pushedOff,
        ),
        GradientEdge.left => (
          0 - pushedOff,
          (size.height / ballCount) * i + (size.height / ballCount) / 2,
        ),
        GradientEdge.right => (
          size.width + pushedOff,
          (size.height / ballCount) * i + (size.height / ballCount) / 2,
        ),
      };

      // Sine wave motion based on edge orientation
      final wavePhase =
          animationValue * 2 * math.pi +
          i * (math.pi / 2); // 90 degree phase offset between balls
      final waveAmplitude = 30.0 * amplitudeEffect;

      final (xOffset, yOffset) = switch (edge) {
        GradientEdge.bottom || GradientEdge.top => (
          math.sin(wavePhase) * waveAmplitude, // Horizontal movement
          0.0,
        ),
        GradientEdge.left || GradientEdge.right => (
          0.0,
          math.sin(wavePhase) * waveAmplitude, // Vertical movement
        ),
      };

      final center = Offset(
        baseX + xOffset,
        baseY + yOffset,
      );

      paint
        ..shader =
            RadialGradient(
              colors: [
                colors[i % colors.length].withValues(alpha: 1),
                colors[i % colors.length].withValues(alpha: 0.5),
                colors[i % colors.length].withValues(alpha: 0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromCircle(center: center, radius: radius),
            )
        ..blendMode = darkMode ? BlendMode.colorDodge : BlendMode.darken;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _GradientPainter) {
      return oldDelegate.amplitude != amplitude ||
          oldDelegate.animationValue != animationValue ||
          oldDelegate.edge != edge ||
          !listEquals(oldDelegate.colors, colors) ||
          oldDelegate.darkMode != darkMode;
    }
    return true;
  }
}
