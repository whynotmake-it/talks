import 'package:build_to_burn/design/slide_frame.dart';
import 'package:build_to_burn/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('01 / 07'), findsOneWidget);
  });

  testWidgets('every slide lays out', (tester) async {
    await tester.pumpWidget(const BuildToBurnTalk());
    await tester.pump(const Duration(seconds: 1));

    for (var slide = 2; slide <= 7; slide++) {
      FlutterDeck.of(tester.element(find.byType(SlideFrame).last)).next();
      // The hook slide's caret never settles, so pump frames explicitly.
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('0$slide / 07'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}
