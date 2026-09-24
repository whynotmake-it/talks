import 'package:build_to_burn/visualizations/blur_scenario.dart';
import 'package:build_to_burn/visualizations/frame_pipeline.dart';
import 'package:build_to_burn/visualizations/paint_vs_composite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';

void main() {
  setUpAll(loadDeckFonts);

  Widget host(Widget child) => MaterialApp(
    home: Center(child: SizedBox(width: 1600, height: 640, child: child)),
  );

  /// Pumps frames explicitly: looping animations never settle.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('FramePipeline', () {
    testWidgets('shows each stage caption, and none when empty', (
      tester,
    ) async {
      await tester.pumpWidget(host(const FramePipeline()));
      await pumpFrames(tester);
      for (final stage in FrameStage.values) {
        expect(find.text(stage.caption), findsNothing);
      }

      for (final stage in FrameStage.values) {
        await tester.pumpWidget(host(FramePipeline(stage: stage)));
        await pumpFrames(tester);
        expect(find.text(stage.caption), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('hides the caption on request', (tester) async {
      await tester.pumpWidget(
        host(
          const FramePipeline(stage: FrameStage.gpu, showCaption: false),
        ),
      );
      await pumpFrames(tester);

      expect(find.text(FrameStage.gpu.caption), findsNothing);
      expect(find.text('Blur × 3'), findsOneWidget);
    });
  });

  group('PaintVsComposite', () {
    testWidgets('multiplies frames by passes for each aha step', (
      tester,
    ) async {
      final expected = {
        // (frames/s, passes/frame, GPU work)
        0: ('120', '≈5', '≈600'),
        1: ('0', '≈5', '0'),
        2: ('120', '1', '120'),
        3: ('2', '≈5', '≈10'),
      };
      for (final MapEntry(key: index, value: numbers) in expected.entries) {
        final scenario = BlurScenario.ahaSequence[index];
        await tester.pumpWidget(host(PaintVsComposite(scenario: scenario)));
        await pumpFrames(tester);

        expect(find.text(numbers.$1), findsWidgets, reason: '$index');
        expect(find.text(numbers.$2), findsWidgets, reason: '$index');
        expect(find.text(numbers.$3), findsWidgets, reason: '$index');
        expect(find.text(scenario.caption), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
