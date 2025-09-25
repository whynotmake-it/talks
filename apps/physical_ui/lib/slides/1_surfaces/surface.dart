import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:halofoil/halofoil.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:physical_ui/slides/1_surfaces/erasable_liquid_metal_logo.dart';
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
                Duration(seconds: 3),
              ),
            )
          : StepSequence(const [0.0], motion: Motion.smoothSpring()),
      converter: SingleMotionConverter(),
      // We bounce the child whenenver the phase changes
      builder: (context, lightDirection, _, child) => SequenceMotionBuilder(
        sequence: StepSequence.withMotions(
          [
            (1.0, Motion.interactiveSpring()),
            (0.95, Motion.interactiveSpring().trimmed(fromEnd: .8)),
            (1.0, Motion.smoothSpring()),
          ],
        ),
        playing: phase > 1,
        restartTrigger: phase,
        converter: SingleMotionConverter(),
        builder: (context, scale, _, child) {
          return Center(
            child: Transform.scale(
              scale: scale,
              child: AnimatedSizeSwitcher(
                clipBehavior: Clip.none,
                duration: Duration(milliseconds: 600),
                child: switch (state.effect) {
                  SpecialEffects.none => _buildNoEffect(
                    context,
                    lightDirection,
                  ),
                  SpecialEffects.halofoil => _buildHalofoil(lightDirection),
                  SpecialEffects.liquidGlass => _buildLiquidGlass(
                    lightDirection,
                  ),
                  SpecialEffects.liquidMetal => LiquidMetalLogo(
                    state: state,
                  ),
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoEffect(BuildContext context, double lightDirection) {
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
      Theme.of(context).colorScheme.secondaryContainer,
      0.5,
    )!;
    final shadowColor = HctTools.lerpBlend(
      Theme.of(context).colorScheme.onSecondaryContainer,
      state.color,
      0.5,
    )!;
    return Stack(
      key: ValueKey(SpecialEffects.none),
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
                      color: shadowColor.withValues(alpha: 0.25),
                      offset: farShadowOffset,
                      blurRadius: state.elevation * 1.5,
                      spreadRadius: state.elevation * 0.2,
                    ),
                    // Close, sharp shadow for definition
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.8),
                      offset: closeShadowOffset,
                      blurRadius: closeDistance * 2,
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
                  alpha: state.gradientOpacity * 1,
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
                  Colors.white.withValues(
                    alpha: state.borderOpacity,
                  ),
                  lightColor.withAlpha(0),
                ],
                stops: const [0, .8],
                transform: GradientRotation(lightDirection),
              ).createShader(bounds);
            },
            child: Container(
              foregroundDecoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(state.radius),
                  side: BorderSide(
                    width: 3,
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
          top: -400,
          left: -400,
          right: -400,
          bottom: -400,
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
            child: Image.asset(
              'assets/flowers.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        SequenceMotionBuilder(
          sequence: StepSequence.withMotions(
            const [
              (0.0, NoMotion(Duration(milliseconds: 700))),
              (1.0, Motion.bouncySpring()),
            ],
          ),
          converter: SingleMotionConverter(),
          builder: (context, visibility, _, child) {
            return LiquidGlassLayer(
              settings: LiquidGlassSettings(
                lightAngle: lightDirection,
                thickness: 80 * visibility,
                lightIntensity: 1 * visibility,
                refractiveIndex: 1.25,
                blur: 4 * visibility,
                chromaticAberration: .2,
                saturation: 1.2,
                blend: 50,
                glassColor: Colors.white.withValues(alpha: visibility * 0.2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SequenceMotionBuilder(
                    sequence: StepSequence(
                      const [
                        Offset(-300, 150),
                        Offset(300, -150),
                      ],
                      motion: CupertinoMotion.snappy(
                        duration: Duration(seconds: 2),
                        snapToEnd: true,
                      ).trimmed(fromEnd: .5),
                      loop: LoopMode.pingPong,
                    ),
                    converter: OffsetMotionConverter(),
                    builder: (context, value, phase, child) =>
                        Transform.translate(
                          offset: value,
                          child: child,
                        ),
                    child: LiquidGlass.inLayer(
                      child: SizedBox.square(dimension: 100),
                      shape: LiquidOval(),
                    ),
                  ),
                  LiquidGlass.inLayer(
                    shape: LiquidRoundedSuperellipse(
                      borderRadius: Radius.circular(state.radius * 1.5),
                    ),
                    child: SizedBox.square(dimension: size),
                  ),
                ],
              ),
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
      key: ValueKey(SpecialEffects.halofoil),
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
            children: const [
              Icon(
                Icons.auto_awesome_rounded,
                size: 200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SpecialEffects {
  none,
  halofoil,
  liquidMetal,
  liquidGlass,
}

class SurfaceState with EquatableMixin {
  const SurfaceState({
    this.radius = 0,
    this.noiseOpacity = 0,
    this.color = Colors.black26,
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
    effect:
        SpecialEffects.values[value[10].round().clamp(
          0,
          SpecialEffects.values.length - 1,
        )],
  ),
);
