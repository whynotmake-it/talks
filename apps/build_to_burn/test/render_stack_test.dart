import 'package:build_to_burn/shared/style.dart';
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

  test('every script caption fits on one 1760 px line', () {
    for (final MapEntry(key: name, value: script) in scripts.entries) {
      for (final step in script) {
        final painter = TextPainter(
          text: TextSpan(
            text: step.caption,
            style: archivo(48, weight: 500, height: 1.25),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 1760);
        expect(
          painter.didExceedMaxLines,
          isFalse,
          reason: '$name caption: ${step.caption}',
        );
      }
    }
  });

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
    expect(find.text('your build() methods → widget tree'), findsNothing);
  });

  testWidgets("a stage slide takes the previous stage's output as input", (
    tester,
  ) async {
    await tester.pumpWidget(host(uiHalfScript[2].view));
    await pumpFrames(tester);

    expect(find.text('Render objects'), findsOneWidget);
    expect(find.text('INPUT'), findsOneWidget);
    expect(find.text('from 1 Widget code'), findsNothing);
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
    expect(find.textContaining(' → layer tree'), findsNothing);

    await tester.pumpWidget(
      host(const RenderStackView(focus: 4, landed: true)),
    );
    await pumpFrames(tester);
    expect(find.textContaining('→ layer tree'), findsNothing);
    expect(find.text('9  Pixels'), findsNothing);
  });

  testWidgets('an expanded tier shows its detail card', (tester) async {
    await tester.pumpWidget(host(const RenderStackView(expanded: {4})));
    await pumpFrames(tester);

    expect(find.text('4  LAYER TREE'), findsOneWidget);
    expect(find.text('  └ BackdropFilter'), findsOneWidget);
  });

  testWidgets('borders are brackets beside the list', (tester) async {
    await tester.pumpWidget(
      host(const RenderStackView(borders: {StackBorder.gpu})),
    );
    await pumpFrames(tester);

    expect(find.text('CPU encodes'), findsOneWidget);
    expect(find.text('GPU executes ↑\ncommit at plane 7'), findsOneWidget);
  });

  testWidgets('labels loop brackets with their rate, and cut ones', (
    tester,
  ) async {
    await tester.pumpWidget(host(ahaScript[3].view));
    await pumpFrames(tester);

    expect(find.text('C · Repaint  8/s'), findsOneWidget);
    expect(find.text('T · Ticker'), findsOneWidget);
    expect(find.text('vsync'), findsOneWidget);
    expect(find.text('skipped'), findsOneWidget);
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
    expect(find.text('N+1 · UI'), findsOneWidget);
    expect(find.text('N · raster'), findsOneWidget);
    expect(find.text('N−1 · GPU'), findsOneWidget);

    await tester.pumpWidget(
      host(const RenderStackView(frames: FramesInFlight(limits: true))),
    );
    await pumpFrames(tester);
    expect(find.text('N+1 · UI'), findsOneWidget);
    expect(find.textContaining('image decode'), findsNothing);
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
    expect(find.text('T0 · ~12 MB'), findsOneWidget);

    await tester.pumpWidget(host(blurCostScript[2].view));
    await pumpFrames(tester);
    expect(find.text('redraw from T0'), findsOneWidget);
  });

  testWidgets('shows GPU back-pressure beside the list', (
    tester,
  ) async {
    final feedback = rasterHalfScript.firstWhere((step) => step.view.feedback);
    await tester.pumpWidget(host(feedback.view));
    await pumpFrames(tester);

    expect(find.text('GPU busy → raster waits'), findsOneWidget);
    expect(find.textContaining('completion'), findsNothing);
  });

  testWidgets('brackets stop at the highest layer on the stack', (
    tester,
  ) async {
    final landing7 = rasterHalfScript.firstWhere(
      (step) => step.view.focus == 7 && step.view.landed,
    );
    await tester.pumpWidget(host(landing7.view));
    await pumpFrames(tester);

    final label = tester.getRect(
      find.text('GPU executes ↑\ncommit at plane 7'),
    );
    final row7 = tester.getRect(find.text('7  Impeller passes'));
    expect((label.center.dy - row7.center.dy).abs(), lessThan(60));
  });

  testWidgets('after the partial #192128 cut, the spinner keeps pulsing', (
    tester,
  ) async {
    await tester.pumpWidget(host(ahaScript.last.view));
    await pumpFrames(tester);

    expect(find.text('skipped'), findsOneWidget);
    expect(find.text('S · Spinner  120/s'), findsOneWidget);
    expect(find.byKey(const ValueKey('arc-line-S')), findsOneWidget);
  });

  testWidgets('frame pills sit on their own bands, level with brackets', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const RenderStackView(frames: FramesInFlight())),
    );
    await pumpFrames(tester);

    final pills = [
      for (final name in ['N+1', 'N', 'N−1'])
        tester.getRect(find.text('frame $name')),
    ];
    final bracketLabels = ['N+1 · UI', 'N · raster', 'N−1 · GPU'];
    final brackets = [
      for (final label in bracketLabels) tester.getRect(find.text(label)),
    ];
    for (var i = 0; i < brackets.length; i++) {
      expect(brackets[i].height, lessThan(50), reason: bracketLabels[i]);
    }
    for (var i = 0; i < 3; i++) {
      if (i > 0) {
        expect(pills[i - 1].top - pills[i].bottom, greaterThan(40));
      }
      expect(
        (pills[i].center.dy - brackets[i].center.dy).abs(),
        lessThan(110),
        reason: 'pill $i',
      );
    }
  });

  testWidgets('focused rows omit speaker-reference details', (tester) async {
    await tester.pumpWidget(
      host(const RenderStackView(focus: 5, landed: true)),
    );
    await pumpFrames(tester);

    expect(find.textContaining('UI builds it'), findsNothing);
    expect(find.text('5  Scene handoff'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
