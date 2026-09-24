import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';

// Content from docs/render-stack-visualization.md (the spec). Example values
// are for its demo tree (a frosted card with a focused CupertinoTextField over
// a blue page) on an iPhone 15 Pro, Flutter 3.47.5, --profile, Impeller Metal.
// Items marked [verify] or [estimate] there are unverified; keep them off
// final slides until they're ticked. Tiers 2-5 and the caret counts follow the
// real dumps in internal/demo-tree-dumps.md (widget test, 3.47.5); the planes
// show the curated app-less subset (no route boundaries, barrier or
// FollowerLayer).

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
      'RenderColoredBox · page',
      'RenderClipRRect',
      'RenderBackdropFilter',
      'RenderDecoratedBox · field',
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
      '   drawRRect  field',
      '   drawRRect  border',
      '③ drawParagraph  text',
      '④ drawRRect  caret',
    ]),
    note:
        'Painting records a tape. Nothing is drawn yet. ② holds the frost '
        'and the white field with its hairline border.',
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
      'Transform  root',
      '├ app shell ▸',
      '│ ├ Picture ①  page',
      '│ └ ClipRRect',
      '│   └ BackdropFilter',
      '│     ├ Picture ②',
      '│     └ field ▸ ③  caret ④',
      '└ Follower',
    ]),
    note:
        'Layers are folders for tapes and effects. ▸ collapses the app '
        "shell and the text field's helper layers.",
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
      'DrawDisplayList ②',
      'DrawDisplayList ③ ④',
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
      StackPass('P6', 'subpass', drawCalls: 6),
    ]),
    note:
        'The backdrop ends P1, runs 3 blur passes, then re-seeds P5 with a '
        'full-screen redraw. Pass list and ~12 draw calls: [estimate].',
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

/// Lighting for a ticker frame (spec section 5): tiers 1-4 off (nothing is
/// dirty), 5 dim, 6-9 hot.
final tickerFrameLight = {
  5: TierLight.dim,
  ..._lit([6, 7, 8, 9], TierLight.hot),
};

const _rebuild = LoopArc(id: 'A', label: 'Rebuild', startTier: 1);
const _repaint = LoopArc(id: 'C', label: 'Repaint', startTier: 3);

/// The talk's aha: a running Ticker requests a frame every vsync, and every
/// frame runs Scene, raster and GPU, whether or not anything repainted.
const _tickerFrame = LoopArc(
  id: 'T',
  label: 'Ticker frame',
  startTier: 1,
  activeFromTier: 5,
  prominent: true,
  origin: 'Ticker · every vsync',
);

const _tickerFrameRunning = LoopArc(
  id: 'T',
  label: 'Ticker frame',
  startTier: 1,
  activeFromTier: 5,
  prominent: true,
  origin: 'Ticker · every vsync',
  perSecond: 119,
  rateLabel: '≈119 frames/s\n≈111 repaint nothing',
);

/// Measured for the demo's caret: 8 repainting ticks per 1.017 s blink cycle
/// (internal/demo-tree-dumps.md).
const _caretRepaint = LoopArc(
  id: 'C',
  label: 'Repaint',
  startTier: 3,
  perSecond: 7.9,
  rateLabel: '≈8/s',
);

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
  RenderStackStep(
    RenderStackView(
      light: {6: TierLight.dim, 7: TierLight.dim, 8: TierLight.hot},
      borders: {StackBorder.gpu},
      feedback: true,
    ),
    caption:
        'Two signals come back down. When the GPU falls behind, the raster '
        'thread waits for a drawable, and DevTools counts it as raster time.',
  ),
];

/// Build-up step 2 (1, the hook): the stack dims and the demo comes forward.
const hookScript = [
  RenderStackStep(
    RenderStackView(
      phone: HookPhone(
        question: 'What keeps the GPU busy?',
        options: [
          'A  The blur',
          'B  The list underneath',
          'C  The blinking cursor',
          'D  The keyboard',
        ],
      ),
    ),
    caption:
        'A search sheet over the app drove the GPU to its limit and never let '
        'it rest. Vote now; we come back to it.',
  ),
];

/// Build-up step 7 (4, why a blur costs): the GPU tier's tile memory.
const blurCostScript = [
  RenderStackStep(
    RenderStackView(
      light: {8: TierLight.dim},
      tiles: TilePhase.fill,
      borders: {StackBorder.gpu},
    ),
    caption:
        'Mobile GPUs render in on-chip tiles. MSAA color and depth are '
        'memoryless: they never leave the chip.',
  ),
  RenderStackStep(
    RenderStackView(
      light: {8: TierLight.hot},
      tiles: TilePhase.flush,
      borders: {StackBorder.gpu},
    ),
    caption:
        'The backdrop blur needs pixels already drawn. The pass snaps: the '
        'frame so far is stored to DRAM as T0, then blurred.',
  ),
  RenderStackStep(
    RenderStackView(
      light: {8: TierLight.hot},
      tiles: TilePhase.reseed,
      borders: {StackBorder.gpu},
    ),
    caption:
        'The resumed pass is re-seeded from DRAM with a full-screen redraw. '
        'Every frame, 120 times a second.',
  ),
];

/// Build-up step 5 (3, the aha): a running Ticker means a full frame every
/// vsync; the RepaintBoundary myth; #192128.
final ahaScript = [
  const RenderStackStep(
    RenderStackView(
      arcs: [_rebuild, _repaint, _tickerFrame],
      borders: {StackBorder.gpu},
    ),
    caption:
        'Loops run from where work starts up to the top. A rebuild starts at '
        'your code, a repaint at paint. A ticker frame starts at the vsync.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [_tickerFrameRunning, _caretRepaint],
      light: tickerFrameLight,
      borders: const {StackBorder.gpu},
    ),
    caption:
        'A running Ticker means a full frame every vsync: about 119 a second, '
        '111 of them with nothing repainted. Scene, raster and GPU run anyway.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [_tickerFrameRunning],
      light: tickerFrameLight,
      borders: const {StackBorder.gpu},
    ),
    caption:
        "RepaintBoundary can't help: nothing is repainting. The Ticker still "
        'asks for a frame every vsync, and tiers 5 to 9 stay hot.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [
        LoopArc(
          id: 'T',
          label: 'Ticker frame',
          startTier: 1,
          endTier: 5,
          activeFromTier: 5,
          prominent: true,
          origin: 'Ticker · every vsync',
          perSecond: 119,
          rateLabel: '≈111 frames/s stop here',
          cutNote: '#192128',
        ),
        _caretRepaint,
      ],
      light: {
        ..._lit([3, 4, 5], .2),
        ..._lit([6, 7, 8, 9], .5),
      },
      borders: const {StackBorder.gpu},
    ),
    caption:
        'With #192128 (master), a ticker frame with nothing dirty stops before '
        'the handoff: ≈8 rendered frames per second instead of ≈119.',
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
