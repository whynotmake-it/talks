import 'package:flutter/foundation.dart';

/// A group of tiers drawn close together, e.g. everything on the UI thread.
@immutable
class StackBand {
  const StackBand({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.connector = false,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Drawn as a thin tray between its neighbors instead of a full band, like
  /// the Scene handoff.
  final bool connector;
}

/// What an expanded tier shows on its plane.
sealed class TierDetail {
  const TierDetail();
}

/// Labelled chips, e.g. render objects.
class ChipsDetail extends TierDetail {
  const ChipsDetail(this.items);
  final List<String> items;
}

/// Lines of a recording or tree, drawn in a monospaced font.
class LinesDetail extends TierDetail {
  const LinesDetail(this.lines);
  final List<String> lines;
}

/// A queue with a fixed number of slots, like the frame pipeline.
class TrayDetail extends TierDetail {
  const TrayDetail({required this.slots, required this.label});
  final int slots;
  final String label;
}

/// One render pass in [PassesDetail].
@immutable
class StackPass {
  const StackPass(
    this.name,
    this.label, {
    this.drawCalls = 0,
    this.hot = false,
  });
  final String name;
  final String label;
  final int drawCalls;
  final bool hot;
}

/// A strip of render passes with draw-call ticks.
class PassesDetail extends TierDetail {
  const PassesDetail(this.passes);
  final List<StackPass> passes;
}

/// Source code, shown as a code slide.
class CodeDetail extends TierDetail {
  const CodeDetail(this.code);
  final String code;
}

/// The demo screen itself: the pixels.
class ScreenDetail extends TierDetail {
  const ScreenDetail();
}

/// One level of the render stack, drawn as an isometric plane.
@immutable
class StackTier {
  const StackTier({
    required this.number,
    required this.band,
    required this.title,
    required this.inputs,
    required this.outputs,
    required this.token,
    this.stage = '',
    this.example = '',
    this.handoff = '',
    this.where = '',
    this.detail,
    this.note = '',
  });

  /// 1 (widget code) to 9 (pixels).
  final int number;

  /// The [StackBand.id] it belongs to.
  final String band;

  final String title;
  final String inputs;
  final String outputs;

  /// The thread or place it runs, e.g. `UI thread`.
  final String where;

  /// A short name for this tier's output, e.g. `Picture`.
  final String token;

  /// The stage slide's title: what happens here, e.g. `Layout: boxes snap to
  /// sizes`.
  final String stage;

  /// One example value from the demo tree, shown with the output.
  final String example;

  /// What happens to the output next: the handoff to the next stage.
  final String handoff;

  /// What the plane shows when expanded.
  final TierDetail? detail;

  /// A key fact shown next to the expanded tier.
  final String note;
}

/// How brightly a tier is lit: [off], [dim] (ran, small) or [hot] (ran over
/// the full screen). Values in between are fine.
abstract final class TierLight {
  static const off = 0.0;
  static const dim = .5;
  static const hot = 1.0;
}

/// The borders the stack can draw.
enum StackBorder {
  /// Thin, between the handoff and the raster thread: same CPU, another
  /// thread.
  thread,

  /// Bold, through the Impeller tier at command-buffer commit.
  gpu,

  /// Thin, between GPU execution and pixels: the frame leaves Flutter.
  present,
}

/// A loop drawn as an arc on the left of the stack, from [startTier] up to
/// [endTier], pulsing at [perSecond].
@immutable
class LoopArc {
  const LoopArc({
    required this.id,
    required this.label,
    required this.startTier,
    this.endTier = 9,
    this.perSecond = 0,
    this.rateLabel,
    this.cutNote = '',
    this.prominent = false,
    this.activeFromTier,
    this.origin = '',
  });

  /// The loop's letter from the spec, e.g. `C`.
  final String id;

  final String label;
  final int startTier;
  final int endTier;

  /// Real frequency. 0 draws the arc without pulses.
  final double perSecond;

  /// Overrides the rate shown next to the arc, e.g. `≈8/s`.
  final String? rateLabel;

  /// Draws the arc bold, as the loop the slide is about. Others stay thin.
  final bool prominent;

  /// The arc runs dim below this tier (the tiers a frame passes through
  /// without work) and full above it.
  final int? activeFromTier;

  /// What starts the loop, shown under it, e.g. `Ticker · every vsync`.
  final String origin;

  /// Shown where the arc is cut short, e.g. `#192128`.
  final String cutNote;

  @override
  bool operator ==(Object other) =>
      other is LoopArc &&
      other.id == id &&
      other.label == label &&
      other.startTier == startTier &&
      other.endTier == endTier &&
      other.perSecond == perSecond &&
      other.rateLabel == rateLabel &&
      other.cutNote == cutNote &&
      other.prominent == prominent &&
      other.activeFromTier == activeFromTier &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    startTier,
    endTier,
    perSecond,
    rateLabel,
    cutNote,
    prominent,
    activeFromTier,
    origin,
  );
}

/// A profiling tool as a light cone on the tiers it can see.
@immutable
class ToolSpotlight {
  const ToolSpotlight({
    required this.tool,
    required this.tiers,
    required this.shows,
  });

  final String tool;

  /// Lit tiers and how brightly (see [TierLight]).
  final Map<int, double> tiers;

  final String shows;

  @override
  bool operator ==(Object other) =>
      other is ToolSpotlight &&
      other.tool == tool &&
      mapEquals(other.tiers, tiers) &&
      other.shows == shows;

  @override
  int get hashCode => Object.hash(tool, shows, Object.hashAll(tiers.keys));
}

/// The hook: the demo on a phone in front of the dimmed stack, with a vote.
@immutable
class HookPhone {
  const HookPhone({required this.question, required this.options});

  final String question;

  /// The vote's answers, e.g. `A  The blur`.
  final List<String> options;

  @override
  bool operator ==(Object other) =>
      other is HookPhone &&
      other.question == question &&
      listEquals(other.options, options);

  @override
  int get hashCode => Object.hash(question, Object.hashAll(options));
}

/// What the GPU tier's tile memory is doing, for why a blur costs.
enum TilePhase {
  /// Tiles render on-chip; memoryless attachments never reach DRAM.
  fill,

  /// The backdrop ends the pass: the frame so far is stored to DRAM (T0).
  flush,

  /// The resumed pass is re-seeded from DRAM with a full-screen redraw.
  reseed,
}

/// Several frames in flight at once, on the finished stack: frame N+1 on the
/// UI thread while N is on the raster thread, N-1 executes on the GPU and N-2
/// is on screen.
@immutable
class FramesInFlight {
  const FramesInFlight({this.animated = false, this.limits = false});

  /// Whether the frames advance one stage per (slowed) vsync.
  final bool animated;

  /// Whether to stamp what does not overlap (one UI thread, one raster
  /// thread, dependent passes) and name the helper threads that do.
  final bool limits;

  @override
  bool operator ==(Object other) =>
      other is FramesInFlight &&
      other.animated == animated &&
      other.limits == limits;

  @override
  int get hashCode => Object.hash(animated, limits);
}

/// Everything `RenderStack` shows at one moment. Changing the view animates
/// from the previous one.
@immutable
class RenderStackView {
  const RenderStackView({
    this.bands = allBands,
    this.visibleTiers,
    this.focus,
    this.landed = false,
    this.expanded = const {},
    this.light = const {},
    this.emphasis = const {},
    this.borders = const {},
    this.showPixels = true,
    this.arcs = const [],
    this.arcSlowdown = 10,
    this.spotlight,
    this.phone,
    this.tiles,
    this.feedback = false,
    this.frames,
    this.showBands = false,
  });

  /// Sentinel for "every band".
  static const allBands = {'*'};

  /// Visible bands, rising in stack order. [allBands] shows all.
  final Set<String> bands;

  /// When set, only these tiers are on the stack (overrides [bands]).
  final Set<int>? visibleTiers;

  /// The tier shown as its own flat slide, with its input and output. With
  /// [landed] it flies onto the stack as its plane.
  final int? focus;

  /// Whether the [focus] slide has landed on the stack.
  final bool landed;

  /// Tier numbers that show their [StackTier.detail].
  final Set<int> expanded;

  /// Tier lighting, see [TierLight]. Missing tiers are off.
  final Map<int, double> light;

  /// Detail items to emphasize, matched by substring, e.g. `'④'`.
  final Set<String> emphasis;

  final Set<StackBorder> borders;

  /// Whether the pixels tier shows the demo screen.
  final bool showPixels;

  final List<LoopArc> arcs;

  /// How much slower than real time the arcs pulse.
  final double arcSlowdown;

  final ToolSpotlight? spotlight;

  /// When set, the stack dims and the hook's phone comes forward.
  final HookPhone? phone;

  /// When set, the GPU tier shows its tile memory in this phase.
  final TilePhase? tiles;

  /// Whether to draw the back-pressure and completion arrows that cross the
  /// CPU/GPU border downward.
  final bool feedback;

  /// When set, several frames are in flight on the finished stack.
  final FramesInFlight? frames;

  /// Whether to group the list into the four bands: the zoom-out summary.
  final bool showBands;

  bool showsBand(String id) => bands.contains('*') || bands.contains(id);

  /// Whether [tier] (in [band]) is on the stack.
  bool showsTier(int tier, String band) {
    if (focus case final focus?) {
      return tier < focus || (tier == focus && landed);
    }
    if (visibleTiers case final tiers?) return tiers.contains(tier);
    return showsBand(band);
  }

  @override
  bool operator ==(Object other) =>
      other is RenderStackView &&
      setEquals(other.bands, bands) &&
      setEquals(other.visibleTiers, visibleTiers) &&
      other.focus == focus &&
      other.landed == landed &&
      setEquals(other.expanded, expanded) &&
      mapEquals(other.light, light) &&
      setEquals(other.emphasis, emphasis) &&
      setEquals(other.borders, borders) &&
      other.showPixels == showPixels &&
      listEquals(other.arcs, arcs) &&
      other.arcSlowdown == arcSlowdown &&
      other.spotlight == spotlight &&
      other.phone == phone &&
      other.tiles == tiles &&
      other.feedback == feedback &&
      other.frames == frames &&
      other.showBands == showBands;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(bands),
    Object.hash(
      visibleTiers == null ? null : Object.hashAllUnordered(visibleTiers!),
      focus,
      landed,
      frames,
      showBands,
    ),
    Object.hashAllUnordered(expanded),
    Object.hashAllUnordered(
      light.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(emphasis),
    Object.hashAllUnordered(borders),
    showPixels,
    Object.hashAll(arcs),
    arcSlowdown,
    spotlight,
    phone,
    tiles,
    feedback,
  );
}

/// One deck step: a view and what to say about it.
@immutable
class RenderStackStep {
  const RenderStackStep(this.view, {this.caption = ''});

  final RenderStackView view;
  final String caption;
}
