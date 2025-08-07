import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/use_interval.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotionSlide extends FlutterDeckSlideWidget {
  const MotionSlide({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final duration = Durations.extralong4;

    return FlutterDeckSlide.custom(
      builder: (context) => HookBuilder(
        builder: (context) {
          final recorder = useMemoized(ValueRecordingNotifier.new);
          final flipFlop = useInterval(interval: duration).isEven;
          final alignment = useAlignmentMotion(
            value: flipFlop ? Alignment.topLeft : Alignment.bottomLeft,
            motion: CurvedMotion(
              duration: duration,
            ),
          );

          recorder.record(alignment.y);

          return Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Padding(
                padding: EdgeInsetsGeometry.all(200),
                child: Align(
                  alignment: alignment,
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
  }
}
