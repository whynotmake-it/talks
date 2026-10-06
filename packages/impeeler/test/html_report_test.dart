import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:impeeler/src/api/html_report.dart';

void main() {
  test('embeds the report so it round-trips and cannot close the script', () {
    final report = <String, Object?>{
      'name': 'alert',
      'flutter': '3.47.1',
      'frames': [
        {
          'device': {'name': 'iPhone 16'},
          'costCenters': [
            {'label': '</script><script>alert(1)</script> <!-- (lib/x.dart:1)'},
          ],
        },
      ],
    };

    final html = renderHtmlReport(report);

    const open = '<script type="application/json" id="report-data">';
    final start = html.indexOf(open) + open.length;
    final embedded = html.substring(start, html.indexOf('</script>', start));
    expect(jsonDecode(embedded), report);
    expect(embedded, isNot(contains('<')));
  });
}
