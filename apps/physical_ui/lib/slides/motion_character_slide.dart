import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:motor/motor.dart';
import 'package:physical_ui/slides/motion/spring_visualizer.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotionCharacterSlide extends FlutterDeckSlideWidget {
  const MotionCharacterSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          title: 'Motion Characters',
          route: '/motion-characters',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('Motion Characters'),
      mainContent: const Row(
        children: [
          Expanded(
            child: MotionCharacterColumn(
              label: 'Smooth',
              emoji: '🙂',
              motion: CupertinoMotion.smooth(),
            ),
          ),
          Expanded(
            child: MotionCharacterColumn(
              label: 'Playful',
              emoji: '😄',
              motion: CupertinoMotion.bouncy(),
            ),
          ),
          Expanded(
            child: MotionCharacterColumn(
              label: 'Snappy',
              emoji: '😎',
              motion: CupertinoMotion(
                duration: Duration(milliseconds: 200),
              ),
            ),
          ),
          Expanded(
            child: MotionCharacterColumn(
              label: 'Underdamped',
              emoji: '😵‍💫',
              motion: CupertinoMotion(
                duration: Duration(milliseconds: 600),
                bounce: 1.01,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MotionCharacterColumn extends HookWidget {
  const MotionCharacterColumn({
    required this.label,
    required this.emoji,
    required this.motion,
    super.key,
  });

  final String label;
  final String emoji;
  final Motion motion;

  String _getMotionDescription() {
    if (motion is CupertinoMotion) {
      final cupertinoMotion = motion as CupertinoMotion;
      final durationMs = cupertinoMotion.duration.inMilliseconds;
      final bounce = cupertinoMotion.bounce;
      return 'Duration: ${durationMs}ms\nBounce: ${bounce.toStringAsFixed(2)}';
    }
    return 'Unknown motion type';
  }

  @override
  Widget build(BuildContext context) {
    final playing = useState(false);
    final springVisible = useState(true); // Start visible
    final target = useState(Offset.zero);

    // Pre-stretch the spring by setting initial position at top
    useEffect(() {
      target.value = const Offset(
        0,
        -250,
      ); // Start position (top, pre-stretched)
      return null;
    }, []);

    void triggerAnimation() {
      if (playing.value) return; // Prevent multiple triggers

      playing.value = true;

      target.value = const Offset(0, 200);

      // Fade out spring after a short delay (only on first click)
      Future.delayed(const Duration(milliseconds: 200), () {
        springVisible.value = false;
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Label
          Text(
            label,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(),
          ),
          const SizedBox(height: 8),
          
          // Motion parameters
          Text(
            _getMotionDescription(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Animation area
          Expanded(
            child: RotatedBox(
              quarterTurns: 2, // Rotate 90 degrees to make vertical
              child: InkWell(
                onTap: triggerAnimation,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SequenceMotionBuilder<int, Offset>(
                    playing: playing.value,
                    sequence: StepSequence.withMotions([
                      (target.value, motion),
                    ]),
                    converter: MotionConverter.offset,
                    builder: (context, value, _, child) => Stack(
                      fit: StackFit.expand,
                      children: [
                        // Spring visualization
                        AnimatedOpacity(
                          opacity: springVisible.value ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: CustomPaint(
                            painter: SpringPainter(
                              start: const Offset(
                                0,
                                300,
                              ), 
                              end: value,
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),

                        // Emoji character
                        Center(
                          child: Transform.translate(
                            offset: value,
                            child: RotatedBox(
                              quarterTurns: -2, // Counter-rotate emoji upright
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 112),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
