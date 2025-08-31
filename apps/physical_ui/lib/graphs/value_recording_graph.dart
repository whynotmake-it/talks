import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:wnma_talk/line_painter.dart';

class ValueRecordingGraph<T extends num> extends HookWidget {
  const ValueRecordingGraph({
    required this.notifier,
    this.filterIdentical = false,
    this.minY,
    this.maxY,
    super.key,
  });

  final ValueRecordingNotifier<T> notifier;

  final bool filterIdentical;

  final T? minY;

  final T? maxY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.tertiary;
    var values = useValueListenable(notifier);

    if (filterIdentical && values.isNotEmpty) {
      // Filter every value where the previous value was the same
      values = [
        values.first,
        for (var i = 1; i < values.length; i++)
          if (values[i] != values[i - 1]) values[i],
      ];
    }

    if (values.isEmpty) return SizedBox.shrink();

    // Convert values to normalized points
    final minValue = minY ?? values.reduce((a, b) => a < b ? a : b);
    final maxValue = maxY ?? values.reduce((a, b) => a > b ? a : b);
    final valueRange = maxValue - minValue;

    final points = <Offset>[];
    final xWidth = notifier.window ?? (values.length - 1);
    final maxX = values.length / xWidth;
    for (var i = 0; i < values.length; i++) {
      final x = maxX - (i / xWidth.clamp(1, double.infinity));
      final y = valueRange == 0
          ? 0.5
          : 1.0 - (values[i] - minValue) / valueRange;
      points.add(Offset(x, y));
    }

    return SizedBox.expand(
      child: LinePathWidget(
        points: points,
        gradient: LinearGradient(
          colors: [
            lineColor,
            lineColor.withValues(alpha: 0),
          ],
        ),
        thickness: 5,
      ),
    );
  }
}
