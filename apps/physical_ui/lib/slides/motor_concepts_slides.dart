import 'package:flutter/material.dart';
// motor import not required directly for these code snippets at compile time
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// A group of slides that walk through the core Motor concepts.
final motorConceptSlides = <FlutterDeckSlideWidget>[
  _MotionSlide(),
  _MotionControllerSlide(),
  _MotionConverterSlide(),
  _MotionBuilderSlide(),
  _PuttingItTogetherSlide(),
];

class _MotionSlide extends FlutterDeckSlideWidget {
  _MotionSlide() : super(
    configuration: const FlutterDeckSlideConfiguration(
      route: '/motor-motion',
      title: 'Motion',
      steps: 1,
    ),
  );

  static const _code = '''// Motion encapsulates timing + curve/physics

// Curve based
final ease = Motion.curved(400.ms, Curves.easeInOut);

// Spring (duration + bounce abstraction)
final smooth = Motion.smoothSpring(duration: 500.ms); // bounce: 0
final bouncy = Motion.bouncySpring(duration: 600.ms, extraBounce: .35);

// Shortcuts
Motion.cupertino();
Motion.smooth();

// Trim / sub-extent lets you re-use a motion
final entrance = smooth.subExtent(extent: .4); // Only first 40%
''';

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('Motion = curve OR spring'),
      mainContent: Align(
        alignment: Alignment.centerLeft,
        child: CodeHighlight(
          filename: 'motion.dart',
          code: _code,
        ),
      ),
    );
  }
}

class _MotionControllerSlide extends FlutterDeckSlideWidget {
  _MotionControllerSlide() : super(
    configuration: const FlutterDeckSlideConfiguration(
      route: '/motor-motion-controller',
      title: 'MotionController',
      steps: 1,
    ),
  );

  static const _code = '''// Multi-dimensional controller
class MyWidgetState extends State<MyWidget> with SingleTickerProviderStateMixin {
  late final controller = MotionController<Offset>(
    motion: Motion.smoothSpring(),
    vsync: this,
    converter: OffsetMotionConverter(),
    // Initial value is required for custom types
    initialValue: Offset.zero,
  );

  void animate() {
    controller.animateTo(const Offset(200, 0));
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Transform.translate(
        offset: controller.value,
        child: child,
      ),
      child: const _Card(),
    );
  }
}
''';

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('MotionController = multi‑dimensional AnimationController'),
      mainContent: Align(
        alignment: Alignment.centerLeft,
        child: CodeHighlight(
          filename: 'motion_controller.dart',
          code: _code,
        ),
      ),
    );
  }
}

class _MotionConverterSlide extends FlutterDeckSlideWidget {
  _MotionConverterSlide() : super(
    configuration: const FlutterDeckSlideConfiguration(
      route: '/motor-motion-converter',
      title: 'MotionConverter',
      steps: 1,
    ),
  );

  static const _code = '''// Animate any type by mapping to List<double>

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

late final controller = MotionController<SurfaceState>(
  motion: Motion.bouncySpring(),
  vsync: this,
  converter: surfaceStateConverter,
  initialValue: const SurfaceState(),
);

controller.animateTo(const SurfaceState(radius: 32, noiseOpacity: .3));
''';

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('MotionConverter = custom tween'),
      mainContent: Align(
        alignment: Alignment.centerLeft,
        child: CodeHighlight(
          filename: 'motion_converter.dart',
          code: _code,
        ),
      ),
    );
  }
}

class _MotionBuilderSlide extends FlutterDeckSlideWidget {
  _MotionBuilderSlide() : super(
    configuration: const FlutterDeckSlideConfiguration(
      route: '/motor-motion-builder',
      title: 'MotionBuilder',
      steps: 1,
    ),
  );

  static const _code = '''// Declarative redirection & composition

return MotionBuilder(
  motion: Motion.smooth(),
  from: 0.0,
  value: target, // Changing target dynamically redirects the animation
  builder: (context, value, child) => Opacity(
    opacity: value,
    child: child,
  ),
  child: const Text('Hello'),
);

// Sequence with different motions per phase
return SequenceMotionBuilder<int, double>(
  playing: playing,
  sequence: StepSequence.withMotions([
    (0.0, Motion.smooth().subExtent(extent: .3)),
    (1.0, Motion.bouncySpring(extraBounce: .4)),
  ]),
  converter: MotionConverter.single,
  builder: (context, v, phase, child) => Transform.scale(
    scale: 0.8 + v * .2,
    child: child,
  ),
  child: const Icon(Icons.star),
);
''';

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('MotionBuilder = TweenAnimationBuilder on steroids'),
      mainContent: Align(
        alignment: Alignment.centerLeft,
        child: CodeHighlight(
          filename: 'motion_builder.dart',
          code: _code,
        ),
      ),
    );
  }
}

class _PuttingItTogetherSlide extends FlutterDeckSlideWidget {
  _PuttingItTogetherSlide() : super(
    configuration: const FlutterDeckSlideConfiguration(
      route: '/motor-putting-it-together',
      title: 'Motor: Putting it together',
      steps: 1,
    ),
  );

  static const _code = '''// Card flick (simplified) with sequence
enum Phase { idle, clearing, dismissing }

late final phaseController = SequenceMotionController<Phase, Offset>(
  motion: Motion.bouncySpring(),
  vsync: this,
  converter: OffsetMotionConverter(),
  initialValue: Offset.zero,
);

MotionSequence<Phase, Offset> buildReturn(Offset offset, Velocity velocity) {
  final clearance = offset + Offset(0, -150);
  return MotionSequence.statesWithMotions({
    Phase.idle: (offset, Motion.none()),
    Phase.clearing: (clearance, Motion.smoothSpring().subExtent(extent: .1)),
    Phase.dismissing: (Offset.zero, Motion.smoothSpring()),
  });
}

void onPanEnd(DragEndDetails d) {
  phaseController.playSequence(
    buildReturn(phaseController.value, d.velocity),
    withVelocity: d.velocity.pixelsPerSecond,
  );
}
''';

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('Putting it together: sequence + redirection'),
      mainContent: Align(
        alignment: Alignment.centerLeft,
        child: CodeHighlight(
          filename: 'card_flick_sequence.dart',
          code: _code,
        ),
      ),
    );
  }
}
