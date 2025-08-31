import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/hooks.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/line_painter.dart';
import 'package:wnma_talk/wnma_talk.dart';

class DimensionalitySlide extends FlutterDeckSlideWidget {
  DimensionalitySlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/dimensionality',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return HookBuilder(
      builder: (context) {
        final recorder = useDisposable(
          () => ValueRecordingNotifier<Offset>(window: 500),
        );

        return FlutterDeckSlideStepsBuilder(
          builder: (context, step) => ContentSlideTemplate(
            title: Text('We need more than one dimension.'),
            mainContent: Stack(
              children: [
                Positioned.fill(
                  child: _ValueGraph(recorder: recorder),
                ),
                Align(
                  child: _Draggable(
                    recorder: recorder,
                    child: FlutterLogo(
                      size: 200,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ValueGraph extends StatelessWidget {
  const _ValueGraph({required this.recorder});

  final ValueRecordingNotifier<Offset> recorder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListenableBuilder(
          listenable: recorder,
          builder: (context, child) {
            return SizedBox.expand(
              child: LinePathWidget(
                color: Theme.of(context).colorScheme.tertiary,
                thickness: 4,
                points: [
                  for (final point in recorder.value)
                    Offset(
                      point.dx / constraints.maxWidth + 0.5,
                      point.dy / constraints.maxHeight + 0.5,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Draggable extends StatefulWidget {
  const _Draggable({
    required this.child,
    this.recorder,
  });

  final Widget child;

  final ValueRecordingNotifier<Offset>? recorder;

  @override
  State<_Draggable> createState() => _DraggableState();
}

class _DraggableState extends State<_Draggable>
    with SingleTickerProviderStateMixin {
  late final motionController = MotionController(
    vsync: this,
    initialValue: Offset.zero,
    motion: CupertinoMotion.bouncy(),
    converter: OffsetMotionConverter(),
  );

  @override
  void initState() {
    super.initState();
    motionController.addListener(_recordValue);
  }

  @override
  void dispose() {
    motionController.dispose();
    super.dispose();
  }

  void _recordValue() {
    widget.recorder?.record(motionController.value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) {
        motionController.stop(canceled: true);
      },
      onPanUpdate: (details) {
        motionController.value += details.delta;
      },
      onPanEnd: (details) => motionController.animateTo(
        Offset.zero,
        withVelocity: details.velocity.pixelsPerSecond,
      ),
      child: ValueListenableBuilder<Offset>(
        valueListenable: motionController,
        builder: (context, value, child) {
          return Transform.translate(
            offset: value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
