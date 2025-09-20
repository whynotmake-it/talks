import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:rivership/rivership.dart';

class Surface extends StatelessWidget {
  const Surface({
    required this.state,
    required this.phase,

    super.key,
  });

  final SurfaceState state;
  final int phase;

  @override
  Widget build(BuildContext context) {
    return SequenceMotionBuilder<int, double>(
      sequence: state.rotateLight
          ? StepSequence(
              const [0, 2 * pi],
              loop: LoopMode.seamless,
              motion: Motion.linear(
                Duration(seconds: 2),
              ),
            )
          : StepSequence(const [0.0], motion: Motion.smoothSpring()),
      converter: SingleMotionConverter(),
      builder: (context, lightDirection, _, child) => AnimatedSizeSwitcher(
        child: SequenceMotionBuilder(
          sequence: StepSequence.withMotions(
            [
              (1.0, Motion.interactiveSpring()),
              (0.95, Motion.interactiveSpring().trimmed(endTrim: .8)),
              (1.0, Motion.smoothSpring()),
            ],
          ),

          restartTrigger: phase,
          converter: SingleMotionConverter(),
          builder: (context, scale, _, child) {
            // Calculate shadow offsets based on light direction and elevation
            final closeDistance = state.elevation * 1;
            final farDistance = state.elevation * 2;

            final closeShadowOffset = Offset(
              sin(lightDirection + pi) * closeDistance,
              -cos(lightDirection + pi) * closeDistance,
            );

            final farShadowOffset = Offset(
              sin(lightDirection + pi) * farDistance,
              -cos(lightDirection + pi) * farDistance,
            );

            return Center(
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  children: [
                    // Main surface container
                    Container(
                      decoration: ShapeDecoration(
                        color: state.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(state.radius),
                        ),
                        shadows: state.elevation > 0
                            ? [
                                // Far, soft shadow for ambient depth
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  offset: farShadowOffset,
                                  blurRadius: state.elevation * 1.5,
                                  spreadRadius: state.elevation * 0.2,
                                ),
                                // Close, sharp shadow for definition
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  offset: closeShadowOffset,
                                  blurRadius: state.elevation,
                                ),
                              ]
                            : null,
                      ),
                      foregroundDecoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(state.radius),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: state.gradientOpacity,
                            ),
                            state.color.withValues(
                              alpha: state.gradientOpacity,
                            ),
                          ],
                          stops: const [0, 1],
                          transform: GradientRotation(lightDirection),
                        ),
                        image: DecorationImage(
                          image: AssetImage('assets/noise.png'),
                          fit: BoxFit.scaleDown,
                          alignment:
                              Alignment.center -
                              Alignment(
                                sin(lightDirection) * 0.02,
                                -cos(lightDirection) * 0.02,
                              ),
                          colorFilter: ColorFilter.mode(
                            state.color.withValues(alpha: .5),
                            BlendMode.colorDodge,
                          ),
                          repeat: ImageRepeat.repeat,
                          scale: 1 - .5 * (state.noiseOpacity),
                          opacity: state.noiseOpacity.clamp(0, 1),
                        ),
                      ),
                      child: const SizedBox.square(
                        dimension: 400,
                      ),
                    ),
                    // Gradient border using ShaderMask
                    if (state.gradientOpacity > 0)
                      ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(
                                alpha: state.borderOpacity,
                              ),
                              Colors.transparent,
                            ],
                            transform: GradientRotation(lightDirection),
                          ).createShader(bounds);
                        },
                        child: Container(
                          foregroundDecoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(state.radius),
                              side: BorderSide(
                                width: 5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          child: const SizedBox.square(
                            dimension: 400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SurfaceState with EquatableMixin {
  const SurfaceState({
    this.radius = 0,
    this.noiseOpacity = 0,
    this.color = Colors.transparent,
    this.elevation = 0,
    this.gradientOpacity = 0,
    this.borderOpacity = 0,
    this.rotateLight = false,
    this.useLiquidGlass = false,
  });

  final double radius;
  final double noiseOpacity;
  final Color color;
  final double elevation;
  final double gradientOpacity;
  final double borderOpacity;
  final bool rotateLight;
  final bool useLiquidGlass;

  @override
  List<double> get props => [
    radius,
    noiseOpacity,
    color.r,
    color.g,
    color.b,
    color.a,
    elevation,
    gradientOpacity,
    borderOpacity,
    if (rotateLight) 1.0 else 0.0,
    if (useLiquidGlass) 1.0 else 0.0,
  ];
}

final surfaceStateConverter = MotionConverter<SurfaceState>.custom(
  normalize: (value) => value.props,
  denormalize: (value) => SurfaceState(
    radius: value[0],
    noiseOpacity: value[1],
    color: Color.from(
      red: value[2],
      green: value[3],
      blue: value[4],
      alpha: value[5],
    ),
    elevation: value[6],
    gradientOpacity: value[7],
    borderOpacity: value[8],
    rotateLight: value[9] > 0.5,
    useLiquidGlass: value[10] > 0.5,
  ),
);
