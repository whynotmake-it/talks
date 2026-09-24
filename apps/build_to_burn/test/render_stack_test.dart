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
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final allPlanes = {for (final plane in renderStackPlanes) plane.id};

  testWidgets('every intro step lays out, animating from the last', (
    tester,
  ) async {
    for (final step in renderStackIntro) {
      await tester.pumpWidget(host(step.view, caption: step.caption));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(step.caption), findsOneWidget);
    }
  });

  testWidgets('labels only the visible planes', (tester) async {
    await tester.pumpWidget(
      host(const RenderStackView(visible: {'widgets', 'render-objects'})),
    );
    await pumpFrames(tester);

    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('Render objects'), findsOneWidget);
    expect(find.text('Pixels'), findsNothing);
  });

  testWidgets('shows inputs and outputs on request', (tester) async {
    await tester.pumpWidget(
      host(RenderStackView(visible: allPlanes, showInputsOutputs: true)),
    );
    await pumpFrames(tester);

    expect(find.text('in  app state  →  out  widget tree'), findsOneWidget);
  });

  testWidgets("shows open planes' items, the border and loop pulses", (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        RenderStackView(
          visible: allPlanes,
          open: const {'layers'},
          showBorder: true,
          pulses: const [
            LoopPulse(from: 'render-objects', to: 'layers', label: 'repaint'),
          ],
        ),
      ),
    );
    await pumpFrames(tester);

    expect(find.text('BackdropFilterLayer'), findsOneWidget);
    expect(find.text('GPU ↑'), findsOneWidget);
    expect(find.text('↻ repaint'), findsOneWidget);
  });

  testWidgets('shows frame N+1 next to frame N in a pipeline', (tester) async {
    await tester.pumpWidget(
      host(
        RenderStackView(
          visible: allPlanes,
          pipeline: const PipelineView(
            current: {'draw-calls', 'pixels'},
            next: {'widgets', 'render-objects'},
          ),
        ),
      ),
    );
    await pumpFrames(tester);

    expect(find.text('FRAME N'), findsOneWidget);
    expect(find.text('FRAME N+1'), findsOneWidget);

    await tester.pumpWidget(host(RenderStackView(visible: allPlanes)));
    await pumpFrames(tester);

    expect(find.text('FRAME N+1'), findsNothing);
  });

  testWidgets('collapses and expands without errors', (tester) async {
    for (final spread in [0.0, 1.0, 0.0]) {
      await tester.pumpWidget(
        host(RenderStackView(visible: allPlanes, spread: spread)),
      );
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
    }
  });
}
