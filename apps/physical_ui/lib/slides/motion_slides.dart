import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:motor/motor.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/hooks.dart';
import 'package:physical_ui/slides/motion/motion_ball.dart';
import 'package:physical_ui/slides/motion/motion_example_app.dart';
import 'package:physical_ui/slides/motion/motion_graph.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotionSlideNoAnimation extends FlutterDeckSlideWidget {
  MotionSlideNoAnimation({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/motion-effects',
          steps: steps.length,
        ),
      );

  static final steps = [
    CurvedMotion(duration: 500.ms, curve: Interval(0, 0.00001)),
    CurvedMotion(duration: 500.ms),
    CurvedMotion(duration: 500.ms, curve: Curves.ease),
    CupertinoMotion.smooth(duration: 500.ms),
  ];

  @override
  Widget build(BuildContext context) {
    return HookBuilder(
      builder: (context) {
        final recorder = useDisposable(
          () => ValueRecordingNotifier<double>(window: 2.seconds),
        );
        return FlutterDeckSlideStepsBuilder(
          builder: (context, step) {
            return ContentSlideTemplate(
              title: const Text('Spring Simulation'),
              mainContent: MotionExampleApp(
                motion: steps[step - 1],
                recorder: recorder,
              ),
              description: const Text(
                'This is a simple slide without any motion effects. It serves as a baseline for comparison with other slides that include motion.',
              ),
              secondaryContent: _MotionDemonstration(
                recorder: recorder,
              ),
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
  });

  final ValueRecordingNotifier<double> recorder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(50),
            child: MotionGraph(notifier: recorder),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ListenableBuilder(
            listenable: recorder,
            builder: (context, child) => MotionBall(
              value: recorder.value.lastOrNull?.$2 ?? 0,
              target: 0,
              showTarget: false,
              diameter: 100,
            ),
          ),
        ),
      ],
    );
  }
}
