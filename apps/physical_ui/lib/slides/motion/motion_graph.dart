import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_graph.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotionGraph extends HookWidget {
  const MotionGraph({
    super.key,
    required this.notifier,
    this.minY = -.01,
    this.maxY = 1.01,
    this.color,
    this.stayLive = true,
  });

  final ValueRecordingNotifier<double> notifier;
  final double minY;
  final double maxY;
  final Color? color;

  final bool stayLive;

  @override
  Widget build(BuildContext context) {
    final color =
        this.color ??
        FlutterDeckTheme.of(context).materialTheme.colorScheme.tertiary;

    if (stayLive) {
      final anim = useAnimationController()..repeat(period: 1.seconds);
      useAnimation(anim);
    }

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          stops: const [0, 0.8],
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ).createShader(bounds);
      },
      child: ValueRecordingGraph(
        notifier: notifier,
        minY: minY,
        maxY: maxY,
      ),
    );
  }
}
