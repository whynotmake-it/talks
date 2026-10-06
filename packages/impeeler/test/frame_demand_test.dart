import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeeler/impeeler.dart';

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
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

Widget _field() => const MaterialApp(
  home: Scaffold(body: Center(child: TextField(autofocus: true))),
);

void main() {
  testWidgets('a static screen requests no frames', (tester) async {
    await tester.pumpWidget(const ColoredBox(color: Colors.blue));
    final demand = await measureFrameDemand(tester);
    expect(demand.verdict, FrameDemandVerdict.idle);
    expect(demand.framesDrawn, 0);
    expect(demand.stillRequesting, isFalse);
  });

  testWidgets('a repeating animation requests every vsync', (tester) async {
    await tester.pumpWidget(const _Pulse());
    final demand = await measureFrameDemand(tester);
    expect(demand.verdict, FrameDemandVerdict.continuous);
    expect(demand.framesDrawn, 60);
    expect(demand.sources.first.origin.isTicker, isTrue);
    // The ticker's start is traced back to the State that started it.
    expect(demand.sources.first.origin.appFrame, contains('_PulseState'));
    final ticker = demand.activeTickers.single;
    expect(ticker.owner, '_Pulse');
    expect(ticker.ownerLocation, contains('frame_demand_test.dart'));
  });

  testWidgets('the Android caret blinks with a timer: 2 frames per second', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_field());
    await tester.pump();
    final demand = await measureFrameDemand(
      tester,
      window: const Duration(seconds: 2),
    );
    expect(demand.verdict, FrameDemandVerdict.periodic);
    // One toggle per 500 ms; the window may catch 3 or 4 of them.
    expect(demand.framesDrawn, inInclusiveRange(3, 4));
    expect(demand.unchangedFrames, 0);
    expect(demand.sources.first.origin.description, contains('editable'));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'the iOS caret fades with a ticker and repeats identical frames',
    (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_field());
      await tester.pump();
      final demand = await measureFrameDemand(
        tester,
        window: const Duration(seconds: 2),
      );
      expect(demand.verdict, FrameDemandVerdict.continuous);
      // The caret holds fully visible / invisible between fades, so many of
      // those frames draw exactly what the previous one did.
      expect(demand.unchangedFrames, greaterThan(demand.framesDrawn ~/ 4));
      expect(
        demand.activeTickers.map((t) => t.owner),
        contains('EditableText'),
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('a device preset measures with its platform', (tester) async {
    // The test runs as Android; the iPhone preset must still show the iOS
    // caret, which animates every vsync, and every frame's passes.
    await tester.pumpWidget(_field());
    await tester.pump();
    final demand = await measureFrameDemand(
      tester,
      device: GpuDevice.iPhone16,
    );
    expect(demand.verdict, FrameDemandVerdict.continuous);
    expect(demand.frames.every((f) => f.renderPasses == 1), isTrue);
    // Every frame names its source, the first one included.
    expect(demand.frames.every((f) => f.requestKeys.isNotEmpty), isTrue);
    expect(defaultTargetPlatform, TargetPlatform.android);
  });
}
