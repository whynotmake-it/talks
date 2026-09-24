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
    'hook': hookScript,
    'UI half': uiHalfScript,
    'raster half': rasterHalfScript,
    'aha': ahaScript,
    'blur cost': blurCostScript,
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

  testWidgets('an expanded tier shows its detail card and key fact', (
    tester,
  ) async {
    await tester.pumpWidget(host(const RenderStackView(expanded: {4})));
    await pumpFrames(tester);

    expect(find.text('4  LAYER TREE'), findsOneWidget);
    expect(find.text('│   └ BackdropFilter'), findsOneWidget);
    expect(find.textContaining('Layers are folders'), findsOneWidget);

    await tester.pumpWidget(host(const RenderStackView(expanded: {7})));
    await pumpFrames(tester);

    expect(find.text('MSAA backdrop'), findsOneWidget);
    expect(find.text('│   └ BackdropFilter'), findsNothing);
  });

  testWidgets('draws the borders with their labels', (tester) async {
    await tester.pumpWidget(
      host(const RenderStackView(borders: {...StackBorder.values})),
    );
    await pumpFrames(tester);

    expect(find.text('GPU EXECUTES ↑'), findsOneWidget);
    expect(find.text('UI → RASTER THREAD · same CPU'), findsOneWidget);
    expect(find.text('PRESENT → SYSTEM COMPOSITOR'), findsOneWidget);
  });

  testWidgets('labels loop arcs with their rate, and cut ones', (tester) async {
    await tester.pumpWidget(host(ahaScript.last.view));
    await pumpFrames(tester);

    expect(find.text('C · Repaint\n≈8/s'), findsOneWidget);
    expect(
      find.text(
        'T · Ticker frame\n≈111 frames/s: no Scene\nTicker · every vsync',
      ),
      findsOneWidget,
    );
    expect(find.text('✂ #192128 · drawFrame gate'), findsOneWidget);
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

  testWidgets('the hook brings the phone and the vote forward', (
    tester,
  ) async {
    await tester.pumpWidget(host(hookScript.first.view));
    await pumpFrames(tester);

    expect(find.text('What keeps the GPU busy?'), findsOneWidget);
    expect(find.text('C  The blinking cursor'), findsOneWidget);
    expect(find.text('9  Pixels'), findsNothing);
  });

  testWidgets('tiles flush to DRAM and re-seed from it', (tester) async {
    await tester.pumpWidget(host(blurCostScript.first.view));
    await pumpFrames(tester);
    expect(find.text('DRAM'), findsNothing);

    await tester.pumpWidget(host(blurCostScript[1].view));
    await pumpFrames(tester);
    expect(find.text('store T0: 1179×2556 RGBA8 ≈ 12 MB'), findsOneWidget);

    await tester.pumpWidget(host(blurCostScript[2].view));
    await pumpFrames(tester);
    expect(find.text('re-seed: full-screen redraw from T0'), findsOneWidget);
  });

  testWidgets('shows back-pressure and completion arrows', (tester) async {
    await tester.pumpWidget(host(rasterHalfScript.last.view));
    await pumpFrames(tester);

    expect(find.textContaining('BACK-PRESSURE'), findsOneWidget);
    expect(find.textContaining('COMPLETION'), findsOneWidget);
  });

  testWidgets('arc labels stay clear of every arc line', (tester) async {
    for (final step in ahaScript) {
      await tester.pumpWidget(host(step.view));
      await pumpFrames(tester);

      final lines = [
        for (final arc in step.view.arcs)
          for (final kind in ['line', 'dim'])
            if (find
                .byKey(ValueKey('arc-$kind-${arc.id}'))
                .evaluate()
                .isNotEmpty)
              tester.getRect(find.byKey(ValueKey('arc-$kind-${arc.id}'))),
      ];
      final labels = [
        for (final arc in step.view.arcs) ...[
          tester.getRect(find.textContaining('${arc.id} · ${arc.label}')),
          if (arc.cutNote.isNotEmpty)
            tester.getRect(find.text('✂ ${arc.cutNote}')),
        ],
      ];
      for (final label in labels) {
        for (final line in lines) {
          expect(label.overlaps(line), isFalse, reason: '$label vs $line');
        }
      }
    }
  });
}
