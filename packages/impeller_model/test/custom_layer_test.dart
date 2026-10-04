// Custom `Layer` subclasses that push their own clips and filters in
// `addToScene` (liquid_glass_renderer's `LiquidGlassCapture` does): the model
// reads them from the scene the engine receives.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeller_model/impeller_model.dart';

import 'cases_test.dart' show captureNow, dir, timelineFor;

/// What a custom layer pushes in `addToScene`.
enum _Push {
  /// A hard-edge clip and an identity backdrop, keeping the clip's engine
  /// layer, as `LiquidGlassCapture` does.
  clipAndBackdrop,

  /// Nothing: only the children.
  nothing,

  /// A backdrop whose engine layer it does not keep.
  untrackedBackdrop,
}

class _CustomLayer extends ContainerLayer {
  _CustomLayer(this.push, this.clip);

  final _Push push;
  final Rect clip;

  @override
  void addToScene(ui.SceneBuilder builder) {
    switch (push) {
      case _Push.clipAndBackdrop:
        engineLayer = builder.pushClipRect(clip, clipBehavior: Clip.hardEdge);
        builder.pushBackdropFilter(
          ui.ImageFilter.matrix(Matrix4.identity().storage),
        );
        addChildrenToScene(builder);
        builder
          ..pop()
          ..pop();
      case _Push.nothing:
        addChildrenToScene(builder);
      case _Push.untrackedBackdrop:
        builder.pushBackdropFilter(
          ui.ImageFilter.matrix(Matrix4.identity().storage),
        );
        addChildrenToScene(builder);
        builder.pop();
    }
  }
}

class _CustomLayerWidget extends SingleChildRenderObjectWidget {
  const _CustomLayerWidget({required this.push, super.child});

  final _Push push;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCustomLayer(push);
}

class _RenderCustomLayer extends RenderProxyBox {
  _RenderCustomLayer(this.push);

  final _Push push;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushLayer(
      _CustomLayer(push, offset & size),
      super.paint,
      Offset.zero,
    );
  }
}

/// Two blurs in a 400x300 box, wrapped by [wrap].
Widget _scene(Widget Function(Widget blurs) wrap) => dir(
  Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
      Positioned(
        left: 200,
        top: 150,
        width: 400,
        height: 300,
        child: wrap(
          Stack(
            children: [
              for (final dx in [40.0, 200.0])
                Positioned(
                  left: dx,
                  top: 50,
                  width: 150,
                  height: 150,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  ),
);

List<String> _shape(FrameCapture capture) => [
  for (final p in timelineFor(capture, CapabilityProfile.iosDevice).passes)
    '${p.role.name} ${p.size.width.round()}x${p.size.height.round()}',
];

void main() {
  testWidgets('a custom clip + backdrop layer estimates like the widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scene(
        (blurs) => ClipRect(
          clipBehavior: Clip.hardEdge,
          child: BackdropFilter(
            filter: ui.ImageFilter.matrix(Matrix4.identity().storage),
            child: blurs,
          ),
        ),
      ),
    );
    final widgets = captureNow();

    await tester.pumpWidget(
      _scene(
        (blurs) =>
            _CustomLayerWidget(push: _Push.clipAndBackdrop, child: blurs),
      ),
    );
    final custom = captureNow();

    expect(_shape(custom), _shape(widgets));
    expect(custom.sceneLayers, {'_CustomLayer'});
    expect(custom.unmodeledLayers, isEmpty);
  });

  testWidgets('a custom layer that pushes nothing is not flagged', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scene((blurs) => _CustomLayerWidget(push: _Push.nothing, child: blurs)),
    );
    final capture = captureNow();
    expect(capture.unmodeledLayers, isEmpty);
  });

  testWidgets('a push without a kept engine layer is flagged', (tester) async {
    await tester.pumpWidget(
      _scene(
        (blurs) =>
            _CustomLayerWidget(push: _Push.untrackedBackdrop, child: blurs),
      ),
    );
    final capture = captureNow();
    expect(capture.unmodeledLayers, {'_CustomLayer'});
  });
}
