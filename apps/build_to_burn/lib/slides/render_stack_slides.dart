import 'package:build_to_burn/slides/render_stack_slide.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart' show FlutterDeckTransition;

// The slides that show the render stack: one per build-up step of
// docs/render-stack-visualization.md that has shipped. Consecutive stack
// slides are chained: each animates from the previous slide's last view
// (forward) or the next slide's first view (backward), with the deck's own
// transition off so the morph runs seamlessly across slides.

RenderStackSlide _stackSlide(
  String route,
  String title,
  List<RenderStackStep> script, {
  required String speakerNotes,
  RenderStackView? entry,
  RenderStackView? backEntry,
}) => RenderStackSlide(
  route: route,
  title: title,
  script: script,
  entry: entry,
  backEntry: backEntry,
  transition: const FlutterDeckTransition.none(),
  speakerNotes: speakerNotes,
);

final coldOpenSlide = RenderStackSlide(
  route: '/cold-open',
  title: 'Cold open',
  script: coldOpenScript,
  backEntry: hookScript.last.view,
  speakerNotes: timSlideNotesHeader,
);

final hookSlide = RenderStackSlide(
  route: '/hook',
  title: 'Hook',
  script: hookScript,
  entry: coldOpenScript.last.view,
  backEntry: docsStep.view,
  transition: const FlutterDeckTransition.none(),
  speakerNotes: jesperSlideNotesHeader,
);

// § 2a, UI half: one slide per stage. Moving on from a stage lands it on the
// stack while the next stage's slide comes in.

final stage2Slide = _stackSlide(
  '/stage-2',
  layerHeading(2),
  // The docs' trees come up as a dialog over the hook, close back onto the
  // code, and then the code lands on the stack.
  [docsStep, codeStep, stage2Step],
  entry: hookScript.last.view,
  backEntry: paintSourceStep.view,
  speakerNotes: timSlideNotesHeader,
);

// The paint() signatures people know, before the demo's paint calls.
final paintSourceSlide = _stackSlide(
  '/paint-source',
  layerHeading(3, 'Inside paint()'),
  [paintSourceStep],
  entry: stage2Step.view,
  backEntry: stage3Step.view,
  speakerNotes: timSlideNotesHeader,
);

final stage3Slide = _stackSlide(
  '/stage-3',
  layerHeading(3),
  [stage3Step],
  entry: paintSourceStep.view,
  backEntry: stage4Step.view,
  speakerNotes: timSlideNotesHeader,
);

final stage4Slide = _stackSlide(
  '/stage-4',
  layerHeading(4),
  [stage4Step],
  entry: stage3Step.view,
  backEntry: stage5Step.view,
  speakerNotes: timSlideNotesHeader,
);

final stage5Slide = _stackSlide(
  '/stage-5',
  layerHeading(5),
  [stage5Step],
  entry: stage4Step.view,
  backEntry: stage6Step.view,
  speakerNotes: timSlideNotesHeader,
);

// § 2b, raster half.

final stage6Slide = _stackSlide(
  '/stage-6',
  layerHeading(6),
  [stage6Step],
  entry: stage5Step.view,
  backEntry: stage7Step.view,
  speakerNotes: jesperSlideNotesHeader,
);

final stage7Slide = _stackSlide(
  '/stage-7',
  layerHeading(7),
  [stage7Step],
  entry: stage6Step.view,
  backEntry: stage8Step.view,
  speakerNotes: jesperSlideNotesHeader,
);

final stage8Slide = _stackSlide(
  '/stage-8',
  layerHeading(8),
  [stage8Step],
  entry: stage7Step.view,
  backEntry: stage9Step.view,
  speakerNotes: jesperSlideNotesHeader,
);

final stage9Slide = _stackSlide(
  '/stage-9',
  layerHeading(9),
  [stage9Step],
  entry: stage8Step.view,
  backEntry: framesStep.view,
  speakerNotes: jesperSlideNotesHeader,
);

final framesSlide = _stackSlide(
  '/frames-in-flight',
  'Frames in flight',
  [framesStep],
  entry: stage9Step.view,
  backEntry: limitsStep.view,
  speakerNotes: jesperSlideNotesHeader,
);

final limitsSlide = _stackSlide(
  '/flight-limits',
  'Pipeline limits',
  [limitsStep],
  entry: framesStep.view,
  backEntry: bandsStep.view,
  speakerNotes: jesperSlideNotesHeader,
);

final bandsSlide = _stackSlide(
  '/stack-bands',
  'Zoom out',
  [bandsStep],
  entry: limitsStep.view,
  backEntry: ahaScript.first.view,
  speakerNotes: jesperSlideNotesHeader,
);

final ahaSlide = RenderStackSlide(
  route: '/paint-vs-composite',
  title: 'Paint vs composite',
  script: ahaScript,
  entry: bandsStep.view,
  backEntry: blurCostScript.first.view,
  transition: const FlutterDeckTransition.none(),
  speakerNotes: timSlideNotesHeader,
);

final blurCostSlide = RenderStackSlide(
  route: '/blur-cost',
  title: 'Why blur costs',
  script: blurCostScript,
  entry: ahaScript.last.view,
  backEntry: profilingScript.first.view,
  transition: const FlutterDeckTransition.none(),
  speakerNotes: jesperSlideNotesHeader,
);

final profilingSlide = RenderStackSlide(
  route: '/profiling',
  title: 'Profiling',
  script: profilingScript,
  entry: blurCostScript.last.view,
  transition: const FlutterDeckTransition.none(),
  speakerNotes: timSlideNotesHeader,
);
