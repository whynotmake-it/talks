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
  speakerNotes: timSlideNotesHeader,
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
  speakerNotes: jesperSlideNotesHeader,
);

// The paint() signatures people know, before the demo's paint calls.
final paintSourceSlide = _stackSlide(
  '/paint-source',
  layerHeading(3, 'Inside paint()'),
  [paintSourceStep],
  entry: stage2Step.view,
  backEntry: stage3Step.view,
  speakerNotes: jesperSlideNotesHeader,
);

final stage3Slide = _stackSlide(
  '/stage-3',
  layerHeading(3),
  [stage3Step, stage3PreviewStep],
  entry: paintSourceStep.view,
  backEntry: stage4Script.first.view,
  speakerNotes: jesperSlideNotesHeader,
);

// The layer tree, then a Scene.
final stage4Slide = _stackSlide(
  '/stage-4',
  layerHeading(4),
  stage4Script,
  entry: stage3PreviewStep.view,
  backEntry: stage5Script.first.view,
  speakerNotes: timSlideNotesHeader,
);

// § 2b, raster half.

final stage5Slide = _stackSlide(
  '/stage-5',
  layerHeading(5),
  stage5Script,
  entry: stage4Step.view,
  backEntry: stage6Script.first.view,
  speakerNotes: timSlideNotesHeader,
);

final stage6Slide = _stackSlide(
  '/stage-6',
  layerHeading(6),
  stage6Script,
  entry: stage5Step.view,
  backEntry: ahaScript.first.view,
  speakerNotes: timSlideNotesHeader,
);

final framesSlide = _stackSlide(
  '/frames-in-flight',
  'Frames in flight',
  [framesStep],
  backEntry: limitsStep.view,
  speakerNotes: jesperSlideNotesHeader,
);

final limitsSlide = _stackSlide(
  '/flight-limits',
  'Pipeline limits',
  [limitsStep],
  entry: framesStep.view,
  speakerNotes: jesperSlideNotesHeader,
);

// After the demo: the hook's vote, answered.
final quizAnswerSlide = RenderStackSlide(
  route: '/quiz-answer',
  title: 'Quiz answer',
  script: quizAnswerScript,
  speakerNotes: jesperSlideNotesHeader,
);

final ahaSlide = RenderStackSlide(
  route: '/paint-vs-composite',
  title: 'Paint vs composite',
  script: ahaScript,
  speakerNotes: timSlideNotesHeader,
);

final profilingSlide = RenderStackSlide(
  route: '/profiling',
  title: 'Profiling',
  script: profilingScript,
  transition: const FlutterDeckTransition.none(),
  speakerNotes: timSlideNotesHeader,
);
