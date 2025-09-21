import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotorCardStackSlide extends FlutterDeckSlideWidget {
  const MotorCardStackSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          title: 'Motor Card Stack',
          route: '/motor-card-stack',
        ),
      );

  static const _motorPseudoCode = '''
// 1. Setup
final controller = SequenceMotionController<Phase, Offset>(
  motion: Motion.bouncySpring(),
  vsync: this,
  converter: OffsetMotionConverter(),
);

// 2. Build a motion sequence
final sequence = MotionSequence.statesWithMotions({
  Phase.idle: (currentOffset, Motion.none()),
  Phase.clearing: (clearanceOffset, Motion.smoothSpring().trimmed(endTrim: .5)),
  Phase.dismissing: (Offset.zero, Motion.smoothSpring()),
});

// 3. Drag handling
GestureDetector(
  onPanUpdate: (details) {
    controller.value += details.delta;
  },
  onPanEnd: (details) {
    // Auto spring-back with velocity
    if (dragDistance > threshold) {
      controller.playSequence(sequence);
    } else {
      controller.animateTo(Offset.zero);
    }
  },
);

// 4. Transform with animation
Transform.translate(
  offset: controller.value, 
  child: myCard,
)
''';

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('Card Stack'),
      mainContent: const Row(
        children: [
          // Left Column: Interactive Demo
          Expanded(
            child: Center(
              child: CardStack(),
            ),
          ),

          // Right Column: Code Example
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 32),
              child: CodeHighlight(
                filename: 'drag_card_example.dart',
                code: _motorPseudoCode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CardStack extends StatefulWidget {
  const CardStack({super.key});

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> {
  late final List<String> _cards = [
    '3',
    '2',
    '1',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final (index, text) in _cards.indexed)
          Center(
            key: ValueKey(text),
            child: _DragCardExample(
              index: _cards.length - 1 - index,
              child: Text(
                text,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              onDismiss: () => _removeCard(index),
            ),
          ),
      ],
    );
  }

  void _removeCard(int index) {
    setState(() {
      final card = _cards.removeAt(index);
      _cards.insert(0, card);
    });
  }
}

enum DragCardPhase {
  idle,
  clearing,
  dismissing,
}

class _DragCardExample extends StatefulWidget {
  const _DragCardExample({
    required this.index,
    required this.child,
    required this.onDismiss,
  });

  final int index;
  final Widget child;
  final VoidCallback onDismiss;

  @override
  State<_DragCardExample> createState() => _DragCardExampleState();
}

class _DragCardExampleState extends State<_DragCardExample>
    with SingleTickerProviderStateMixin {
  late final phaseController = SequenceMotionController<DragCardPhase, Offset>(
    motion: Motion.bouncySpring(),
    vsync: this,
    converter: OffsetMotionConverter(),
    initialValue: Offset.zero,
  );

  static const cardSize = 500.0;
  static const dismissThreshold = 100.0;

  Offset? getClearanceOffset(Offset offset, Velocity velocity) {
    final minDistance = cardSize * 1.5;
    final vector = switch (velocity.pixelsPerSecond) {
      Offset.zero => offset.normalized,
      final v => v.normalized,
    };
    final remainingDistance = minDistance - offset.distance;
    if (remainingDistance <= 0) {
      return null;
    }
    return offset + vector * remainingDistance;
  }

  MotionSequence<DragCardPhase, Offset> buildReturn(
    Offset offset,
    Velocity velocity,
  ) {
    final clearance = getClearanceOffset(offset, velocity);
    return MotionSequence.statesWithMotions({
      DragCardPhase.idle: (offset, Motion.none()),
      if (clearance != null)
        DragCardPhase.clearing: (
          clearance,
          // Only use the very beginning of the spring way before it settles
          Motion.smoothSpring().subExtent(extent: .1),
        ),
      DragCardPhase.dismissing: (
        Offset.zero,
        Motion.smoothSpring(),
      ),
    });
  }

  @override
  void dispose() {
    phaseController.dispose();
    super.dispose();
  }

  void _onPanEnd(DragEndDetails details) {
    if (phaseController.value.distance > dismissThreshold) {
      phaseController.playSequence(
        buildReturn(phaseController.value, details.velocity),
        onPhaseChanged: (phase) {
          // We wait until the flight back to tell the stack to resort
          if (phase == DragCardPhase.dismissing) {
            widget.onDismiss();
          }
        },
        withVelocity: details.velocity.pixelsPerSecond,
      );
    } else {
      phaseController.animateTo(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: _onPanEnd,
      onPanCancel: () => phaseController.animateTo(Offset.zero),
      onPanUpdate: (details) {
        phaseController.value += details.delta;
      },
      child: Center(
        child: AnimatedBuilder(
          animation: phaseController,
          builder: (context, child) {
            return Transform.translate(
              offset: phaseController.value,
              child: SizedBox.square(
                dimension: _DragCardExampleState.cardSize,
                child: child,
              ),
            );
          },
          child: _DistanceBuilder(
            index: widget.index,
            child: Container(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistanceBuilder extends StatelessWidget {
  const _DistanceBuilder({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).colorScheme.surface;
    return SingleMotionBuilder(
      value: index.toDouble(),
      motion: Motion.cupertino(),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, value * -56),
        child: Transform.scale(
          scale: 1 - value * .1,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              backgroundColor.withValues(alpha: value * .2),
              BlendMode.srcATop,
            ),
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }
}

extension on Offset {
  Offset get normalized {
    final length = distance;
    if (length == 0) return this;
    return this / length;
  }
}
