import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:motor/motor.dart';
import 'package:physical_ui/slides/dimensionality_slides.dart';
// motor import not required directly for these code snippets at compile time
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// A group of slides that walk through the core Motor concepts.
final motorConceptSlides = <FlutterDeckSlideWidget>[
  _MotionSlide(),
  _MotionConverterSlide(),
  _MotionControllerSlide(),
  _MotionBuilderSlide(),
];

class _MotionSlide extends FlutterDeckSlideWidget {
  _MotionSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/motor-motion',
          title: 'Motion',
          speakerNotes: timSlideNotesHeader
        ),
      );

  static const _code = '''
import 'package:motor/motor.dart';

// Motion encapsulates timing + curve/physics

// Curve based
final ease = Motion.curved(400.ms, Curves.easeInOut);

// Spring (duration + bounce abstraction)
CupertinoMotion.smooth(duration: 500.ms); // bounce: 0
CupertinoMotion.bouncy(duration: 600.ms, extraBounce: .1);

// Trim / segment lets you use a subse of a motion characteristic
final entrance = smooth.segment(length: .4); // Only first 40%

// Also supports Material Expressive Motion tokens
MaterialSpringMotion.expressiveEffectsDefault();
''';

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: const Text('1. Motion – A unified Abstraction'),
      mainContent: CodeHighlight(
        code: _code,
      ),
      secondaryContent: Center(
        child: Image.asset(
          'assets/motion_friends.png',
          width: 500,
        ),
      ),
    );
  }
}

class _MotionControllerSlide extends FlutterDeckSlideWidget {
  const _MotionControllerSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/motor-motion-controller',
          title: 'MotionController',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  static const _code = '''
import 'package:motor/motor.dart';

// In your State class:
late final controller = MotionController<Offset>(
    motion: Motion.smoothSpring(),
    vsync: this,
    converter: OffsetMotionConverter(),
    initialValue: Offset.zero,
);

@override
void dispose() {
  controller.dispose();
  super.dispose();
}

// We can just set the value directly
void onDragUpdate(DragUpdateDetails details) {
  controller.value += details.delta;
}

// And it understands Offset, so this is easy
void onDragEnd(DragEndDetails details) {
  controller.animateTo(
    Offset.zero, 
    withVelocity: details.velocity.pixelsPerSecond,
  );
}


@override
Widget build(BuildContext context) {
  //... 
}
''';

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: const Text('3. MotionController'),
      mainContent: Align(
        alignment: Alignment.centerLeft,
        child: CodeHighlight(
          code: _code,
        ),
      ),
      secondaryContent: Center(
        child: Draggable2D(
          motion: CupertinoMotion.smooth(),
          child: Image.asset(
            'assets/file.png',
            width: 200,
          ),
        ),
      ),
    );
  }
}

class _MotionConverterSlide extends FlutterDeckSlideWidget {
  _MotionConverterSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/motor-motion-converter',
          title: 'MotionConverter',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  static const _code = '''
import 'package:motor/motor.dart';

// Common types are included
MotionConverter<double> a = 
  SingleMotionConverter();

MotionConverter<Offset> b = 
  OffsetMotionConverter();

MotionConverter<Alignment> c = 
  AlignmentMotionConverter();

// Or animate any type by mapping to List<double>
final surfaceStateConverter = MotionConverter<SurfaceState>.custom(
  normalize: (value) => [
    value.radius,
    value.noiseOpacity,
    value.elevation,
  ],
  denormalize: (values) => SurfaceState(
    radius: values[0],
    noiseOpacity: values[1],
    elevation: values[2],
  ),
);
''';

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: const Text('2. MotionConverter'),
      mainContent: CodeHighlight(
        code: _code,
      ),
      secondaryContent: Image.asset('assets/motion_converter.png'),
    );
  }
}

class _MotionBuilderSlide extends FlutterDeckSlideWidget {
  _MotionBuilderSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/motor-motion-builder',
          title: 'MotionBuilder',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  String getCode(Alignment target) =>
      '''
import 'package:motor/motor.dart';

// Declarative redirection & composition

return MotionBuilder(
  motion: CupertinoMotion.smooth(),
  converter: AlignmentMotionConverter(),
  value: $target, // Changing target dynamically redirects the animation
  from: Alignment.center, // (optional) On first build the animation starts here
  builder: (context, alignment, child) => Align(
    alignment: alignment,
    child: child,
  ),
  child: const Text('Hello'),
);
''';

  @override
  Widget build(BuildContext context) {
    return HookBuilder(
      builder: (context) {
        const order = [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomRight,
          Alignment.bottomLeft,
        ];

        final index = useState(0);
        final target = order[index.value % order.length];

        return ContentSlideTemplate(
          insetSecondaryContent: true,
          title: const Text(
            'MotionBuilder - Declarative Animation',
          ),
          mainContent: Align(
            alignment: Alignment.centerLeft,
            child: CodeHighlight(
              filename: 'motion_builder.dart',
              code: getCode(target),
            ),
          ),
          secondaryContent: InkWell(
            onTap: () {
              index.value++;
            },
            child: MotionBuilder(
              value: target,
              from: Alignment.center,
              motion: CupertinoMotion.smooth(duration: 800.ms),
              converter: AlignmentMotionConverter(),
              builder: (context, value, child) => Align(
                alignment: value,
                child: child,
              ),
              child: FlutterLogo(
                size: 120,
              ),
            ),
          ),
        );
      },
    );
  }
}
