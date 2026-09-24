import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';

// Placeholder content until docs/render-stack-visualization.md exists. Swap
// the text here; the mechanics in render_stack.dart don't need to change.

/// The planes, bottom (widget code) to top (pixels).
const renderStackPlanes = [
  StackPlane(
    id: 'widgets',
    title: 'Widgets',
    subtitle: 'your code',
    side: StackSide.cpu,
    inputs: 'app state',
    outputs: 'widget tree',
    items: ['Container', 'BackdropFilter', 'ColoredBox'],
  ),
  StackPlane(
    id: 'render-objects',
    title: 'Render objects',
    subtitle: 'UI thread · layout + paint',
    side: StackSide.cpu,
    inputs: 'widget tree',
    outputs: 'paint() calls',
    items: ['RenderDecoratedBox', 'RenderBackdropFilter', 'RenderColoredBox'],
  ),
  StackPlane(
    id: 'layers',
    title: 'Layers + pictures',
    subtitle: 'UI thread · recorded, not drawn',
    side: StackSide.cpu,
    inputs: 'paint() calls',
    outputs: 'layer tree',
    items: ['OffsetLayer', 'BackdropFilterLayer', 'PictureLayer'],
  ),
  StackPlane(
    id: 'scene',
    title: 'Engine handoff',
    subtitle: 'UI thread · SceneBuilder',
    side: StackSide.cpu,
    inputs: 'layer tree',
    outputs: 'Scene',
    items: ['Scene'],
  ),
  StackPlane(
    id: 'raster',
    title: 'Raster',
    subtitle: 'raster thread · one DisplayList',
    side: StackSide.cpu,
    inputs: 'Scene',
    outputs: 'GPU commands',
    items: ['DisplayList', 'Impeller Canvas'],
  ),
  StackPlane(
    id: 'draw-calls',
    title: 'Draw calls + shaders',
    subtitle: 'GPU · render passes',
    side: StackSide.gpu,
    inputs: 'GPU commands',
    outputs: 'tiles',
    items: ['Pass 1', 'Blur × 3', 'Pass 2'],
  ),
  StackPlane(
    id: 'pixels',
    title: 'Pixels',
    subtitle: 'display · next vsync',
    side: StackSide.gpu,
    inputs: 'tiles',
    outputs: 'the screen',
  ),
];

/// The id of the first GPU plane; the CPU/GPU border sits below it.
final firstGpuPlane = renderStackPlanes
    .firstWhere((plane) => plane.side == StackSide.gpu)
    .id;

Set<String> _upTo(String id) => {
  for (final plane in renderStackPlanes.take(
    renderStackPlanes.indexWhere((plane) => plane.id == id) + 1,
  ))
    plane.id,
};

final _all = _upTo('pixels');

const _repaintLoop = LoopPulse(
  from: 'render-objects',
  to: 'layers',
  label: 'repaint',
);

const _frameLoop = LoopPulse(
  from: 'scene',
  to: 'pixels',
  label: 'every frame',
  period: Duration(milliseconds: 900),
  tone: StackTone.hot,
);

/// A build-up that exercises every mechanic. Placeholder captions.
final renderStackIntro = [
  RenderStackStep(
    RenderStackView(visible: _upTo('widgets'), open: const {'widgets'}),
    caption: '[placeholder] Widget code at the bottom.',
  ),
  RenderStackStep(
    RenderStackView(
      visible: _upTo('render-objects'),
      open: const {'render-objects'},
      highlighted: const {'render-objects'},
    ),
    caption: '[placeholder] Render objects lay out and paint.',
  ),
  RenderStackStep(
    RenderStackView(
      visible: _upTo('layers'),
      open: const {'layers'},
      highlighted: const {'layers'},
    ),
    caption: '[placeholder] Paint records pictures into layers.',
  ),
  RenderStackStep(
    RenderStackView(
      visible: _upTo('scene'),
      open: const {'scene'},
      highlighted: const {'scene'},
    ),
    caption: '[placeholder] The layer tree is handed to the engine.',
  ),
  RenderStackStep(
    RenderStackView(
      visible: _upTo('raster'),
      open: const {'raster'},
      highlighted: const {'raster'},
    ),
    caption: '[placeholder] The raster thread flattens it into one list.',
  ),
  RenderStackStep(
    RenderStackView(
      visible: _upTo('draw-calls'),
      open: const {'draw-calls'},
      hot: const {'draw-calls'},
      showBorder: true,
    ),
    caption: '[placeholder] Work crosses from CPU to GPU: draw calls.',
  ),
  RenderStackStep(
    RenderStackView(visible: _all, showBorder: true),
    caption: '[placeholder] Pixels on screen.',
  ),
  RenderStackStep(
    RenderStackView(visible: _all, showBorder: true, showInputsOutputs: true),
    caption: '[placeholder] Every plane has inputs and outputs.',
  ),
  RenderStackStep(
    RenderStackView(
      visible: _all,
      showBorder: true,
      highlighted: const {'render-objects', 'layers'},
      pulses: const [_repaintLoop],
    ),
    caption: '[placeholder] A repaint reruns only the lower loop.',
  ),
  RenderStackStep(
    RenderStackView(
      visible: _all,
      showBorder: true,
      hot: const {'raster', 'draw-calls', 'pixels'},
      pulses: const [_repaintLoop, _frameLoop],
    ),
    caption: '[placeholder] Every frame reruns everything above the handoff.',
  ),
  RenderStackStep(
    RenderStackView(visible: _all, spread: 0, showBorder: true),
    caption: '[placeholder] Collapsed: one stack, one frame.',
  ),
  RenderStackStep(
    RenderStackView(
      visible: _all,
      spread: .55,
      showBorder: true,
      pipeline: PipelineView(
        current: const {'draw-calls', 'pixels'},
        next: _upTo('raster'),
      ),
    ),
    caption: '[placeholder] Frame N+1 is prepared while frame N draws.',
  ),
];
