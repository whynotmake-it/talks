import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/widgets.dart';

extension ColorToChartColor on Color {
  charts.Color toChartsColor() => charts.Color(
    // ignore: deprecated_member_use
    r: red,
    // ignore: deprecated_member_use
    g: green,
    // ignore: deprecated_member_use
    b: blue,
  );
}
