import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/flip_flop/flip_flop_notifier.dart';
import 'package:physical_ui/graphs/value_recording_graph.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/hooks.dart';
import 'package:physical_ui/shared/widgets/motion_description.dart';
import 'package:physical_ui/slides/motion/motion_ball.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

typedef MotionSlideStep = ({
  bool showGraph,
  bool showTarget,
  Motion motion,
  String motionDescription,
});

class MotionSlide extends FlutterDeckSlideWidget {
  MotionSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/motion',
          steps: steps.length,
        ),
      );

  static const duration = Durations.extralong4;

  static const steps = <MotionSlideStep>[
    (
      showGraph: false,
      showTarget: false,
      motionDescription: "Linear",
      motion: CurvedMotion(duration: duration),
    ),
    (
      showGraph: false,
      showTarget: true,
      motionDescription: "Linear",
      motion: CurvedMotion(duration: duration),
    ),
    (
      showGraph: true,
      showTarget: true,
      motionDescription: "Curves.linear",
      motion: CurvedMotion(duration: duration),
    ),
    (
      showGraph: true,
      showTarget: true,
      motionDescription: "Curves.easeInOut",
      motion: CurvedMotion(duration: duration, curve: Curves.easeInOut),
    ),
    (
      showGraph: true,
      showTarget: true,
      motionDescription: "Curves.ease",
      motion: CurvedMotion(duration: duration, curve: Curves.ease),
    ),
    (
      showGraph: true,
      showTarget: true,
      motionDescription: "Spring simulation",
      motion: CupertinoMotion.smooth(duration: duration),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final ballDiameter = 200.0;

    return FlutterDeckSlide.custom(
      builder: (context) => FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) => HookBuilder(
          builder: (context) {
            final step = useKeyedState(
              steps[stepNumber - 1],
              keys: [stepNumber],
            );

            final valueRecorder = useDisposable(
              () => ValueRecordingNotifier<double>(window: duration * 2),
            );

            final flipFlopNotifier = useDisposable(
              () => FlipFlopNotifier(duration),
            );
            final flipFlop = useValueListenable(flipFlopNotifier);
            final target = flipFlop ? .0 : 1.0;

            return FlutterDeckSlideStepsListener(
              listener: (context, stepNumber) => valueRecorder.reset(),
              child: SingleVelocityMotionBuilder(
                value: target,
                motion: step.value.motion,
                builder: (context, value, velocity, child) {
                  valueRecorder.record(value);
                  return Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: EdgeInsetsGeometry.all(200),
                        child: Column(
                          children: [
                            Center(
                              child: MotionDescription(
                                motion: step.value.motion,
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  MotionBall(
                                    value: value,
                                    target: target,
                                    diameter: ballDiameter,
                                    showTarget: step.value.showTarget,
                                  ),
                                  Flexible(
                                    child: AnimatedSizeSwitcher(
                                      child: step.value.showGraph
                                          ? Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: ballDiameter / 2,
                                              ),
                                              child: ValueRecordingGraph(
                                                notifier: valueRecorder,
                                                minY: 0,
                                                maxY: 1,
                                              ),
                                            )
                                          : SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              spacing: 24,
                              children: [
                                CupertinoButton.filled(
                                  onPressed: flipFlopNotifier.flip,
                                  child: Text('Flip'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(64),
                          child: Text(
                            'Physical UI',
                            textHeightBehavior: TextHeightBehavior(
                              applyHeightToLastDescent: false,
                            ),
                            style:
                                FlutterDeckTheme.of(
                                  context,
                                ).textTheme.title.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
