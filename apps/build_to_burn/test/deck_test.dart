import 'package:build_to_burn/main.dart';
import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/stage_slide_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

void main() {
  setUpAll(() async {
    // Lay out with the real fonts, not the test font's 1em-wide glyphs.
    for (final (family, file) in [
      ('Archivo', 'Archivo-VariableFont_wdth,wght.ttf'),
      ('JetBrains Mono', 'JetBrainsMono-VariableFont_wght.ttf'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$file'))).load();
    }
  });

  testWidgets('opens on the title slide', (tester) async {
    await tester.pumpWidget(const BuildToBurnTalk());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('From build\nto burn'), findsOneWidget);
    expect(find.text('01 / 08'), findsOneWidget);
  });

  testWidgets('every slide lays out', (tester) async {
    await tester.pumpWidget(const BuildToBurnTalk());
    await tester.pump(const Duration(seconds: 1));

    for (var slide = 2; slide <= 8; slide++) {
      FlutterDeck.of(tester.element(find.byType(SlideFrame).last)).next();
      // The hook slide's caret never settles, so pump frames explicitly.
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('0$slide / 08'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows the speaker from the speaker notes', (tester) async {
    await tester.pumpWidget(
      FlutterDeckApp(slides: const [_TimSlide()]),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('TIM'), findsOneWidget);
  });
}

class _TimSlide extends FlutterDeckSlideWidget {
  const _TimSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/tim',
          speakerNotes: '$timSlideNotesHeader\nNotes.',
        ),
      );

  @override
  Widget build(BuildContext context) =>
      const StageSlideTemplate(section: 'Test', title: 'Title', lead: 'Lead');
}
