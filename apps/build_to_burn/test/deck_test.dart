import 'package:build_to_burn/main.dart';
import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/slides/skeleton.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

import 'fonts.dart';

void main() {
  setUpAll(loadDeckFonts);

  /// Pumps frames explicitly: looping visualizations never settle.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('opens on the title slide', (tester) async {
    await tester.pumpWidget(const BuildToBurnTalk());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('From build\nto burn'), findsOneWidget);
    expect(find.text('01 / 11'), findsOneWidget);
  });

  testWidgets('every slide and step lays out', (tester) async {
    await tester.pumpWidget(const BuildToBurnTalk());
    await pumpFrames(tester);

    FlutterDeck deck() =>
        FlutterDeck.of(tester.element(find.byType(SlideFrame).last));

    var advances = 0;
    while (deck().slideNumber < 11 && advances < 50) {
      deck().next();
      advances++;
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
    }

    expect(deck().slideNumber, 11);
    // 10 slide changes plus the render stack slides' extra steps.
    final extraSteps = [
      coldOpenScript,
      hookScript,
      uiHalfScript,
      rasterHalfScript,
      ahaScript,
      blurCostScript,
      profilingScript,
    ].fold(0, (sum, script) => sum + script.length - 1);
    expect(advances, 10 + extraSteps);
  });

  testWidgets('shows the speaker from the speaker notes', (tester) async {
    await tester.pumpWidget(
      FlutterDeckApp(
        slides: const [
          SkeletonSlide(
            section: 'Test',
            title: 'Title',
            configuration: FlutterDeckSlideConfiguration(
              route: '/tim',
              speakerNotes: '$timSlideNotesHeader\nNotes.',
            ),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('TIM'), findsOneWidget);
  });
}
