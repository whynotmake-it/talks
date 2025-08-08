import 'package:community_charts_flutter/community_charts_flutter.dart';
import 'package:flutter/material.dart' hide Color;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/shared/extensions/color_to_chart_color.dart';

class ValueRecordingGraph<T extends num> extends HookWidget {
  const ValueRecordingGraph({
    required this.notifier,

    this.minY,
    this.maxY,
    super.key,
  });

  final ValueRecordingNotifier<T> notifier;

  final T? minY;

  final T? maxY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.tertiary;
    final values = useValueListenable(notifier);
    if (values.isEmpty) return SizedBox.shrink();

    final now = DateTime.now();

    return SizedBox.expand(
      child: TimeSeriesChart(
        [
          Series<TimedValue<T>, DateTime>(
            id: '',
            data: values,
            domainFn: (datum, index) {
              final diff = -datum.$1.difference(now);

              return DateTime.fromMillisecondsSinceEpoch(diff.inMilliseconds);
            },
            measureFn: (datum, index) => datum.$2,
            colorFn: (datum, index) => lineColor.toChartsColor(),
            strokeWidthPxFn: (datum, index) => 5,
          ),
        ],
        primaryMeasureAxis: NumericAxisSpec(
          viewport: NumericExtents(minY!, maxY!),
          showAxisLine: false,
          renderSpec: NoneRenderSpec(),
        ),
        layoutConfig: LayoutConfig(
          leftMarginSpec: MarginSpec.fixedPixel(0),
          topMarginSpec: MarginSpec.fixedPixel(0),
          rightMarginSpec: MarginSpec.fixedPixel(0),
          bottomMarginSpec: MarginSpec.fixedPixel(0),
        ),
        domainAxis: DateTimeAxisSpec(
          renderSpec: NoneRenderSpec(),
          viewport: switch (notifier.window) {
            null => null,
            final window => DateTimeExtents(
              start: DateTime.fromMillisecondsSinceEpoch(0),
              end: DateTime.fromMillisecondsSinceEpoch(window.inMilliseconds),
            ),
          },
        ),
        defaultInteractions: false,
        animate: false,
      ),
    );
  }
}
