import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/flip_flop/flip_flop_notifier.dart';
import 'package:physical_ui/graphs/graph.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/hooks.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotionSlide extends FlutterDeckSlideWidget {
  MotionSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/motion',
          steps: motions.length,
        ),
      );

  static const duration = Durations.extralong4;

  static const motions = [
    ("Linear", CurvedMotion(duration: duration)),
    ("Ease", CurvedMotion(duration: duration, curve: Curves.ease)),
    ("Spring", CupertinoMotion()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FlutterDeckSlide.custom(
      builder: (context) => FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) => HookBuilder(
          builder: (context) {
            final motion = useKeyedState(
              motions[stepNumber - 1],
              keys: [stepNumber],
            );
            final recorder = useDisposable(
              () => ValueRecordingNotifier<double>(window: duration * 2),
            );
            final flipFlopNotifier = useDisposable(
              () => FlipFlopNotifier(duration),
            );
            final flipFlop = useValueListenable(flipFlopNotifier);

            final value = useSingleMotion(
              value: flipFlop ? 0 : 1,
              motion: motion.value.$2,
            );

            recorder.record(value);
            return Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: EdgeInsetsGeometry.all(200),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Align(
                              alignment: Alignment(-1, value * 2 - 1),
                              child: Heroine(
                                tag: true,
                                motion: CupertinoMotion.bouncy(),
                                child: SizedBox.square(
                                  dimension: 200,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      shape: CircleBorder(),
                                      color: theme.colorScheme.errorContainer,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ValueRecordingGraph(
                                notifier: recorder,
                                minY: -1,
                                maxY: 1,
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
                          DropdownButton(
                            items: [
                              for (final motion in motions)
                                DropdownMenuItem(
                                  value: motion,
                                  child: Text(motion.$1),
                                ),
                            ],
                            onChanged: (value) => motion.value = value!,
                            value: motion.value,
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
      ),
    );
  }
}
