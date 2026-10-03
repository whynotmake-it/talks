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

/// The demo's widget tree, for stage 2's split view beside the render tree:
/// each chip is the color of the render objects its widget creates.
const demoWidgetTree = WidgetNode(
  'Stack',
  widget: DemoWidget.stack,
  children: [
    WidgetNode(
      'Positioned.fill',
      widget: DemoWidget.positioned,
      note: 'no render object',
      children: [WidgetNode('ColoredBox', widget: DemoWidget.coloredBox)],
    ),
    WidgetNode(
      'Center',
      widget: DemoWidget.center,
      children: [
        WidgetNode(
          'ClipRRect',
          widget: DemoWidget.clipRRect,
          children: [
            WidgetNode(
              'BackdropFilter',
              widget: DemoWidget.backdropFilter,
              children: [
                WidgetNode(
                  'Container',
                  widget: DemoWidget.container,
                  children: [
                    WidgetNode(
                      'CupertinoTextField',
                      widget: DemoWidget.textField,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

const renderStackTiers = [
  StackTier(
    number: 1,
    band: 'code',
    title: 'Widget code',
    stage: 'You all write this.',
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
    stage: 'Widgets create render objects. Layout sizes them.',
    inputs: 'widget tree',
    outputs: 'laid-out render tree',
    example:
        'RenderClipRRect 300×120 @ (46.5, 366); RenderBackdropFilter needs '
        'compositing, up to the root',
    handoff: 'dirty repaint boundaries go to flushPaint',
    where: 'UI thread · layout',
    token: 'RenderObject',
    detail: RenderTreeDetail(
      RenderNode(
        'RenderStack',
        widget: DemoWidget.stack,
        size: '393×852',
        children: [
          RenderNode(
            '_RenderColoredBox',
            widget: DemoWidget.coloredBox,
            size: '393×852',
            note: 'sized by Positioned.fill',
          ),
          RenderNode(
            'RenderPositionedBox',
            widget: DemoWidget.center,
            size: '393×852',
            children: [
              RenderNode(
                'RenderClipRRect',
                widget: DemoWidget.clipRRect,
                size: '300×120',
                children: [
                  RenderNode(
                    'RenderBackdropFilter',
                    widget: DemoWidget.backdropFilter,
                    size: '300×120',
                    children: [
                      RenderNode(
                        'RenderConstrainedBox',
                        widget: DemoWidget.container,
                        size: '300×120',
                        children: [
                          RenderNode(
                            '_RenderColoredBox',
                            widget: DemoWidget.container,
                            size: '300×120',
                            children: [
                              RenderNode(
                                'RenderPositionedBox',
                                widget: DemoWidget.container,
                                size: '300×120',
                                children: [
                                  RenderNode(
                                    '22 render objects',
                                    widget: DemoWidget.textField,
                                    count: 22,
                                    note: 'RenderDecoratedBox … RenderEditable',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  ),
  StackTier(
    number: 3,
    band: 'ui',
    title: 'Paint calls',
    stage: 'Paint records pictures and pushes layers.',
    inputs: 'laid-out render tree',
    outputs: 'pictures + layers',
    example:
        'RenderClipRRect pushes a ClipRRectLayer because its child needs '
        'compositing',
    handoff: 'pushLayer adds to the layer tree as paint runs',
    where: 'UI thread · PictureRecorder',
    token: 'Picture',
    detail: PaintDetail(
      [
        PaintOp(
          '_RenderColoredBox',
          'drawRect',
          widget: DemoWidget.coloredBox,
          picture: 1,
        ),
        PaintOp(
          'RenderClipRRect',
          'push',
          widget: DemoWidget.clipRRect,
          pushes: 'ClipRRectLayer',
        ),
        PaintOp(
          'RenderBackdropFilter',
          'push',
          widget: DemoWidget.backdropFilter,
          pushes: 'BackdropFilterLayer',
        ),
        PaintOp(
          '_RenderColoredBox',
          'drawRect',
          widget: DemoWidget.container,
          picture: 2,
        ),
        PaintOp(
          'RenderDecoratedBox',
          'drawRRect',
          widget: DemoWidget.textField,
          picture: 2,
        ),
        PaintOp(
          'RenderRepaintBoundary',
          'push',
          widget: DemoWidget.textField,
          pushes: 'OffsetLayer',
        ),
        PaintOp(
          'RenderEditable',
          'drawParagraph',
          widget: DemoWidget.textField,
          picture: 3,
        ),
        PaintOp(
          '_RenderEditableCustomPaint',
          'drawRRect',
          widget: DemoWidget.textField,
          picture: 4,
          pushes: 'OffsetLayer',
        ),
      ],
    ),
  ),
  StackTier(
    number: 4,
    band: 'ui',
    title: 'Layer tree',
    stage: 'The pushed layers hold the pictures: a layer tree.',
    inputs: 'pictures + layers',
    outputs: 'layer tree',
    example: 'BackdropFilterLayer(blur 10) holds picture ② and the field',
    handoff: 'walked by a SceneBuilder',
    where: 'UI thread',
    token: 'Layer',
    detail: LayerTreeDetail(
      LayerNode(
        'OffsetLayer · route boundary',
        children: [
          LayerNode(
            'Picture ①',
            picture: 1,
            sources: [DemoWidget.coloredBox],
          ),
          LayerNode(
            'ClipRRectLayer · r 24',
            widget: DemoWidget.clipRRect,
            children: [
              LayerNode(
                'BackdropFilterLayer · blur 10',
                widget: DemoWidget.backdropFilter,
                children: [
                  LayerNode(
                    'Picture ②',
                    picture: 2,
                    sources: [DemoWidget.container, DemoWidget.textField],
                  ),
                  LayerNode(
                    'OffsetLayer · field',
                    widget: DemoWidget.textField,
                    children: [
                      LayerNode(
                        'Picture ③',
                        picture: 3,
                        sources: [DemoWidget.textField],
                      ),
                      LayerNode(
                        'OffsetLayer · caret',
                        widget: DemoWidget.textField,
                        children: [
                          LayerNode(
                            'Picture ④',
                            picture: 4,
                            sources: [DemoWidget.textField],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  ),
  StackTier(
    number: 5,
    band: 'handoff',
    title: 'Scene handoff',
    stage: 'A SceneBuilder packs the layers into one Scene.',
    inputs: 'layer tree',
    outputs: 'one Scene',
    example: '26 SceneBuilder calls on a caret fade step, 7 on a hold tick',
    handoff: 'FlutterView.render() → a pipeline slot → the raster thread',
    where: 'UI builds it · the frame pipeline carries it',
    token: 'Scene',
    detail: TrayDetail(
      slots: 2,
      label: 'Frame pipeline · 2 slots',
      slotLabels: ['N · raster', 'N+1 · UI'],
      notes: [
        'SceneBuilder calls cross FFI: the layer tree is built again in C++.',
        'A slot is taken when the UI thread starts a frame,',
        'and freed when the raster thread has finished it.',
        'Two slots: the UI thread builds N+1 while raster draws N.',
      ],
    ),
  ),
  StackTier(
    number: 6,
    band: 'raster',
    title: 'One DisplayList',
    stage: 'The raster thread flattens the Scene into one DisplayList.',
    inputs: 'one Scene',
    outputs: 'one DisplayList',
    example: 'SaveLayer(backdrop blur σ = 30 px)  [estimate]',
    handoff: 'Impeller canvas dispatch',
    where: 'raster thread · preroll + paint',
    token: 'DisplayList',
    detail: LinesDetail([
      'DrawDisplayList 1',
      'ClipRRect',
      'SaveLayer · blur',
      'DrawDisplayList 2 3 4',
      'Restore',
    ]),
  ),
  StackTier(
    number: 7,
    band: 'raster',
    title: 'Impeller passes',
    stage: 'Impeller turns the DisplayList into render passes.',
    inputs: 'one DisplayList',
    outputs: 'command buffers',
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
    stage: 'The GPU fills tiles on-chip.',
    inputs: 'command buffers',
    outputs: 'finished drawable',
    example: 'T0 ≈ 12 MB stored and read back at the pass break  [estimate]',
    handoff: 'present',
    where: 'GPU · tile memory + DRAM',
    token: 'Tile',
    detail: ChipsDetail([
      'tiles stay on-chip',
      'T0 · ~12 MB to DRAM',
    ]),
  ),
  StackTier(
    number: 9,
    band: 'gpu',
    title: 'Pixels',
    stage: 'The frosted card is on screen.',
    inputs: 'finished drawable',
    outputs: 'pixels on screen',
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

/// Each layer's slide title: what that stage's slide shows.
const layerTitles = {
  1: 'Your widget code',
  2: 'Render objects',
  3: 'Paint calls',
  4: 'Layer tree',
  5: 'One Scene',
  6: 'One DisplayList',
  7: 'Render passes',
  8: 'GPU tiles',
  9: 'Pixels on screen',
};

/// The heading of layer [number]'s slide: its number, then its title.
String layerHeading(int number, [String? title]) =>
    '$number: ${title ?? layerTitles[number]}';

/// Stage [number] as its own flat slide. Moving on to the next slide lands
/// it on the stack as its plane.
RenderStackStep _stageSlide(
  int number, {
  String? caption,
  bool widgetColors = false,
  Set<StackBorder> borders = const {},
}) => RenderStackStep(
  RenderStackView(
    focus: number,
    widgetColors: widgetColors,
    borders: borders,
  ),
  caption: caption ?? layerHeading(number),
);

/// Cold open (agenda § 0): the demo's code and what it builds, on a phone.
const coldOpenScript = [
  RenderStackStep(
    RenderStackView(focus: 1, phone: HookPhone()),
    caption: 'You all write this.',
  ),
];

/// The demo on its phone, with the hook's vote.
const _hookVote = HookPhone(
  question: 'What keeps the GPU busy?',
  options: [
    'A  The blur',
    'B  The list underneath',
    'C  The blinking cursor',
    'D  The keyboard',
  ],
);

/// Hook (agenda § 1): the demo's code on the left, the demo on a phone and
/// the vote on the right. No stack yet.
const hookScript = [
  RenderStackStep(
    RenderStackView(
      focus: 1,
      phone: _hookVote,
    ),
    caption: 'A search sheet pinned the GPU. What kept it busy?',
  ),
];

// Pipeline, UI half (agenda § 2a) and raster half (§ 2b): one deck slide per
// stage. Moving on from each stage's slide lands it as its plane while the
// next stage comes in.

/// The official docs' picture of the trees, as a dialog over the hook: the
/// docs stop at the render tree, this talk goes on toward the GPU.
final docsStep = RenderStackStep(
  const RenderStackView(focus: 1, phone: _hookVote, docs: true),
  caption: layerHeading(1),
);

/// The dialog closed, back on the code and its phone, before it lands. The
/// vote is done.
final codeStep = RenderStackStep(
  const RenderStackView(focus: 1, phone: HookPhone()),
  caption: layerHeading(1),
);

// The code gains its widget colors as it lands, matching the render objects.
final stage2Step = _stageSlide(2, widgetColors: true);

/// The paint() signatures you may have written yourself, before the demo's
/// paint calls: render objects paint the way a CustomPainter does.
final paintSourceStep = RenderStackStep(
  const RenderStackView(
    focus: 3,
    focusDetail: SourceDetail([
      SourceExcerpt('', '''
// A render object
void paint(PaintingContext context, Offset offset)

// A CustomPainter
void paint(Canvas canvas, Size size)'''),
    ]),
  ),
  caption: layerHeading(3, 'Inside paint()'),
);

final stage3Step = _stageSlide(3);
final stage4Step = _stageSlide(4);
final stage5Step = _stageSlide(5);

// Plane 5 lands across the thread border.
final stage6Step = _stageSlide(6, borders: {StackBorder.thread});
final stage7Step = _stageSlide(7);

// Plane 7 lands across the GPU border.
final stage8Step = _stageSlide(8, borders: {StackBorder.gpu});

/// GPU back-pressure (spec section 6): the raster thread waits on a busy GPU.
final backpressureStep = RenderStackStep(
  RenderStackView(
    visibleTiers: _upTo(8),
    light: const {6: TierLight.dim, 7: TierLight.dim, 8: TierLight.hot},
    feedback: true,
  ),
  caption: 'When the GPU falls behind, the raster thread waits.',
);

final stage9Step = _stageSlide(9);

const framesStep = RenderStackStep(
  RenderStackView(frames: FramesInFlight(animated: true)),
  caption: 'Frames overlap: N+1 builds while N rasters and N−1 draws.',
);

const limitsStep = RenderStackStep(
  RenderStackView(frames: FramesInFlight(limits: true)),
  caption: 'One UI thread, one raster thread, two slots.',
);

const bandsStep = RenderStackStep(
  RenderStackView(showBands: true),
  caption: 'Zoomed out: five bands, two threads, one GPU.',
);

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
  label: 'Ticker',
  startTier: 1,
  activeFromTier: 5,
  prominent: true,
  origin: 'Ticker · every vsync',
);

const _tickerFrameRunning = LoopArc(
  id: 'T',
  label: 'Ticker',
  startTier: 1,
  activeFromTier: 5,
  prominent: true,
  origin: 'Ticker · every vsync',
  perSecond: 119,
  rateLabel: '119/s',
);

/// Measured for the demo's caret: 8 repainting ticks per 1.017 s blink cycle
/// (internal/demo-tree-dumps.md).
const _caretRepaint = LoopArc(
  id: 'C',
  label: 'Repaint',
  startTier: 3,
  perSecond: 7.9,
  rateLabel: '8/s',
);

/// A custom spinner inside a RepaintBoundary (spec section 4.1): it paints
/// one small picture every tick, so #192128 can't skip its frames.
const _spinner = LoopArc(
  id: 'S',
  label: 'Spinner',
  startTier: 3,
  perSecond: 120,
  prominent: true,
  rateLabel: '120/s',
);

/// Aha (agenda § 3): a running Ticker means a full frame every vsync; the
/// RepaintBoundary myth; #192128 as a partial fix; the spinner it can't cut.
final ahaScript = [
  const RenderStackStep(
    RenderStackView(arcs: [_rebuild, _repaint, _tickerFrame]),
    caption: 'Three loops: rebuild, repaint, and the ticker frame.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [_tickerFrameRunning, _caretRepaint],
      light: tickerFrameLight,
    ),
    caption: 'A running Ticker means a full frame every vsync.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [_tickerFrameRunning],
      light: tickerFrameLight,
    ),
    caption: "RepaintBoundary can't help. Nothing is repainting.",
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [
        LoopArc(
          id: 'T',
          label: 'Ticker',
          startTier: 1,
          endTier: 4,
          activeFromTier: 5,
          prominent: true,
          origin: 'Ticker · every vsync',
          perSecond: 119,
          cutNote: 'skipped',
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
        'Partial fix (expected in 3.50): skip frames that painted nothing.',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [
        LoopArc(
          id: 'T',
          label: 'Ticker',
          startTier: 1,
          endTier: 4,
          activeFromTier: 5,
          origin: 'Ticker · every vsync',
          rateLabel: '',
          cutNote: 'skipped',
        ),
        _spinner,
      ],
      light: {
        3: .25,
        4: .25,
        5: TierLight.dim,
        ..._lit([6, 7, 8, 9], 1),
      },
    ),
    caption: 'A spinner paints every tick. The real fix: stop the Ticker.',
  ),
];

/// Why an everyday blur costs so much (agenda § 4): the GPU tier's tiles.
const blurCostScript = [
  RenderStackStep(
    RenderStackView(light: {8: TierLight.dim}, tiles: TilePhase.fill),
    caption: 'Mobile GPUs draw in on-chip tiles.',
  ),
  RenderStackStep(
    RenderStackView(light: {8: TierLight.hot}, tiles: TilePhase.flush),
    caption: 'The blur needs finished pixels: the pass breaks to DRAM.',
  ),
  RenderStackStep(
    RenderStackView(light: {8: TierLight.hot}, tiles: TilePhase.reseed),
    caption: 'Then a full-screen redraw to resume, 120 times a second.',
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
        'Highlight repaints sees paint only. For the caret: almost nothing.',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'DevTools Performance',
        tiers: {1: .5, 2: .5, 3: .5, 4: .5, 5: .5, 6: .3, 7: .3},
        shows: 'UI + raster CPU time',
      ),
    ),
    caption: "DevTools' raster bar is CPU time, not GPU time.",
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Metal System Trace',
        tiers: {6: .5, 7: .5, 8: .5},
        shows: 'GPU work every vsync',
      ),
    ),
    caption: 'Metal System Trace shows GPU work every vsync.',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Metal frame capture',
        tiers: {7: .5, 8: .5},
        shows: 'passes, draws: structure',
      ),
    ),
    caption: "A Metal frame capture shows one frame's passes and draws.",
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Power Profiler',
        tiers: {8: .5, 9: .5},
        shows: 'power + thermal state',
      ),
    ),
    caption: 'Power Profiler shows the cost in power and heat.',
  ),
];
