// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:physical_ui/slides/1_surfaces/decorative_gradient.dart';
import 'package:physical_ui/slides/1_surfaces/surface.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/big_quote_template.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

final surfacesCodeSlides = [
  BigQuoteTemplate(title: Text('How do we do this in Flutter?')),
  BasicSurfaceSlide(),
  SurfaceWithGradientSlide(),
  SurfaceWithNoiseSlide(),
  SurfaceWithShadowSlide(),
  PhysicalModelSlide(),
  CustomPainterSlide(),
  ShadersSlide(),
];

class BasicSurfaceSlide extends FlutterDeckSlideWidget {
  BasicSurfaceSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/basic_surface',
          steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: Text('1. Start with a basic colored box'),
      mainContent: SizedBox.expand(
        child: CodeHighlight(
          code: '''
Container(
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(48),
  ),
  child: SizedBox.square(dimension: 400),
)
          ''',
        ),
      ),
      secondaryContent: Surface(
        state: SurfaceState(
          color: theme.colorScheme.secondary,
          radius: 48,
        ),
        phase: 0,
      ),
    );
  }
}

class SurfaceWithGradientSlide extends FlutterDeckSlideWidget {
  SurfaceWithGradientSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/with_gradient',
          steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: Text('2. Add a gradient for lighting'),
      mainContent: SizedBox.expand(
        child: CodeHighlight(
          code: '''
Container(
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(48),
  ),
  foregroundDecoration: BoxDecoration(
    borderRadius: BorderRadius.circular(48),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.3),
        Colors.transparent,
      ],
    ),
  ),
  child: SizedBox.square(dimension: 400),
)
          ''',
        ),
      ),
      secondaryContent: Surface(
        state: SurfaceState(
          color: theme.colorScheme.secondary,
          radius: 48,
          gradientOpacity: 0.3,
          borderOpacity: 0.3,
        ),
        phase: 0,
      ),
    );
  }
}

class SurfaceWithNoiseSlide extends FlutterDeckSlideWidget {
  SurfaceWithNoiseSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/with_noise',
          steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: Text('3. Add texture with noise overlay'),
      mainContent: SizedBox.expand(
        child: CodeHighlight(
          code: '''
Container(
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(48),
  ),
  foregroundDecoration: BoxDecoration(
    borderRadius: BorderRadius.circular(48),
    gradient: LinearGradient(/* ... */),
    image: DecorationImage(
      image: AssetImage('assets/noise.png'),
      repeat: ImageRepeat.repeat,
      opacity: 0.5,
      colorFilter: ColorFilter.mode(
        Colors.blue.withOpacity(0.5),
        BlendMode.colorDodge,
      ),
    ),
  ),
  child: SizedBox.square(dimension: 400),
)
          ''',
        ),
      ),
      secondaryContent: Surface(
        state: SurfaceState(
          color: theme.colorScheme.secondary,
          radius: 48,
          gradientOpacity: 0.3,
          borderOpacity: 0.3,
          noiseOpacity: 0.5,
        ),
        phase: 0,
      ),
    );
  }
}

class SurfaceWithShadowSlide extends FlutterDeckSlideWidget {
  SurfaceWithShadowSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/with_shadow',
          steps: 2,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterDeckSlideStepsBuilder(
      builder: (context, step) {
        return ContentSlideTemplate(
          insetSecondaryContent: true,
          title: Text('4. Add depth with directional shadows'),
          mainContent: SizedBox.expand(
            child: CodeHighlight(
              code: '''
Container(
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(48),
    boxShadow: [
      // Far, soft shadow for ambient depth
      BoxShadow(
        color: Colors.black26,
        offset: Offset(8, 8),
        blurRadius: 15,
        spreadRadius: 2,
      ),
      // Close, sharp shadow for definition
      BoxShadow(
        color: Colors.black54,
        offset: Offset(4, 4),
        blurRadius: 8,
      ),
    ],
  ),
  foregroundDecoration: BoxDecoration(/* ... */),
  child: SizedBox.square(dimension: 400),
)
          ''',
            ),
          ),
          secondaryContent: AnimatedSizeSwitcher(
            transitionBuilder: AnimatedSizeSwitcher.sizeFadeTransitionBuilder,
            child: step == 1
                ? Surface(
                    state: SurfaceState(
                      color: theme.colorScheme.secondary,
                      radius: 48,
                      gradientOpacity: 0.3,
                      borderOpacity: 0.3,
                      noiseOpacity: 0.5,
                      elevation: 8,
                    ),
                    phase: 0,
                  )
                : Image.asset('assets/shadow_example.png'),
          ),
        );
      },
    );
  }
}

class PhysicalModelSlide extends FlutterDeckSlideWidget {
  PhysicalModelSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/physical_model',
          steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: Text('Tip: PhysicalShape for pre-built shadows'),
      mainContent: SizedBox.expand(
        child: CodeHighlight(
          code: '''
return PhysicalShape(
  clipper: ShapeBorderClipper(
    shape: BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(48),
    ),
  ),
  color: Colors.blue,
  elevation: 8.0,
  shadowColor: Colors.black26,
  child: SizedBox.square(dimension: 400),
);
          ''',
        ),
      ),
      secondaryContent: Center(
        child: PhysicalShape(
          clipper: ShapeBorderClipper(
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(48),
            ),
          ),
          color: theme.colorScheme.secondary,
          elevation: 12,
          shadowColor: theme.colorScheme.secondary,
          child: SizedBox.square(dimension: Surface.size),
        ),
      ),
    );
  }
}

class CustomPainterSlide extends FlutterDeckSlideWidget {
  CustomPainterSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/custom_painter',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: Text('CustomPainter for advanced effects'),
      mainContent: SizedBox.expand(
        child: CodeHighlight(
          code: '''
class _GradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30);
    
    for (var i = 0; i < colors.length; i++) {
      final center = Offset(/* animated position */);
      
      paint.shader = RadialGradient(
        colors: [
          colors[i].withOpacity(1.0),
          colors[i].withOpacity(0.0),
        ],
      ).createShader(bounds);
      
      canvas.drawCircle(center, radius, paint);
    }
  }
}
          ''',
        ),
      ),
      secondaryContent: Center(
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surfaceContainer,
                theme.colorScheme.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(48),
            ),
          ),
          child: SizedBox.square(
            dimension: Surface.size,
            child: DecorativeGradient(
              intensityFactor: .7,
              radiusFactor: 5,
              animationSpeed: 4,
            ),
          ),
        ),
      ),
    );
  }
}

class ShadersSlide extends FlutterDeckSlideWidget {
  ShadersSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/shaders',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: Text('Fragment Shaders for everything beyond'),
      mainContent: SizedBox.expand(
        child: CodeHighlight(
          code: '''
import 'dart:ui';
import 'package:flutter_shaders/flutter_shaders.dart';

final myShaderProgram = await FragmentProgram.fromAsset(
  'shaders/my_shader.glsl',
);

AnimatedSampler(
  (image, size, canvas) {
    shader.setImageSampler(0, image);
    shader.setFloat(0, size.width); // iResolution.x
    shader.setFloat(1, size.height); // iResolution.y
    return child;
  },
  child: Container(/* your content */),
);


// IMPELLER ONLY
// Will set size and sampler automatically
ImageFiltered(
  filter: ImageFilter.shader(myShaderProgram),
  child: Container(/* your content */),
)

BackdropFilter(
  filter: ImageFilter.shader(myShaderProgram),
  child: Container(/* your content */),
)

// Fragment Shader Pseudocode
#version 460 core

uniform sampler2D background;
uniform vec2 iResolution;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    
    // Calculate glass distortion
    vec2 distortion = refract(uv, normal, 1.5);
    
    // Sample background with chromatic aberration
    vec3 color = texture(background, distortion).rgb;
    
    fragColor = vec4(color, transparency);
}
          ''',
        ),
      ),
      secondaryContent: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: SizedBox.square(
            dimension: Surface.size,
            child: Surface(
              state: SurfaceState(
                effect: SpecialEffects.liquidGlass,
                radius: 80,
                rotateLight: true,
              ),

              phase: 0,
            ),
          ),
        ),
      ),
    );
  }
}
