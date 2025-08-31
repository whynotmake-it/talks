import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/hooks.dart';
import 'package:physical_ui/shared/reverse_curve_motion.dart';
import 'package:physical_ui/slides/motion/motion_ball.dart';
import 'package:physical_ui/slides/motion/motion_example_app.dart';
import 'package:physical_ui/slides/motion/motion_graph.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

final motionSlides = [
  MotionSlideTemplate(
    title: const Text('Why motion?'),
    description: const Text(
      '''
Transitions without motion feel jarring and unnatural.
''',
    ),
    motion: CurvedMotion(
      curve: Interval(0, 0.0001),
      duration: 1.seconds,
    ),
    filterIdentical: false,
  ),
  MotionSlideTemplate(
    title: const Text('Linear Motion'),
    description: const Text(
      '''
Motion gives elements context and meaning.
''',
    ),
    motion: CurvedMotion(
      duration: 0.5.seconds,
    ),
  ),
  MotionSlideTemplate(
    title: const Text('Curves and Easing'),
    description: const Text(
      '''
By using curves such as .ease, the animated element feels more physical 
and responsive...
''',
    ),
    motion: CurvedMotion(
      duration: 0.8.seconds,
      curve: Curves.ease,
    ),
  ),
  MotionSlideTemplate(
    title: const Text('Curves and Easing'),
    description: const Text(
      '''
...but they can feel weird when used to respond to user gestures.
''',
    ),
    motion: CurvedMotion(
      duration: 0.8.seconds,
      curve: Curves.ease,
    ),
  ),
  MotionSlideTemplate(
    title: const Text('Curves and Easing'),
    description: const Text(
      '''
Curves are also often used in reverse where they shouldn't be. 
''',
    ),
    motion: ReverseCurveMotion(
      duration: 0.8.seconds,
      curve: Curves.ease,
      reverseCurve: Curves.ease.flipped,
    ),
  ),
  MotionSlideTemplate(
    title: const Text('Spring Simulations'),
    description: const Text(
      '''
Simulations use the last velocity of a gesture to create a more
natural movement.
''',
    ),
    motion: CupertinoMotion.smooth(duration: 0.8.seconds),
  ),
];

class MotionSlideTemplate extends FlutterDeckSlideWidget {
  MotionSlideTemplate({
    required this.title,
    required this.description,
    required this.motion,
    super.key,
    this.filterIdentical = true,
  }) : super(
         configuration: FlutterDeckSlideConfiguration(
           route: '/motion-${title.hashCode}',
           steps: 2,
         ),
       );

  final Widget title;

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
              () => ValueRecordingNotifier<double>(window: 100),
            );

            // The graph is invisible on step 1 and becomes visible on step 2
            // but can be toggled by clicking it
            final graphVisible = useKeyedState(step > 1, keys: [step]);

            return FlutterDeckSlideStepsBuilder(
              builder: (context, step) {
                return ContentSlideTemplate(
                  title: title,
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
