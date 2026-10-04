import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeller_model/impeller_model.dart';
import 'package:impeller_model_example/live_dot.dart';

Widget _app(double? fps) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: LiveDot(fps: fps)),
);

void main() {
  testWidgets('a vsync pulse draws every frame', (tester) async {
    await tester.pumpWidget(_app(null));
    final demand = await measureFrameDemand(tester);
    expect(demand.verdict, FrameDemandVerdict.continuous);
    expect(demand.activeTickers.single.owner, 'LiveDot');
  });

  testWidgets('the same pulse at 10 fps draws a sixth of the frames', (
    tester,
  ) async {
    await tester.pumpWidget(_app(10));
    final demand = await measureFrameDemand(tester);
    print('${demand.framesDrawn} frames in ${demand.window.inMilliseconds} ms');
    expect(demand.verdict, FrameDemandVerdict.periodic);
    expect(demand.framesDrawn, inInclusiveRange(9, 11));
  });
}
