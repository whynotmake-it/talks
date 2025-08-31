import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_graph.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';

class MotionGraph extends HookWidget {
  const MotionGraph({
    required this.notifier,
    this.filterIdentical = false,
    super.key,
    this.minY = 0,
    this.maxY = 1.0,
    this.color,
  });

  final ValueRecordingNotifier<double> notifier;
  final bool filterIdentical;
  final double minY;
  final double maxY;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueRecordingGraph(
      filterIdentical: filterIdentical,
      notifier: notifier,
      minY: minY,
      maxY: maxY,
    );
  }
}
