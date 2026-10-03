import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeller_model/impeller_model.dart';

class _Blinker extends StatefulWidget {
  @override
  State<_Blinker> createState() => _BlinkerState();
}

class _BlinkerState extends State<_Blinker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: const ColoredBox(color: Colors.red),
  );
}

void main() {
  FrameRecorderBinding();
  testWidgets('frame requests vs painted over 1s', (tester) async {
    final b = FrameRecorderBinding.instance;
    await tester.pumpWidget(_Blinker());
    final req0 = b.framesRequested;
    final drawn0 = b.framesDrawn;
    final painted0 = b.framesPainted;
    // ~1 second of wall time at 60Hz cadence.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final requested = b.framesRequested - req0;
    final drawn = b.framesDrawn - drawn0;
    final painted = b.framesPainted - painted0;
    print('requested=$requested drawn=$drawn');
    print('requesters=${b.frameRequesters}');
    print('tickerRequests=${b.tickerRequests}');
    // In a widget test every pump schedules and paints one frame; the
    // controller's ticker requests one tick per frame.
    expect(requested, 60);
    expect(drawn, 60);
    expect(painted, greaterThan(0));
    expect(b.tickerRequests.values.fold(0, (a, n) => a + n), greaterThan(0));
  });
}
