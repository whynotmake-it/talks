// Custom `Layer` subclasses that push their own clips and filters in
// `addToScene` (liquid_glass_renderer's `LiquidGlassCapture` does): the model
// reads them from the scene the engine receives.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeeler/impeeler.dart';
import 'package:impeeler/src/capture/layer_walk.dart' show LayerWalker;

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

  /// A clip it keeps, then a sibling backdrop it does not keep.
  clipThenSiblingBackdrop,
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
      case _Push.clipThenSiblingBackdrop:
        engineLayer = builder.pushClipRect(clip, clipBehavior: Clip.hardEdge);
        builder
          ..pop()
          ..pushBackdropFilter(
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

/// A PictureLayer subclass, as a package might use to cache a picture.
class _CachedPictureLayer extends PictureLayer {
  _CachedPictureLayer(super.canvasBounds);
}

/// Paints a full-size blur into a [_CachedPictureLayer] when [subclass], else
/// into a plain PictureLayer.
class _BlurPicture extends LeafRenderObjectWidget {
  const _BlurPicture({required this.subclass});

  final bool subclass;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlurPicture(subclass: subclass);
}

class _RenderBlurPicture extends RenderBox {
  _RenderBlurPicture({required this.subclass});

  final bool subclass;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final bounds = offset & size;
    final recorder = RendererBinding.instance.createPictureRecorder();
    RendererBinding.instance
        .createCanvas(recorder)
        .drawRect(
          bounds,
          Paint()
            ..color = const Color(0xFF3366CC)
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        );
    final layer = subclass ? _CachedPictureLayer(bounds) : PictureLayer(bounds);
    context.addLayer(layer..picture = recorder.endRecording());
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

  testWidgets('pushes a layer does not keep are flagged', (tester) async {
    await tester.pumpWidget(
      _scene(
        (blurs) => _CustomLayerWidget(
          push: _Push.clipThenSiblingBackdrop,
          child: blurs,
        ),
      ),
    );
    final capture = captureNow();
    expect(capture.unmodeledLayers, {LayerWalker.unattributedPushes});
  });

  testWidgets('a custom layer is still read after a toImage snapshot', (
    tester,
  ) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: _scene(
          (blurs) =>
              _CustomLayerWidget(push: _Push.clipAndBackdrop, child: blurs),
        ),
      ),
    );
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async => (await render.toImage()).dispose());
    await tester.pump();
    final capture = captureNow();
    expect(capture.sceneLayers, {'_CustomLayer'});
    expect(capture.unmodeledLayers, isEmpty);
  });

  testWidgets('a PictureLayer subclass draws like a PictureLayer', (
    tester,
  ) async {
    await tester.pumpWidget(const _BlurPicture(subclass: false));
    final plain = captureNow();
    await tester.pumpWidget(const _BlurPicture(subclass: true));
    final subclass = captureNow();
    expect(_shape(plain).length, greaterThan(1));
    expect(_shape(subclass), _shape(plain));
  });
}
