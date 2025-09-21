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
import 'package:wnma_talk/wnma_talk.dart';

final dimensionalitySlides = [
  DimensionalitySlideTemplate(
    showTitle: false,
    motion: CurvedMotion(.5.seconds, Curves.ease),
    showTrajectoryInStep2: false,
  ),
  DimensionalitySlideTemplate(
    showTitle: false,
    motion: CurvedMotion(.5.seconds, Curves.ease),
    code: _standardAnimationPseudocode,
  ),
  DimensionalitySlideTemplate(
    showTitle: false,
    motion: SpringMotion(
      SpringDescription.withDurationAndBounce(
        duration: Duration(milliseconds: 500),
        bounce: 0.1,
      ),
    ),
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
  ),
  DimensionalitySlideTemplate(
    motion: MaterialSpringMotion.expressiveSpatialSlow(),
    filename: 'flutter_physics_simulation_example.dart',
    code: _flutterSpringCodeExample,
    showTrajectoryInStep2: false,
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
  }) : super(
         configuration: FlutterDeckSlideConfiguration(
           route: '/dimensionality-${Object.hash(motion, code)}',
           steps: showTrajectoryInStep2 ? 2 : 1,
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
                  child: _Draggable(
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

class _Draggable extends StatefulWidget {
  const _Draggable({
    required this.child,
    required this.motion,
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
  State<_Draggable> createState() => _DraggableState();
}

class _DraggableState extends State<_Draggable>
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
  void didUpdateWidget(covariant _Draggable oldWidget) {
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

const _flutterSpringCodeExample = '''
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

void main() {
  runApp(const MaterialApp(home: PhysicsCardDragDemo()));
}

class PhysicsCardDragDemo extends StatelessWidget {
  const PhysicsCardDragDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const DraggableCard(child: FlutterLogo(size: 128)),
    );
  }
}

/// A draggable card that moves back to [Alignment.center] when it's
/// released.
class DraggableCard extends StatefulWidget {
  const DraggableCard({required this.child, super.key});

  final Widget child;

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// The alignment of the card as it is dragged or being animated.
  ///
  /// While the card is being dragged, this value is set to the values computed
  /// in the GestureDetector onPanUpdate callback. If the animation is running,
  /// this value is set to the value of the [_animation].
  Alignment _dragAlignment = Alignment.center;

  late Animation<Alignment> _animation;

  /// Calculates and runs a [SpringSimulation].
  void _runAnimation(Offset pixelsPerSecond, Size size) {
    _animation = _controller.drive(
      AlignmentTween(begin: _dragAlignment, end: Alignment.center),
    );
    // Calculate the velocity relative to the unit interval, [0,1],
    // used by the animation controller.
    final unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;

    const spring = SpringDescription(mass: 1, stiffness: 1, damping: 1);

    final simulation = SpringSimulation(spring, 0, 1, -unitVelocity);

    _controller.animateWith(simulation);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    _controller.addListener(() {
      setState(() {
        _dragAlignment = _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onPanDown: (details) {
        _controller.stop();
      },
      onPanUpdate: (details) {
        setState(() {
          _dragAlignment += Alignment(
            details.delta.dx / (size.width / 2),
            details.delta.dy / (size.height / 2),
          );
        });
      },
      onPanEnd: (details) {
        _runAnimation(details.velocity.pixelsPerSecond, size);
      },
''';
