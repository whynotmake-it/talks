import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:halofoil/halofoil.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:rivership/rivership.dart';

class Surface extends StatelessWidget {
  const Surface({
    required this.state,
    required this.phase,
    super.key,
  });

  final SurfaceState state;
  final int phase;

  static const double size = 400;

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
      builder: (context, lightDirection, _, child) => SequenceMotionBuilder(
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
          return Center(
            child: Transform.scale(
              scale: scale,
              child: AnimatedSizeSwitcher(
                duration: Duration(milliseconds: 600),
                child: switch (state.effect) {
                  SpecialEffects.none => _buildNoEffect(
                    lightDirection,
                  ),
                  SpecialEffects.halofoil => _buildHalofoil(lightDirection),
                  SpecialEffects.liquidGlass => _buildLiquidGlass(
                    lightDirection,
                  ),
                  SpecialEffects.liquidMetal => _buildNoEffect(
                    lightDirection,
                  ),
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoEffect(double lightDirection) {
    // Calculate shadow offsets based on light direction and elevation
    final closeDistance = state.elevation * .5;
    final farDistance = state.elevation * 2;

    final closeShadowOffset = Offset(
      sin(lightDirection + pi) * closeDistance,
      -cos(lightDirection + pi) * closeDistance,
    );

    final farShadowOffset = Offset(
      sin(lightDirection + pi) * farDistance,
      -cos(lightDirection + pi) * farDistance,
    );

    final lightColor = HctTools.lerpBlend(
      Colors.white,
      state.color,
      0.05,
    )!;
    final shadowColor = HctTools.lerpBlend(
      Colors.black,
      state.color,
      0.8,
    )!;
    return Stack(
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
                      color: shadowColor.withValues(alpha: 0.15),
                      offset: farShadowOffset,
                      blurRadius: state.elevation * 1.5,
                      spreadRadius: state.elevation * 0.2,
                    ),
                    // Close, sharp shadow for definition
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.25),
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
                lightColor.withValues(
                  alpha: state.gradientOpacity * 0.8,
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
            blendMode: BlendMode.srcIn,
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lightColor.withValues(
                    alpha: state.borderOpacity,
                  ),
                  shadowColor.withValues(
                    alpha: state.borderOpacity * 0.5,
                  ),
                ],
                transform: GradientRotation(lightDirection),
              ).createShader(bounds);
            },
            child: Container(
              foregroundDecoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(state.radius),
                  side: BorderSide(
                    width: 4,
                    color: Colors.white,
                  ),
                ),
              ),
              child: const SizedBox.square(dimension: size),
            ),
          ),
      ],
    );
  }

  Widget _buildLiquidGlass(double lightDirection) {
    return Stack(
      key: ValueKey(SpecialEffects.liquidGlass),
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -800,
          left: -800,
          right: -800,
          bottom: -800,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return RadialGradient(
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.5, 1],
              ).createShader(bounds);
            },
            child: Image.network(
              'https://picsum.photos/id/106/2400/2400',
              fit: BoxFit.cover,
            ),
          ),
        ),
        SequenceMotionBuilder(
          sequence: StepSequence.withMotions(
            const [
              (0.0, NoMotion(Duration(seconds: 1))),
              (1.0, Motion.bouncySpring()),
            ],
          ),
          converter: SingleMotionConverter(),
          builder: (context, visibility, _, child) {
            return LiquidGlass(
              settings: LiquidGlassSettings(
                lightAngle: lightDirection,
                thickness: 50 * visibility,
                lightIntensity: 1 * visibility,
                refractiveIndex: 1.25,
                blur: 4 * visibility,
                chromaticAberration: .2,
                saturation: 1.2,
              ),
              shape: LiquidRoundedSuperellipse(
                borderRadius: Radius.circular(state.radius * 1.5),
              ),
              child: SizedBox.square(dimension: size),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHalofoil(double lightDirection) {
    final angleX = sin(lightDirection);
    final angleY = -cos(lightDirection);
    return SizedBox.square(
      dimension: size,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(angleX * .2)
          ..rotateY(angleY * .2),
        alignment: FractionalOffset.center,
        child: PhysicalModel(
          color: state.color,
          borderRadius: BorderRadius.circular(state.radius),
          elevation: state.elevation,
          shadowColor: Colors.black26,
          child: Halofoil(
            angleX: angleX * .4,
            angleY: angleY * .4,
            grainAsset: 'assets/noise.png',
            borderRadius: BorderRadius.circular(state.radius),
            children: [],
          ),
        ),
      ),
    );
  }
}

enum SpecialEffects {
  none,
  halofoil,
  liquidGlass,
  liquidMetal,
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
    this.effect = SpecialEffects.none,
  });

  final double radius;
  final double noiseOpacity;
  final Color color;
  final double elevation;
  final double gradientOpacity;
  final double borderOpacity;
  final bool rotateLight;
  final SpecialEffects effect;

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
    effect.index.toDouble(),
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
    effect: SpecialEffects.values[value[10].round()],
  ),
);
