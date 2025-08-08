import 'package:community_charts_flutter/community_charts_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:value_notifier_tools/value_notifier_tools.dart';

class ValueRecordingGraph<T extends num> extends HookWidget {
  const ValueRecordingGraph({
    required this.notifier,
    this.from,
    this.to,
    this.minY,
    this.maxY,
    super.key,
  }) : window = null;

  const ValueRecordingGraph.window({
    required this.notifier,
    required Duration this.window,
    this.minY,
    this.maxY,
    super.key,
  }) : from = null,
       to = null;

  final ValueRecordingNotifier<T> notifier;

  final Duration? window;

  final DateTime? from;

  final DateTime? to;

  final T? minY;

  final T? maxY;

  ValueListenable<List<TimedValue<T>>> get selectedNotifier => switch (window) {
    final window? => notifier.select(
      (value) => value.window(window),
    ),
    null => notifier.select(
      (value) => value.subset(
        from: from,
        to: to,
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = useValueListenable(selectedNotifier);
    if (values.isEmpty) return SizedBox.shrink();

    return SizedBox.expand(
      child: TimeSeriesChart(
        [
          Series<TimedValue<T>, DateTime>(
            id: '',
            data: values,
            domainFn: (datum, index) {
              final now = DateTime.now();
              final date = -datum.$1.difference(now);

              return DateTime.fromMillisecondsSinceEpoch(date.inMilliseconds);
            },
            measureFn: (datum, index) => datum.$2,
          ),
        ],
        defaultInteractions: false,
        animate: false,
        flipVerticalAxis: true,
      ),
    );
  }
}
