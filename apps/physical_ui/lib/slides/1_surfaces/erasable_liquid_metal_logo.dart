// ignore_for_file: depend_on_referenced_packages

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:paper_liquid_metal_logo/liquid_metal_shader_controller.dart';
import 'package:physical_ui/slides/1_surfaces/surface.dart';
import 'package:scribble/scribble.dart';

class LiquidMetalLogo extends StatefulWidget {
  const LiquidMetalLogo({
    required this.state,
    super.key,
  });

  final SurfaceState state;

  @override
  State<LiquidMetalLogo> createState() => _LiquidMetalLogoState();
}

class _LiquidMetalLogoState extends State<LiquidMetalLogo>
    with SingleTickerProviderStateMixin {
  late final controller = LiquidMetalShaderController.withDefaults(vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    setParameters();
    super.initState();
  }

  void setParameters() {
    controller
      ..speed.value = .003
      ..penSize.value = 20
      ..blur.value = 10;
  }

  @override
  void reassemble() {
    setParameters();
    super.reassemble();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 200,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        Center(
          child: RepaintBoundary(
            child: _Logo(controller, widget.state),
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo(this.controller, this.state);

  final LiquidMetalShaderController controller;
  final SurfaceState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(controller.parameters),
      builder: (context, child) {
        return ShaderBuilder(
          assetKey:
              'packages/paper_liquid_metal_logo/assets/shaders/wobble.frag',
          (context, shader, _) {
            return AnimatedSampler(
              (image, size, canvas) {
                // Calculate image aspect ratio
                final imageRatio = image.width / image.height;

                shader
                  ..setImageSampler(0, image) // Set the texture
                  ..setFloatUniforms((uniforms) {
                    uniforms
                      ..setSize(size) // uSize
                      ..setFloat(controller.time.value) // u_time
                      ..setFloat(size.width / size.height) // u_ratio
                      ..setFloat(imageRatio) // u_img_ratio
                      // Animation speed
                      ..setFloat(0.15) // u_timeScale
                      // Noise detail
                      ..setFloat(
                        2.5 * controller.patternScale.value,
                      ) // u_noiseScale
                      // Pattern size
                      ..setFloat(
                        3.0 * controller.patternScale.value,
                      ) // u_patternScale
                      // Edge effect width
                      ..setFloat(
                        controller.edge.value * 4,
                      ) // u_edgeEffectWidth
                      // Pattern intensity
                      ..setFloat(
                        0.9 * (1.0 - controller.patternBlur.value),
                      ) // u_patternIntensity
                      // Drip effect strength
                      ..setFloat(
                        100 * controller.dispersion.value,
                      ) // u_dripStrength
                      // Border deformation amount
                      ..setFloat(
                        0.046 * controller.liquid.value,
                      ) // u_borderDeformStrength
                      // Edge detection threshold
                      ..setFloat(0.68) // u_edgeThreshold
                      // Liquid effect
                      ..setFloat(controller.liquid.value); // u_liquid
                  });

                canvas.drawRect(
                  Rect.fromLTWH(0, 0, size.width, size.height),
                  Paint()..shader = shader,
                );
              },
              child: child!,
            );
          },
        );
      },

      child: ListenableBuilder(
        listenable: Listenable.merge([
          controller.blur,
          controller.penSize,
        ]),
        builder: (context, child) {
          return _Image(
            controller.blur.value,
            controller.penSize.value,
            state,
          );
        },
      ),
    );
  }
}

class _Image extends StatefulWidget {
  const _Image(this.blur, this.penSize, this.state);
  final double blur;
  final double penSize;
  final SurfaceState state;

  @override
  State<_Image> createState() => _ImageState();
}

class _ImageState extends State<_Image> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    reverseDuration: const Duration(milliseconds: 300),
  );

  late final _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  late final ScribbleNotifier scribbleNotifier;

  @override
  void initState() {
    super.initState();

    scribbleNotifier = ScribbleNotifier()..setColor(Colors.white);
    scribbleNotifier.setStrokeWidth(widget.penSize);

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _Image oldWidget) {
    scribbleNotifier.setStrokeWidth(widget.penSize);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    _opacity.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: widget.blur * 2,
          sigmaY: widget.blur * 2,
        ),
        child: Container(
          width: Surface.size,
          height: Surface.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.state.radius),
            color: Colors.black,
          ),
          child: Stack(
            children: [
              Scribble(notifier: scribbleNotifier),
            ],
          ),
        ),
      ),
    );
  }
}
