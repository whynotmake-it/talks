import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';

// Content from docs/render-stack-visualization.md (the spec): section 2 for
// the tiers, section 7.1 for the stage slides and their handoffs, section 6
// for frames in flight. Example values are for its demo tree (a frosted card
// with a focused CupertinoTextField over a blue page) on an iPhone 15 Pro,
// Flutter 3.47.5, --profile, Impeller Metal. Tiers 1-4 are [measured] (see
// internal/demo-tree-dumps.md); 5-8 are [estimate]/pending a Metal capture.
// Keep [verify]/[estimate] values off final slides until they're ticked.

const renderStackBands = [
  StackBand(id: 'code', title: 'Your code'),
  StackBand(id: 'ui', title: 'UI thread', subtitle: 'platform main thread'),
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
    title: 'Layer tree → Scene',
    stage: 'The layer tree, copied into the engine as one Scene.',
    inputs: 'pictures + layers',
    outputs: 'one Scene',
    example: '26 SceneBuilder calls on a caret fade step, 7 on a hold tick',
    handoff: 'FlutterView.render() → a pipeline slot → the raster thread',
    where: 'UI thread',
    token: 'Scene',
    detail: EngineStageDetail(EngineStage.scene, 3, [
      'Scene · in C++',
      '  TransformLayer',
      '    ClipRRectLayer',
      '      BackdropFilterLayer',
      '→ raster thread',
    ]),
  ),
  StackTier(
    number: 5,
    band: 'raster',
    title: 'One DisplayList',
    stage: 'The raster thread flattens the Scene into one DisplayList.',
    inputs: 'one Scene',
    outputs: 'one DisplayList',
    example: 'SaveLayer(backdrop blur σ = 30 px)  [estimate]',
    handoff: 'Impeller canvas dispatch',
    where: 'raster thread · preroll + paint',
    token: 'DisplayList',
    detail: EngineStageDetail(EngineStage.displayList, 3, [
      'draw picture ①',
      'save · clipRRect',
      '  saveLayer · backdrop blur',
      '    draw picture ② ③ ④',
      '  restore',
      'restore',
    ]),
  ),
  StackTier(
    number: 6,
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
    detail: EngineStageDetail(EngineStage.passes, 3, [
      'Pass · behind the blur',
      'Blur · 3 passes',
      'New pass · blurred copy, the rest',
    ]),
  ),
  StackTier(
    number: 7,
    band: 'gpu',
    title: 'GPU execution',
    stage: 'The GPU fills tiles on-chip.',
    inputs: 'command buffers',
    outputs: 'finished drawable',
    example: 'T0 ≈ 24 MB stored and read back at the pass break  [estimate]',
    handoff: 'present',
    where: 'GPU · tile memory + DRAM',
    token: 'Tile',
    detail: ChipsDetail([
      'tiles stay on-chip',
      'T0 · ~24 MB to DRAM',
    ]),
  ),
  StackTier(
    number: 8,
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

/// Each layer's slide title: what that stage's slide shows.
const layerTitles = {
  1: 'Your widget code',
  2: 'Render objects',
  3: 'Paint calls',
  4: 'Layer tree',
  5: 'One DisplayList',
  6: 'Render passes',
  7: 'GPU tiles',
  8: 'Pixels on screen',
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
    caption: 'An example from the ClickUp app',
  ),
];

/// The demo on its phone, with the hook's vote.
const _hookVote = HookPhone(
  question: 'What keeps the GPU busy?',
  options: [
    'A  The blur',
    'B  The circles underneath',
    'C  The fading cursor',
    'D  The keyboard',
    'E  The rounded clip',
  ],
);

/// The quiz's answer: the blur and the cursor, together.
const _hookAnswer = HookPhone(
  question: 'What keeps the GPU busy?',
  options: [
    'A  The blur',
    'B  The circles underneath',
    'C  The fading cursor',
    'D  The keyboard',
    'E  The rounded clip',
  ],
  answers: {0, 2},
);

/// After the demo: the hook's vote again, then its answer.
const quizAnswerScript = [
  RenderStackStep(
    RenderStackView(focus: 1, phone: _hookVote),
    caption: 'The quiz',
  ),
  RenderStackStep(
    RenderStackView(focus: 1, phone: _hookAnswer),
    caption: 'Both, together',
  ),
];

/// Hook (agenda § 1): Xcode's energy report of the demo, then the demo's code
/// on the left and the demo on a phone with the vote on the right. No stack
/// yet.
const hookScript = [
  // Xcode's energy report of the demo on a phone, over everything.
  RenderStackStep(
    RenderStackView(focus: 1, phone: HookPhone(), energyReport: true),
    caption: 'A search sheet pinned the GPU.',
  ),
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

/// The paint calls next to the layer tree they build, before that tree
/// moves on to its own slide.
const stage3PreviewStep = RenderStackStep(
  RenderStackView(focus: 3, treePreview: TreePreview.right),
  caption: '3: Paint calls',
);

/// An engine stage's slide, one step per beat of its `EngineStageView`.
List<RenderStackStep> _engineScript(
  int number,
  EngineStage stage,
  int beats, {
  Set<StackBorder> borders = const {},
  List<String>? captions,
  Map<int, TreePreview> treePreview = const {},
}) {
  final lines = (renderStackTiers[number - 1].detail! as LinesDetail).lines;
  return [
    for (var beat = 0; beat < beats; beat++)
      RenderStackStep(
        RenderStackView(
          focus: number,
          borders: borders,
          treePreview: treePreview[beat],
          focusDetail: EngineStageDetail(stage, beat, lines),
        ),
        caption: captions?[beat] ?? layerHeading(number),
      ),
  ];
}

// Starts as the layer tree, in Dart only; the SceneBuilder turns it into
// the Scene.
final stage4Script = _engineScript(
  4,
  EngineStage.scene,
  4,
  captions: [
    layerHeading(4),
    layerHeading(4),
    layerHeading(4, 'One Scene'),
    layerHeading(4, 'One Scene'),
  ],
  // Arrives as the preview from the paint calls slide, moved left.
  treePreview: {0: TreePreview.left},
);

// Plane 4 lands across the thread border. Ends on the written, flat list.
final stage5Script = _engineScript(
  5,
  EngineStage.displayList,
  2,
  borders: {StackBorder.thread},
);
// The finished plan in one step: the GPU slide before it told the story.
final stage6Script = [
  RenderStackStep(
    RenderStackView(focus: 6, focusDetail: renderStackTiers[5].detail),
    caption: layerHeading(6),
  ),
];

final stage4Step = stage4Script.last;
final stage5Step = stage5Script.last;

const framesStep = RenderStackStep(
  RenderStackView(frames: FramesInFlight(animated: true)),
  caption: 'Frames overlap: N+1 builds while N rasters and N−1 draws.',
);

const limitsStep = RenderStackStep(
  RenderStackView(frames: FramesInFlight(limits: true)),
  caption: 'One UI thread, one raster thread, two slots.',
);

/// Lighting for a ticker frame (spec section 5): tiers 1-3 off (nothing is
/// dirty), 4 dim (the Scene is still sent), 5-8 hot.
final tickerFrameLight = {
  4: TierLight.dim,
  ..._lit([5, 6, 7, 8], TierLight.hot),
};

/// The talk's aha: a running Ticker requests a frame every vsync, and every
/// frame runs Scene, raster and GPU, whether or not anything repainted.
const _tickerFrameRunning = LoopArc(
  id: 'T',
  label: 'Ticker',
  startTier: 1,
  activeFromTier: 4,
  prominent: true,
  origin: 'Ticker · every vsync',
  perSecond: 120,
  rateLabel: '120/s',
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

/// Aha (agenda § 3): what we'd expect from a caret that changes 8 times a
/// second, then what its Ticker really does: a full frame every vsync.
final ahaScript = [
  // First what we'd expect: the caret changes 8 times a second.
  RenderStackStep(
    RenderStackView(
      arcs: const [_caretRepaint],
      light: _lit([3, 4, 5, 6, 7, 8], TierLight.dim),
    ),
    caption: 'Expected: 8 new frames a second',
  ),
  RenderStackStep(
    RenderStackView(
      arcs: const [_tickerFrameRunning, _caretRepaint],
      light: tickerFrameLight,
    ),
    caption: 'Reality: 120 frames a second',
  ),
];

/// Profiling (agenda § 5): each tool marks the layers it can see, next to
/// our own capture of it running on the demo.
const profilingScript = [
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Highlight repaints',
        tiers: {3: TierLight.dim},
        shows: 'which boundaries repaint',
        // A clip, so the caret's ~8 repaints a second can be seen.
        image: 'assets/images/tools/highlight_repaints.mp4',
      ),
    ),
    caption: 'Highlight repaints',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'DevTools Performance',
        tiers: {1: .5, 2: .5, 3: .5, 4: .5, 5: .3, 6: .3},
        shows: 'UI + raster CPU time',
        image: 'assets/images/tools/devtools_performance.png',
      ),
    ),
    caption: 'DevTools Performance',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Metal System Trace',
        tiers: {5: .5, 6: .5, 7: .5},
        shows: 'GPU work every vsync',
        image: 'assets/images/tools/metal_system_trace.png',
      ),
    ),
    caption: 'Metal System Trace',
  ),
  RenderStackStep(
    RenderStackView(
      spotlight: ToolSpotlight(
        tool: 'Energy Impact',
        tiers: {7: .5, 8: .5},
        shows: 'what it all costs',
        image: 'assets/images/tools/energy_impact.png',
      ),
    ),
    caption: 'Energy Impact',
  ),
];
