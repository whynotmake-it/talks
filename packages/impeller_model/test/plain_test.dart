import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeller_model/impeller_model.dart';

void main() {
  FrameRecorderBinding();

  testWidgets('plain screen: single pass', (tester) async {
    await tester.pumpWidget(const ColoredBox(color: Color(0xFF336699)));
    final capture = await FrameRecorderBinding.instance.captureFrame(tester);
    final report = analyzeFrame(capture);
    for (final t in report.timelines) {
      // ignore: avoid_print
      print('${t.profile.name}: ${t.passes.length} passes, flips=${t.flips}');
      for (final p in t.passes) {
        // ignore: avoid_print
        print('  ${p.label} ${p.size} reason=${p.reason} draws=${p.drawCount}');
      }
      expect(t.passes.length, 1, reason: t.profile.name);
    }
    // ignore: avoid_print
    print(report.toJsonString());
  });
}
