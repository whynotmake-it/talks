import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/hooks.dart';
import 'package:physical_ui/shared/reverse_curve_motion.dart';
import 'package:physical_ui/slides/motion/motion_ball.dart';
import 'package:physical_ui/slides/motion/motion_example_app.dart';
import 'package:physical_ui/slides/motion/motion_graph.dart';
import 'package:physical_ui/slides/motion/spring_code_visualizer.dart';
import 'package:physical_ui/slides/motion/spring_visualizer.dart';
import 'package:physical_ui/slides/motion_character_slide.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

final motionSlides = [
  MotionSlideTemplate(
    title: 'Why motion?',
    description: const Text(
      '''
Transitions without motion feel jarring and unnatural.
''',
    ),
    motion: CurvedMotion(.5.seconds, Interval(0, 0.0001)),
    filterIdentical: false,
    speakerNotes: jesperSlideNotesHeader,
  ),
  MotionSlideTemplate(
    title: 'Linear Motion',
    description: const Text(
      '''
Motion gives elements context and meaning.
''',
    ),
    motion: CurvedMotion(0.5.seconds),
    speakerNotes: timSlideNotesHeader,
  ),
  MotionSlideTemplate(
    title: 'Curves and Easing',
    description: const Text(
      '''
By using curves such as .ease, the animated element feels more physical 
and responsive...
''',
    ),
    motion: CurvedMotion(0.8.seconds, Curves.ease),
    speakerNotes: jesperSlideNotesHeader,
  ),

  MotionSlideTemplate(
    title: 'Curves and Easing',
    description: const Text(
      '''
... but you have to make sure to use the right curve, the right way around. 
''',
    ),

    motion: ReverseCurveMotion(
      0.8.seconds,
      Curves.ease,
      Curves.ease.flipped,
    ),
    speakerNotes: timSlideNotesHeader,
  ),
  MotionSlideTemplate(
    title: 'Curves and Easing',
    description: const Text(
      '''
And they don't respond well to user gestures.
''',
    ),
    motion: ReverseCurveMotion(
      0.8.seconds,
      Curves.ease,
      Curves.ease.flipped,
    ),
    speakerNotes: timSlideNotesHeader,
  ),
  MotionSlideTemplate(
    title: 'Spring Simulations',
    description: const Text(
      '''
Simulations use the last velocity of a gesture to create a more
natural movement.
''',
    ),
    motion: CupertinoMotion.smooth(duration: 0.8.seconds),
    speakerNotes: jesperSlideNotesHeader,
  ),
  SpringVisualisationSlide(),
  MotionCharacterSlide(),
  CodeSlide(),
];

class MotionSlideTemplate extends FlutterDeckSlideWidget {
  MotionSlideTemplate({
    required this.title,
    required this.description,
    required this.motion,
    super.key,
    this.filterIdentical = true,
    String speakerNotes = '',
  }) : super(
         configuration: FlutterDeckSlideConfiguration(
           title: title,
           route:
               '/motion-${Object.hash(
                 title,
                 description,
                 motion,
                 filterIdentical,
               )}',
           steps: 2,
           speakerNotes: speakerNotes,
         ),
       );

  final String title;

  final Widget description;

  final Motion motion;

  final bool filterIdentical;

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlideStepsBuilder(
      builder: (context, step) {
        return HookBuilder(
          builder: (context) {
            final recorder = useDisposable(
              () => ValueRecordingNotifier<double>(window: 200),
            );

            // The graph is invisible on step 1 and becomes visible on step 2
            // but can be toggled by clicking it
            final graphVisible = useKeyedState(step > 1, keys: [step]);

            return FlutterDeckSlideStepsBuilder(
              builder: (context, step) {
                return ContentSlideTemplate(
                  title: Text(title),
                  mainContent: MotionExampleApp(
                    motion: motion,
                    recorder: recorder,
                  ),
                  description: description,
                  secondaryContent: InkWell(
                    onTap: () {
                      graphVisible.value = !graphVisible.value;
                    },
                    child: AnimatedOpacity(
                      opacity: graphVisible.value ? 1 : 0,
                      duration: 300.ms,
                      child: _MotionDemonstration(
                        recorder: recorder,
                        filterIdentical: filterIdentical,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MotionDemonstration extends HookWidget {
  const _MotionDemonstration({
    required this.recorder,
    required this.filterIdentical,
  });

  final bool filterIdentical;
  final ValueRecordingNotifier<double> recorder;

  @override
  Widget build(BuildContext context) {
    const diameter = 25.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(
              top: diameter / 2,
              bottom: diameter / 2,
              left: diameter / 2,
            ),
            child: MotionGraph(
              notifier: recorder,
              filterIdentical: filterIdentical,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ListenableBuilder(
            listenable: recorder,
            builder: (context, child) => MotionBall(
              value: recorder.value.lastOrNull ?? 0,
              target: 0,
              showTarget: false,
              diameter: diameter,
            ),
          ),
        ),
      ],
    );
  }
}

class SpringVisualisationSlide extends FlutterDeckSlideWidget {
  SpringVisualisationSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          title: 'What is a Spring Simulation?',
          route: '/what-is-a-spring-simulation',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlideStepsBuilder(
      builder: (context, stepNumber) => HookBuilder(
        builder: (context) {
          final duration = useState(400.ms);
          final bounce = useState<double>(0);
          return ContentSlideTemplate(
            title: Text('What is a Spring Simulation?'),
            mainContent: SpringVisualizer(
              duration: duration.value,
              bounce: bounce.value,
              showSpring: true,
            ),
            secondaryContent: SpringCodeVisualizer(
              duration: duration,
              bounce: bounce,
            ),
          );
        },
      ),
    );
  }
}

class CodeSlide extends FlutterDeckSlideWidget {
  const CodeSlide({
    super.key,
  }) : super(
         configuration: const FlutterDeckSlideConfiguration(
           title: 'Spring Simulation Code',
           route: '/spring-simulation-code',
           steps: 1,
           speakerNotes: jesperSlideNotesHeader,
         ),
       );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('Flutter supports this quite easily!'),
      mainContent: Align(
        alignment: Alignment.centerLeft,
        child: CodeHighlight(code: springDemoCode),
      ),
    );
  }
}

const springDemoCode = '''
// Semi-pseudo code for a spring simulation

final customSpring = SpringDescription(
  mass: 1,          // Heavier = slower
  stiffness: 100,   // Higher = faster
  damping: 10,      // Higher = less bouncy
);

final spring = SpringDescription.withDurationAndBounce(
  duration: Duration(milliseconds: 400), // Approximate duration
  bounce: 0.0, // From 0 (no bounce) to 1 (very bouncy)
);

final animationController = AnimationController(vsync: this);

/// Could be called when the user lets go of the sheet
void onDragEnd(DragEndDetails details) {
  final velocity = details.velocity.pixelsPerSecond;

  // animationController.animateTo(0, duration: Duration(milliseconds: 400));

  animationController.animateWith(
    SpringSimulation(
      spring,                      // Our SpringDescription
      animationController.value,   // Starting value
      0,                           // Target value
      velocity,                    // Initial velocity
    ),
  );
}


''';
