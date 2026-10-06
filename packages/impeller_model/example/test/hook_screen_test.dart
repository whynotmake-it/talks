import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeller_model/impeller_model.dart';
import 'package:impeller_model_example/main.dart';

void main() {
  testWidgets('hook screen with the name dialog', (tester) async {
    await tester.pumpWidget(const HookApp());

    // Writes test/.impeller_model/hook_screen_with_the_name_dialog.{json,html}.
    final report = await estimateGpu(tester, screenshot: true);

    final iPhone = report.frames.first;
    print(
      '${iPhone.device.name}: ${iPhone.renderPasses} render passes, '
      '${iPhone.traffic.relativeToPlainFrame.toStringAsFixed(1)}x the memory '
      'traffic of a plain frame',
    );
    for (final c in iPhone.costCenters) {
      print('  ${c.label}: ${c.renderPasses} passes');
    }

    // Budgets: fail the test when a change makes the screen more expensive.
    expect(iPhone.renderPasses, lessThanOrEqualTo(8));
    // The caret blinks: on iOS it animates its opacity every vsync.
    expect(report.frameDemand!.verdict, FrameDemandVerdict.continuous);
  });

  testWidgets('hook screen without the dialog', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(home: HookScreen(showDialog: false)),
    );
    final report = await estimateGpu(tester);
    for (final frame in report.frames) {
      expect(frame.renderPasses, 1, reason: frame.device.name);
    }
    expect(report.frameDemand!.verdict, FrameDemandVerdict.idle);
  });
}
