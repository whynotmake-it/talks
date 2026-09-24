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

  /// Pumps frames explicitly: loop pulses never settle.
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

  testWidgets('the cold open is the code slide alone', (tester) async {
    await tester.pumpWidget(host(coldOpenScript.single.view));
    await pumpFrames(tester);

    expect(find.textContaining('class Demo extends'), findsOneWidget);
    expect(find.text('1  Widget code'), findsNothing);
  });

  testWidgets('the code slide lands as plane 1 and its row appears', (
    tester,
  ) async {
    await tester.pumpWidget(host(uiHalfScript[0].view));
    await pumpFrames(tester);
    await tester.pumpWidget(host(uiHalfScript[1].view));
    await pumpFrames(tester);

    expect(find.textContaining('class Demo extends'), findsNothing);
    expect(find.text('1  Widget code'), findsOneWidget);
    expect(
      find.text('your build() methods  →  widget tree'),
      findsOneWidget,
    );
  });

  testWidgets("a stage slide takes the previous stage's output as input", (
    tester,
  ) async {
    await tester.pumpWidget(host(uiHalfScript[2].view));
    await pumpFrames(tester);

    expect(find.text('STAGE 2 · RENDER OBJECTS'), findsOneWidget);
    expect(find.text('INPUT'), findsOneWidget);
    expect(find.text('from 1 Widget code'), findsOneWidget);
    expect(find.text('OUTPUT'), findsOneWidget);
    expect(find.text('laid-out render tree'), findsOneWidget);
    for (var n = 2; n <= 9; n++) {
      expect(
        renderStackTiers[n - 1].inputs,
        renderStackTiers[n - 2].outputs,
        reason: 'stage $n',
      );
    }
  });

  testWidgets('list rows show number and title; only the focus expands', (
    tester,
  ) async {
    await tester.pumpWidget(host(const RenderStackView()));
    await pumpFrames(tester);

    for (final tier in renderStackTiers) {
      expect(find.text('${tier.number}  ${tier.title}'), findsOneWidget);
    }
    expect(find.textContaining('  →  '), findsNothing);

    await tester.pumpWidget(
      host(const RenderStackView(focus: 4, landed: true)),
    );
    await pumpFrames(tester);
    expect(find.text('pictures ①–④  →  layer tree'), findsOneWidget);
    expect(find.text('9  Pixels'), findsNothing);
  });

  testWidgets('an expanded tier shows its detail card', (tester) async {
    await tester.pumpWidget(host(const RenderStackView(expanded: {4})));
    await pumpFrames(tester);

    expect(find.text('4  LAYER TREE'), findsOneWidget);
    expect(find.text('│   └ BackdropFilter'), findsOneWidget);
  });

  testWidgets('borders are brackets beside the list', (tester) async {
    await tester.pumpWidget(
      host(const RenderStackView(borders: {StackBorder.gpu})),
    );
    await pumpFrames(tester);

    expect(find.text('CPU encodes'), findsOneWidget);
    expect(find.text('GPU executes\n↓ commit at 7'), findsOneWidget);
  });

  testWidgets('labels loop brackets with their rate, and cut ones', (
    tester,
  ) async {
    await tester.pumpWidget(host(ahaScript.last.view));
    await pumpFrames(tester);

    expect(find.text('C · Repaint\n≈8/s'), findsOneWidget);
    expect(
      find.text('T · Ticker frame\n≈111 frames/s: no Scene'),
      findsOneWidget,
    );
    expect(find.text('⏱  Ticker · every vsync'), findsOneWidget);
    expect(find.text('✂ #192128 · drawFrame gate'), findsOneWidget);
  });

  testWidgets('loop labels stay clear of every loop line', (tester) async {
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
        for (final arc in step.view.arcs)
          tester.getRect(find.textContaining('${arc.id} · ${arc.label}')),
      ];
      for (final label in labels) {
        for (final line in lines) {
          expect(label.overlaps(line), isFalse, reason: '$label vs $line');
        }
      }
    }
  });

  testWidgets('a spotlight names its tool beside the list', (tester) async {
    await tester.pumpWidget(host(profilingScript[1].view));
    await pumpFrames(tester);

    expect(
      find.text('DevTools Performance\nUI + raster CPU time'),
      findsOneWidget,
    );
  });

  testWidgets('frames in flight: three frames at once, then the limits', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const RenderStackView(frames: FramesInFlight())),
    );
    await pumpFrames(tester);

    expect(find.text('frame N+1'), findsOneWidget);
    expect(find.text('frame N'), findsOneWidget);
    expect(find.text('frame N−1'), findsOneWidget);
    expect(find.text('queue ▣▢'), findsOneWidget);
    expect(find.text('drawables ▣▣▢'), findsOneWidget);

    await tester.pumpWidget(
      host(const RenderStackView(frames: FramesInFlight(limits: true))),
    );
    await pumpFrames(tester);
    expect(find.text('frame N+1\none UI thread'), findsOneWidget);
    expect(find.textContaining('image decode'), findsOneWidget);
  });

  testWidgets('the zoom-out groups the list into bands', (tester) async {
    await tester.pumpWidget(host(rasterHalfScript.last.view));
    await pumpFrames(tester);

    expect(find.text('Your code'), findsOneWidget);
    expect(find.text('Raster thread'), findsOneWidget);
    expect(find.text('GPU and display'), findsOneWidget);
  });

  testWidgets('the hook shows the phone and the vote, no stack', (
    tester,
  ) async {
    await tester.pumpWidget(host(hookScript.first.view));
    await pumpFrames(tester);

    expect(find.text('What keeps the GPU busy?'), findsOneWidget);
    expect(find.text('C  The blinking cursor'), findsOneWidget);
    expect(find.text('1  Widget code'), findsNothing);
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

  testWidgets('shows back-pressure and completion beside the list', (
    tester,
  ) async {
    final feedback = rasterHalfScript.firstWhere((step) => step.view.feedback);
    await tester.pumpWidget(host(feedback.view));
    await pumpFrames(tester);

    expect(find.textContaining('back-pressure'), findsOneWidget);
    expect(find.textContaining('completion'), findsOneWidget);
  });
}
