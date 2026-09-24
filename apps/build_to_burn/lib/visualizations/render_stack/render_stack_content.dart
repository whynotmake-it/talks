import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';

// Content from docs/render-stack-visualization.md (the spec). Example values
// are for its demo tree (a frosted card with a focused CupertinoTextField over
// a blue page) on an iPhone 15 Pro, Flutter 3.47.5, --profile, Impeller Metal.
// Items marked [verify] or [estimate] there are unverified; keep them off
// final slides until they're ticked.

const renderStackBands = [
  StackBand(id: 'code', title: 'Your code'),
  StackBand(id: 'ui', title: 'UI thread', subtitle: 'platform main thread'),
  StackBand(id: 'handoff', title: 'Handoff', connector: true),
  StackBand(id: 'raster', title: 'Raster thread', subtitle: 'CPU'),
  StackBand(id: 'gpu', title: 'GPU and display'),
];

const renderStackTiers = [
  StackTier(
    number: 1,
    band: 'code',
    title: 'Widget code',
    inputs: 'build() + state',
    outputs: 'element tree',
    where: 'UI thread',
    token: 'Widget',
    detail: ChipsDetail([
      'Stack',
      'ClipRRect(r: 24)',
      'BackdropFilter(σ 10)',
      'Container(300×120)',
      'CupertinoTextField',
    ]),
  ),
  StackTier(
    number: 2,
    band: 'ui',
    title: 'Render objects',
    inputs: 'elements, constraints',
    outputs: 'sizes, offsets, needsCompositing',
    where: 'UI thread · layout',
    token: 'RenderObject',
    detail: ChipsDetail([
      'RenderColoredBox',
      'RenderClipRRect',
      'RenderBackdropFilter',
      'RenderEditable',
      'caret painter · boundary',
    ]),
    note:
        'needsCompositing spreads upward: the blur turns the clip into a '
        'real layer.',
  ),
  StackTier(
    number: 3,
    band: 'ui',
    title: 'Paint calls',
    inputs: 'dirty repaint boundaries',
    outputs: 'Pictures (DisplayLists)',
    where: 'UI thread · PictureRecorder',
    token: 'Picture',
    detail: LinesDetail([
      '① drawRect  page',
      '② drawRect  frost',
      '③ drawParagraph  text',
      '④ drawRRect  caret',
    ]),
    note:
        'Painting records a tape. Nothing is drawn yet. A caret tick '
        're-records only ④.',
  ),
  StackTier(
    number: 4,
    band: 'ui',
    title: 'Layer tree',
    inputs: 'paint output',
    outputs: 'retained layers + pictures',
    where: 'UI thread',
    token: 'Layer',
    detail: LinesDetail([
      'TransformLayer  root',
      '├ Picture ①',
      '└ ClipRRectLayer',
      '  └ BackdropFilterLayer',
      '    ├ Pictures ② ③',
      '    └ OffsetLayer  caret',
      '      └ Picture ④',
    ]),
    note:
        'Layers are folders for tapes and effects. The caret has its own '
        'repaint boundary.',
  ),
  StackTier(
    number: 5,
    band: 'handoff',
    title: 'Scene handoff',
    inputs: 'layer tree',
    outputs: 'one single-use Scene',
    where: 'UI builds it · pipeline carries it',
    token: 'Scene',
    detail: TrayDetail(slots: 2, label: 'frame pipeline · 2 slots'),
    note:
        'Retained subtrees save UI work only. A new Scene ships every '
        'frame on stable.',
  ),
  StackTier(
    number: 6,
    band: 'raster',
    title: 'One DisplayList',
    inputs: 'LayerTree',
    outputs: 'one frame DisplayList',
    where: 'raster thread · preroll + paint',
    token: 'DisplayList',
    detail: LinesDetail([
      'Transform 3×',
      'DrawDisplayList ①',
      'ClipRRect 24',
      'SaveLayer  backdrop σ 30 px',
      'DrawDisplayList ② ③',
      'DrawDisplayList ④',
      'Restore',
    ]),
    note:
        'Layers melt into one list, replayed in full every frame. No raster '
        'cache, no partial repaint on mobile Impeller.',
  ),
  StackTier(
    number: 7,
    band: 'raster',
    title: 'Impeller passes',
    inputs: 'frame DisplayList',
    outputs: 'committed command buffers',
    where: 'raster thread encodes · GPU executes',
    token: 'Pass',
    detail: PassesDetail([
      StackPass('P1', 'offscreen · clear'),
      StackPass('P2', 'blur ↓', drawCalls: 1, hot: true),
      StackPass('P3', 'blur ↕', drawCalls: 1, hot: true),
      StackPass('P4', 'blur ↔', drawCalls: 1, hot: true),
      StackPass('P5', 'MSAA backdrop', drawCalls: 3, hot: true),
      StackPass('P6', 'subpass', drawCalls: 4),
    ]),
    note:
        'The backdrop ends P1, runs 3 blur passes, then re-seeds P5 with a '
        'full-screen redraw. Pass list and ~10 draw calls: [estimate].',
  ),
  StackTier(
    number: 8,
    band: 'gpu',
    title: 'GPU execution',
    inputs: 'command buffers',
    outputs: 'resolved drawable',
    where: 'GPU · tile memory + DRAM',
    token: 'Tile',
    detail: ChipsDetail([
      'tiles: memoryless MSAA',
      'T0 ≈ 12 MB to DRAM',
      'blur textures at ⅛',
    ]),
  ),
  StackTier(
    number: 9,
    band: 'gpu',
    title: 'Pixels',
    inputs: 'drawable',
    outputs: 'the frame on screen',
    where: 'FlutterMetalLayer · 3 drawables',
    token: 'Pixel',
    detail: ScreenDetail(),
  ),
];

/// The thin cap above the pixels: the system still composites Flutter's
/// surface.
const systemCompositorLabel = 'System compositor · iOS render server';

Map<int, double> _lit(Iterable<int> tiers, double light) => {
  for (final tier in tiers) tier: light,
};

/// Section 5's lighting for a caret tick: 1-2 off, 3-5 dim, 6-9 hot.
final caretTickLight = {
  ..._lit([3, 4, 5], TierLight.dim),
  ..._lit([6, 7, 8, 9], TierLight.hot),
};

const _rebuild = LoopArc(id: 'A', label: 'Rebuild', startTier: 1);
const _repaint = LoopArc(id: 'C', label: 'Repaint', startTier: 3);
const _sceneOnly = LoopArc(id: 'E', label: 'Scene only', startTier: 5);

/// Build-up step 1 (cold open): the bands rise, then one frame travels up.
const coldOpenScript = [
  RenderStackStep(
    RenderStackView(showPixels: false),
    caption:
        'One frame of one small widget tree, from your code at the bottom '
        'to pixels at the top.',
  ),
  RenderStackStep(
    RenderStackView(token: true),
    caption:
        'Each tier hands its output up: widget, render object, picture, '
        'layer, Scene, DisplayList, pass, tile, pixel.',
  ),
];

/// Build-up step 3 (2a, UI half): expand paint calls and the layer tree.
const uiHalfScript = [
  RenderStackStep(
    RenderStackView(expanded: {3}, light: {3: TierLight.dim}),
    caption:
        'Paint records a tape per picture. Nothing is drawn yet: ① page, '
        '② frost, ③ text, ④ caret.',
  ),
  RenderStackStep(
    RenderStackView(
      expanded: {4},
      light: {4: TierLight.dim},
      emphasis: {'BackdropFilterLayer', 'OffsetLayer'},
    ),
    caption:
        'Layers are folders for tapes and effects. The blur is a layer; the '
        'caret has its own repaint boundary.',
  ),
];

/// Build-up step 4 (2b, raster half): the handoff, one list, the passes.
const rasterHalfScript = [
  RenderStackStep(
    RenderStackView(
      expanded: {5},
      light: {5: TierLight.dim},
      borders: {StackBorder.thread},
    ),
    caption:
        'The Scene crosses to the raster thread through a queue with two '
        'slots. Same CPU, another thread.',
  ),
  RenderStackStep(
    RenderStackView(
      expanded: {6},
      light: {6: TierLight.dim},
      borders: {StackBorder.thread},
    ),
    caption:
        'The raster thread melts the layers into one DisplayList and replays '
        'all of it, every frame.',
  ),
  RenderStackStep(
    RenderStackView(
      expanded: {7},
      light: {7: TierLight.hot},
      emphasis: {'blur', 'MSAA'},
      borders: {StackBorder.thread, StackBorder.gpu, StackBorder.present},
    ),
    caption:
        'Impeller encodes render passes; the GPU executes them after commit. '
        'The blur breaks the pass: 3 blur passes and a full-screen re-seed.',
  ),
];

/// Build-up step 5 (3, the aha): loops, the caret tick, the myth, #192128.
final ahaScript = [
  const RenderStackStep(
    RenderStackView(
      arcs: [_rebuild, _repaint, _sceneOnly],
      borders: {StackBorder.gpu},
    ),
    caption:
        'Every loop starts at a tier and runs to the top. Rebuild starts at '
        'your code, repaint at paint, Scene only at the handoff.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [
        _rebuild,
        LoopArc(id: 'C', label: 'Repaint', startTier: 3, perSecond: 120),
        LoopArc(id: 'E', label: 'Scene only', startTier: 5, perSecond: 120),
      ],
      light: caretTickLight,
      borders: const {StackBorder.gpu},
    ),
    caption:
        'The caret ticks 120 times a second. Its loops are tiny at the '
        'bottom, but the top lights up as brightly as a rebuild.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [
        LoopArc(id: 'C', label: 'Repaint', startTier: 3, perSecond: 120),
        LoopArc(id: 'E', label: 'Scene only', startTier: 5, perSecond: 120),
      ],
      light: {...caretTickLight, 3: .25},
      borders: const {StackBorder.gpu},
    ),
    caption:
        'Wrap it in a RepaintBoundary: only the paint tier gets thinner. '
        'Tiers 6 to 9 stay hot.',
  ),
  const RenderStackStep(
    RenderStackView(
      arcs: [
        LoopArc(id: 'C', label: 'Repaint', startTier: 3, perSecond: 8),
        LoopArc(
          id: 'E',
          label: 'Scene only',
          startTier: 5,
          endTier: 5,
          perSecond: 120,
          cutNote: '#192128',
        ),
      ],
      light: {
        3: TierLight.dim,
        4: TierLight.dim,
        5: TierLight.dim,
        6: .7,
        7: .7,
        8: .7,
        9: .7,
      },
      borders: {StackBorder.gpu},
    ),
    caption:
        'With #192128 (master), ticks where nothing repainted stop at the '
        'handoff. Only the ~8 repainting ticks per second render [verify].',
  ),
];

/// Build-up step 8 (5, profiling): each tool lights the tiers it can see.
const profilingScript = [
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Highlight repaints',
        tiers: {3: TierLight.dim},
        shows: 'which boundaries repaint',
      ),
    ),
    caption: 'Highlight repaints sees the paint tier only.',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'DevTools Performance',
        tiers: {1: .5, 2: .5, 3: .5, 4: .5, 5: .5, 6: .3, 7: .3},
        shows: 'UI and raster CPU time; raster includes waiting for a drawable',
      ),
      borders: {StackBorder.gpu},
    ),
    caption:
        'DevTools sees the UI thread and the CPU half of the raster thread. '
        'The raster bar is CPU time, not GPU time.',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Metal System Trace',
        tiers: {6: .5, 7: .5, 8: .5},
        shows: 'GPU work every vsync, over time',
      ),
      borders: {StackBorder.gpu},
    ),
    caption: 'Instruments Metal System Trace shows GPU work every vsync.',
  ),
  RenderStackStep(
    RenderStackView(
      expanded: {7},
      spotlight: ToolSpotlight(
        tool: 'Metal frame capture',
        tiers: {7: .5, 8: .5},
        shows: 'passes, draw calls, textures: structure, not cost',
      ),
      borders: {StackBorder.gpu},
    ),
    caption:
        'An Xcode Metal frame capture shows one frame: its passes, draw calls '
        'and textures.',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Power Profiler',
        tiers: {8: .5, 9: .5},
        shows: 'power impact and thermal state',
      ),
      borders: {StackBorder.gpu},
    ),
    caption: 'Power Profiler shows what it costs in power and heat.',
  ),
];
