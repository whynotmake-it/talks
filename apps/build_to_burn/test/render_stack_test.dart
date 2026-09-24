import 'package:build_to_burn/visualizations/render_stack/render_stack.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';

void main() {
  setUpAll(loadDeckFonts);

  Widget host(RenderStackView view, {String? caption}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 1600,
        height: 900,
        child: RenderStack(view: view, caption: caption),
      ),
    ),
  );

  /// Pumps frames explicitly: loop arcs never settle.
  Future<void> pumpFrames(WidgetTester tester, {int count = 30}) async {
    for (var frame = 0; frame < count; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final scripts = {
    'cold open': coldOpenScript,
    'UI half': uiHalfScript,
    'raster half': rasterHalfScript,
    'aha': ahaScript,
    'profiling': profilingScript,
  };

  for (final MapEntry(key: name, value: script) in scripts.entries) {
    testWidgets('every $name step lays out, animating from the last', (
      tester,
    ) async {
      for (final step in script) {
        await tester.pumpWidget(host(step.view, caption: step.caption));
        await pumpFrames(tester);
        expect(tester.takeException(), isNull);
        expect(find.text(step.caption), findsOneWidget);
      }
    });
  }

  testWidgets('the default view shows all bands and tiers', (tester) async {
    await tester.pumpWidget(host(const RenderStackView()));
    await pumpFrames(tester);

    for (final tier in renderStackTiers) {
      expect(find.text('${tier.number}  ${tier.title}'), findsOneWidget);
    }
    expect(find.text('UI THREAD · PLATFORM MAIN THREAD'), findsOneWidget);
    expect(find.text('GPU AND DISPLAY'), findsOneWidget);
  });

  testWidgets('shows only the visible bands', (tester) async {
    await tester.pumpWidget(host(const RenderStackView(bands: {'code'})));
    await pumpFrames(tester);

    expect(find.text('1  Widget code'), findsOneWidget);
    expect(find.text('9  Pixels'), findsNothing);
  });

  testWidgets('expanded tiers show their detail and key fact', (tester) async {
    await tester.pumpWidget(host(const RenderStackView(expanded: {4, 7})));
    await pumpFrames(tester);

    expect(find.text('  └ BackdropFilterLayer'), findsOneWidget);
    expect(find.text('MSAA backdrop'), findsOneWidget);
    expect(find.textContaining('Layers are folders'), findsOneWidget);
  });

  testWidgets('draws the borders with their labels', (tester) async {
    await tester.pumpWidget(
      host(const RenderStackView(borders: {...StackBorder.values})),
    );
    await pumpFrames(tester);

    expect(find.text('GPU EXECUTES ↑'), findsOneWidget);
    expect(find.text('RASTER THREAD ↑'), findsOneWidget);
    expect(find.text('SYSTEM ↑'), findsOneWidget);
  });

  testWidgets('labels loop arcs with their rate, and cut ones', (tester) async {
    await tester.pumpWidget(host(ahaScript.last.view));
    await pumpFrames(tester);

    expect(find.text('C · Repaint\n8/s'), findsOneWidget);
    expect(find.text('E · Scene only\n120/s'), findsOneWidget);
    expect(find.text('✂ #192128'), findsOneWidget);
  });

  testWidgets('the token climbs the stack, then the pixels appear', (
    tester,
  ) async {
    await tester.pumpWidget(host(coldOpenScript.first.view));
    await pumpFrames(tester);
    await tester.pumpWidget(host(coldOpenScript.last.view));
    await pumpFrames(tester, count: 1);
    expect(find.text('Widget'), findsOneWidget);

    await pumpFrames(tester, count: 40);
    expect(find.text('Widget'), findsNothing);
    expect(find.text('Pixel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a spotlight names its tool', (tester) async {
    await tester.pumpWidget(host(profilingScript[1].view));
    await pumpFrames(tester);

    expect(find.text('DevTools Performance'), findsOneWidget);
  });
}
