import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';

// Content from docs/render-stack-visualization.md (the spec): section 2 for
// the tiers, section 7.1 for the stage slides and their handoffs, section 6
// for frames in flight. Example values are for its demo tree (a frosted card
// with a focused CupertinoTextField over a blue page) on an iPhone 15 Pro,
// Flutter 3.47.5, --profile, Impeller Metal. Tiers 1-5 are [measured] (see
// internal/demo-tree-dumps.md); 6-9 are [estimate]/pending a Metal capture.
// Keep [verify]/[estimate] values off final slides until they're ticked.

const renderStackBands = [
  StackBand(id: 'code', title: 'Your code'),
  StackBand(id: 'ui', title: 'UI thread', subtitle: 'platform main thread'),
  StackBand(id: 'handoff', title: 'Handoff', connector: true),
  StackBand(id: 'raster', title: 'Raster thread', subtitle: 'CPU'),
  StackBand(id: 'gpu', title: 'GPU and display'),
];

/// The spec's `Demo` widget (section 1).
const demoCode = '''
class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF2563EB)),
        ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 300,
                height: 120,
                color: const Color(0x33FFFFFF),
                alignment: Alignment.center,
                child: const CupertinoTextField(autofocus: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}''';

const renderStackTiers = [
  StackTier(
    number: 1,
    band: 'code',
    title: 'Widget code',
    stage: 'You all write this',
    inputs: 'your build() methods',
    outputs: 'widget tree',
    example: 'ClipRRect → BackdropFilter → Container → CupertinoTextField',
    handoff: 'elements create render objects',
    where: 'UI thread (the platform main thread)',
    token: 'Widget',
    detail: CodeDetail(demoCode),
  ),
  StackTier(
    number: 2,
    band: 'ui',
    title: 'Render objects',
    stage: 'Layout: boxes snap to sizes',
    inputs: 'widget tree',
    outputs: 'laid-out render tree',
    example:
        'RenderClipRRect 300×120 @ (46.5, 366); RenderBackdropFilter needs '
        'compositing, up to the root',
    handoff: 'dirty repaint boundaries go to flushPaint',
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
  ),
  StackTier(
    number: 3,
    band: 'ui',
    title: 'Paint calls',
    stage: 'Paint: four tapes record, nothing is drawn',
    inputs: 'laid-out render tree',
    outputs: 'pictures ①–④',
    example: '④ drawRRect(2×19, r=2, #007AFF): the caret',
    handoff: 'each picture goes into a PictureLayer',
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
  ),
  StackTier(
    number: 4,
    band: 'ui',
    title: 'Layer tree',
    stage: 'Layers: the tapes drop into folders',
    inputs: 'pictures ①–④',
    outputs: 'layer tree',
    example: 'BackdropFilterLayer(blur 10) holds ② and the text field',
    handoff: 'walked by a SceneBuilder',
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
  ),
  StackTier(
    number: 5,
    band: 'handoff',
    title: 'Scene handoff',
    stage: 'Scene: the builder describes the tree',
    inputs: 'layer tree',
    outputs: 'one Scene',
    example: '26 SceneBuilder calls on a caret fade step, 7 on a hold tick',
    handoff: 'FlutterView.render() → a pipeline slot → the raster thread',
    where: 'UI builds it · the frame pipeline carries it',
    token: 'Scene',
    detail: TrayDetail(slots: 2, label: 'frame pipeline · 2 slots'),
  ),
  StackTier(
    number: 6,
    band: 'raster',
    title: 'One DisplayList',
    stage: 'Raster: the folders melt into one tape',
    inputs: 'one Scene',
    outputs: 'one frame DisplayList',
    example: 'SaveLayer(backdrop blur σ = 30 px)  [estimate]',
    handoff: 'Impeller canvas dispatch',
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
  ),
  StackTier(
    number: 7,
    band: 'raster',
    title: 'Impeller passes',
    stage: 'Impeller: the tape becomes render passes',
    inputs: 'one frame DisplayList',
    outputs: '~6 command buffers',
    example:
        'P1 offscreen, 3× Gaussian blur, P5 MSAA backdrop, P6 subpass; '
        '~12 draw calls  [estimate]',
    handoff: 'committed to the GPU queue',
    where: 'raster thread encodes · GPU executes after commit',
    token: 'Pass',
    detail: PassesDetail([
      StackPass('P1', 'offscreen · clear'),
      StackPass('P2', 'blur ↓', drawCalls: 1, hot: true),
      StackPass('P3', 'blur ↕', drawCalls: 1, hot: true),
      StackPass('P4', 'blur ↔', drawCalls: 1, hot: true),
      StackPass('P5', 'MSAA backdrop', drawCalls: 3, hot: true),
      StackPass('P6', 'subpass', drawCalls: 6),
    ]),
  ),
  StackTier(
    number: 8,
    band: 'gpu',
    title: 'GPU execution',
    stage: 'GPU: tiles fill on-chip',
    inputs: '~6 command buffers',
    outputs: 'resolved drawable',
    example: 'T0 ≈ 12 MB stored and read back at the pass break  [estimate]',
    handoff: 'present',
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
    stage: 'Pixels: the phone shows the frosted card',
    inputs: 'resolved drawable',
    outputs: 'the frame on screen',
    example: '1179×2556; on ≈111 of ≈119 caret frames/s no pixel changes',
    handoff: 'the render server composites it → display',
    where: 'FlutterMetalLayer · 3 drawables',
    token: 'Pixel',
    detail: ScreenDetail(),
  ),
];

Map<int, double> _lit(Iterable<int> tiers, double light) => {
  for (final tier in tiers) tier: light,
};

Set<int> _upTo(int tier) => {for (var n = 1; n <= tier; n++) n};

StackTier _tier(int number) =>
    renderStackTiers.firstWhere((tier) => tier.number == number);

/// Stage [number] as its own flat slide.
RenderStackStep _stageSlide(int number, {String? caption}) => RenderStackStep(
  RenderStackView(focus: number),
  caption:
      caption ??
      'What happens to the ${_tier(number).inputs} now? '
          '${_tier(number).stage}.',
);

/// Stage [number]'s slide landing on the stack as its plane.
RenderStackStep _landing(
  int number, {
  Set<StackBorder> borders = const {},
  String? caption,
}) => RenderStackStep(
  RenderStackView(focus: number, landed: true, borders: borders),
  caption:
      caption ??
      'Layer $number: ${_tier(number).outputs}, and next, '
          '${_tier(number).handoff}.',
);

/// Cold open (agenda § 0): only the code slide.
final coldOpenScript = [
  _stageSlide(1, caption: 'You all write this.'),
];

/// Hook (agenda § 1): the demo on a phone and the vote. No stack yet.
const hookScript = [
  RenderStackStep(
    RenderStackView(
      visibleTiers: {},
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

/// Pipeline, UI half (agenda § 2a): the code lands as plane 1, then stages
/// 2-5, each as its own slide that lands on the stack.
final uiHalfScript = [
  _stageSlide(1, caption: 'Your code again. What happens to it now?'),
  _landing(
    1,
    caption:
        'It becomes the first layer. Its output, a widget tree, is the next '
        "stage's input.",
  ),
  for (final number in [2, 3, 4]) ...[
    _stageSlide(number),
    _landing(number),
  ],
  _stageSlide(5),
  _landing(5, borders: {StackBorder.thread}),
];

/// Pipeline, raster half (agenda § 2b): stages 6-9, then frames in flight
/// (spec section 6) and the four-band zoom-out.
final rasterHalfScript = [
  _stageSlide(6),
  _landing(6),
  _stageSlide(7),
  _landing(
    7,
    borders: {StackBorder.gpu},
    caption:
        'Layer 7: command buffers, committed to the GPU queue. This is where '
        'work crosses from CPU to GPU.',
  ),
  _stageSlide(8),
  _landing(8),
  RenderStackStep(
    RenderStackView(
      visibleTiers: _upTo(8),
      light: const {6: TierLight.dim, 7: TierLight.dim, 8: TierLight.hot},
      feedback: true,
    ),
    caption:
        'Two signals come back down. When the GPU falls behind, the raster '
        'thread waits for a drawable, and DevTools counts it as raster time.',
  ),
  _stageSlide(9),
  _landing(9, borders: {StackBorder.present}),
  const RenderStackStep(
    RenderStackView(frames: FramesInFlight()),
    caption:
        'One frame runs in order, but frames overlap: N+1 on the UI thread '
        'while N rasterizes and N−1 runs on the GPU.',
  ),
  const RenderStackStep(
    RenderStackView(frames: FramesInFlight(animated: true)),
    caption:
        'Every vsync, each frame moves up one stage. Two Scenes can wait in '
        "the queue; three drawables rotate. On Metal, N's first passes start "
        'on the GPU while later ones encode.',
  ),
  const RenderStackStep(
    RenderStackView(frames: FramesInFlight(limits: true)),
    caption:
        "What doesn't overlap: one UI thread, one raster thread, and passes "
        'that wait on each other. The price of pipelining is latency.',
  ),
  const RenderStackStep(
    RenderStackView(showBands: true),
    caption:
        'Zoomed out: your code, the UI thread, the handoff, the raster '
        'thread, and the GPU and display.',
  ),
];

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

/// Aha (agenda § 3): a running Ticker means a full frame every vsync; the
/// RepaintBoundary myth; #192128.
final ahaScript = [
  const RenderStackStep(
    RenderStackView(arcs: [_rebuild, _repaint, _tickerFrame]),
    caption:
        'Loops run from where work starts up to the top. A rebuild starts at '
        'your code, a repaint at paint. A ticker frame starts at the vsync.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [_tickerFrameRunning, _caretRepaint],
      light: tickerFrameLight,
    ),
    caption:
        'A running Ticker means a full frame every vsync: about 119 a second, '
        '111 of them with nothing repainted. Scene, raster and GPU run anyway.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [_tickerFrameRunning],
      light: tickerFrameLight,
    ),
    caption:
        "RepaintBoundary can't help: nothing is repainting. The Ticker still "
        'asks for a frame every vsync, and layers 5 to 9 stay hot.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [
        LoopArc(
          id: 'T',
          label: 'Ticker frame',
          startTier: 1,
          endTier: 4,
          activeFromTier: 5,
          prominent: true,
          origin: 'Ticker · every vsync',
          perSecond: 119,
          rateLabel: '≈111 frames/s: no Scene',
          cutNote: '#192128 · drawFrame gate',
        ),
        _caretRepaint,
      ],
      light: {
        3: .2,
        4: .2,
        5: .2,
        ..._lit([6, 7, 8, 9], .3),
      },
    ),
    caption:
        'With #192128 (master, expected in 3.50), drawFrame skips frames '
        'with nothing repainted: no Scene. ≈119 → ≈7.9 Scenes per second.',
  ),
];

/// Why an everyday blur costs so much (agenda § 4): the GPU tier's tiles.
const blurCostScript = [
  RenderStackStep(
    RenderStackView(light: {8: TierLight.dim}, tiles: TilePhase.fill),
    caption:
        'Mobile GPUs render in on-chip tiles. MSAA color and depth are '
        'memoryless: they never leave the chip.',
  ),
  RenderStackStep(
    RenderStackView(light: {8: TierLight.hot}, tiles: TilePhase.flush),
    caption:
        'The backdrop blur needs pixels already drawn. The pass snaps: the '
        'frame so far is stored to DRAM as T0, then blurred.',
  ),
  RenderStackStep(
    RenderStackView(light: {8: TierLight.hot}, tiles: TilePhase.reseed),
    caption:
        'The resumed pass is re-seeded from DRAM with a full-screen redraw. '
        'Every frame, 120 times a second.',
  ),
];

/// Profiling (agenda § 5): each tool marks the layers it can see.
const profilingScript = [
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Highlight repaints',
        tiers: {3: TierLight.dim},
        shows: 'which boundaries repaint',
      ),
    ),
    caption:
        'Highlight repaints sees the paint layer only: for the caret, almost '
        'nothing, which is why it misleads.',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'DevTools Performance',
        tiers: {1: .5, 2: .5, 3: .5, 4: .5, 5: .5, 6: .3, 7: .3},
        shows: 'UI + raster CPU time',
      ),
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
        shows: 'GPU work every vsync',
      ),
    ),
    caption: 'Instruments Metal System Trace shows GPU work every vsync.',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Metal frame capture',
        tiers: {7: .5, 8: .5},
        shows: 'passes, draws: structure',
      ),
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
        shows: 'power + thermal state',
      ),
    ),
    caption: 'Power Profiler shows what it costs in power and heat.',
  ),
];
