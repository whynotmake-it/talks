import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/hooks.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/animated_visibility.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/line_painter.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

final dimensionalitySlides = [
  DimensionalitySlideTemplate(
    showTitle: false,
    motion: CurvedMotion(.5.seconds, Curves.ease),
    showTrajectoryInStep2: false,
    speakerNotes: timSlideNotesHeader,
  ),
  DimensionalitySlideTemplate(
    showTitle: false,
    motion: CurvedMotion(.5.seconds, Curves.ease),
    code: _standardAnimationPseudocode,
    speakerNotes: timSlideNotesHeader,
  ),
  DimensionalitySlideTemplate(
    showTitle: false,
    motion: SpringMotion(
      SpringDescription.withDurationAndBounce(
        duration: Duration(milliseconds: 500),
        bounce: 0.1,
      ),
    ),
    speakerNotes: jesperSlideNotesHeader,
  ),
  DimensionalitySlideTemplate(
    motion: SpringMotion(
      SpringDescription.withDurationAndBounce(
        duration: Duration(milliseconds: 500),
        bounce: 0.1,
      ),
    ),
    showTrajectoryInStep2: false,
    code: _multiDimensionPseudocode,
    speakerNotes: jesperSlideNotesHeader,
  ),
];

class DimensionalitySlideTemplate extends FlutterDeckSlideWidget {
  DimensionalitySlideTemplate({
    super.key,
    this.showTitle = true,
    this.motion = const CupertinoMotion.smooth(),
    this.filename,
    this.code,
    bool showTrajectoryInStep2 = true,
    String speakerNotes = '',
  }) : super(
         configuration: FlutterDeckSlideConfiguration(
           route: '/dimensionality-${Object.hash(motion, code)}',
           steps: showTrajectoryInStep2 ? 2 : 1,
           speakerNotes: speakerNotes,
         ),
       );

  final bool showTitle;
  final Motion motion;
  final String? filename;
  final String? code;

  @override
  Widget build(BuildContext context) {
    return HookBuilder(
      builder: (context) {
        final recorder = useDisposable(
          () => ValueRecordingNotifier<Offset>(window: 200),
        );

        final letGoAt = useState<Offset?>(null);

        return FlutterDeckSlideStepsBuilder(
          builder: (context, step) => ContentSlideTemplate(
            title: Visibility.maintain(
              visible: showTitle,
              child: Text('We need more than one dimension.'),
            ),

            mainContent: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: AnimatedVisibility(
                    visible: step > 1,
                    from: Offset.zero,
                    child: _ValueGraph(recorder: recorder),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedVisibility(
                    visible: step > 1,
                    from: Offset.zero,
                    child: _LetGoPoint(at: letGoAt.value),
                  ),
                ),

                Align(
                  child: Draggable2D(
                    recorder: recorder,
                    motion: motion,
                    onDragStart: () {
                      recorder.reset();
                      letGoAt.value = null;
                    },
                    onLetGo: (offset) {
                      letGoAt.value = offset;
                    },
                    child: Image.asset(
                      'assets/file.png',
                      height: 200,
                    ),
                  ),
                ),
              ],
            ),
            secondaryContent: Stack(
              children: [
                Align(
                  child: Image.asset(
                    'assets/folder.png',
                    height: 200,
                  ),
                ),
                AnimatedVisibility(
                  visible: code != null,
                  animateIn: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: CodeHighlight(
                      filename: filename,
                      code: code ?? '',
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

class _LetGoPoint extends StatelessWidget {
  const _LetGoPoint({required this.at});

  final Offset? at;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: switch (at) {
        null => const SizedBox.shrink(),
        final at => Transform.translate(
          offset: at,
          child: Icon(Icons.location_searching_rounded),
        ),
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
                fadeOutCurve: Curves.linear,
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

class Draggable2D extends StatefulWidget {
  const Draggable2D({
    required this.child,
    required this.motion,
    super.key,
    this.recorder,
    this.onDragStart,
    this.onLetGo,
  });

  final Widget child;

  final Motion motion;

  final ValueRecordingNotifier<Offset>? recorder;

  final VoidCallback? onDragStart;

  final ValueChanged<Offset>? onLetGo;

  @override
  State<Draggable2D> createState() => _Draggable2DState();
}

class _Draggable2DState extends State<Draggable2D>
    with SingleTickerProviderStateMixin {
  late final motionController = MotionController(
    vsync: this,
    initialValue: Offset.zero,
    motion: widget.motion,
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

  @override
  void didUpdateWidget(covariant Draggable2D oldWidget) {
    if (oldWidget.motion != widget.motion) {
      motionController.motion = widget.motion;
    }
    super.didUpdateWidget(oldWidget);
  }

  void _recordValue() {
    widget.recorder?.record(motionController.value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) {
        motionController.stop(canceled: true);
        widget.onDragStart?.call();
      },
      onPanUpdate: (details) {
        motionController.value += details.delta;
      },
      onPanEnd: (details) {
        widget.onLetGo?.call(motionController.value);
        motionController.animateTo(
          Offset.zero,
          withVelocity: details.velocity.pixelsPerSecond,
        );
      },
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

const _standardAnimationPseudocode = '''
// On drag end
animationController.animateWith(
  SpringSimulation(
    springDescription,
    0,
    1,
    relativeVelocity,
  ),
);

final offset = animationController.drive(
  OffsetTween(
    begin: currentDragOffset,
    end: Offset.zero,
  ),
);

// Build widget
return Transform.translate(
  offset: offset.value,
  child: child,
);
''';

const _multiDimensionPseudocode = '''
// Pseudocode for multi-dimensional drag
final springDescription = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 500),
  bounce: 0.1,
);

final x = animationControllerX.animateWith(
  SpringSimulation(
    springDescription,
    currentDragOffset.dx,
    0,
    currentDragVelocity.pixelsPerSecond.dx,
  ),
);

final y = animationControllerX.animateWith(
  SpringSimulation(
    springDescription,
    currentDragOffset.dy,
    0,
    currentDragVelocity.pixelsPerSecond.dy,
  ),
);

final targetOffset = Offset(x.value, y.value);

// Build widget...

''';
