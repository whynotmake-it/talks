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

  /// The output chip the traveling frame token shows at this tier.
  final String token;

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
    this.cutNote = '',
  });

  /// The loop's letter from the spec, e.g. `C`.
  final String id;

  final String label;
  final int startTier;
  final int endTier;

  /// Real frequency. 0 draws the arc without pulses.
  final double perSecond;

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
      other.cutNote == cutNote;

  @override
  int get hashCode =>
      Object.hash(id, label, startTier, endTier, perSecond, cutNote);
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

/// Everything `RenderStack` shows at one moment. Changing the view animates
/// from the previous one.
@immutable
class RenderStackView {
  const RenderStackView({
    this.bands = allBands,
    this.expanded = const {},
    this.light = const {},
    this.emphasis = const {},
    this.borders = const {},
    this.token = false,
    this.showPixels = true,
    this.arcs = const [],
    this.arcSlowdown = 10,
    this.spotlight,
  });

  /// Sentinel for "every band".
  static const allBands = {'*'};

  /// Visible bands, rising in stack order. [allBands] shows all.
  final Set<String> bands;

  /// Tier numbers that show their [StackTier.detail].
  final Set<int> expanded;

  /// Tier lighting, see [TierLight]. Missing tiers are off.
  final Map<int, double> light;

  /// Detail items to emphasize, matched by substring, e.g. `'④'`.
  final Set<String> emphasis;

  final Set<StackBorder> borders;

  /// Whether one frame travels up the stack as a token.
  final bool token;

  /// Whether the pixels tier shows the demo screen.
  final bool showPixels;

  final List<LoopArc> arcs;

  /// How much slower than real time the arcs pulse.
  final double arcSlowdown;

  final ToolSpotlight? spotlight;

  bool showsBand(String id) => bands.contains('*') || bands.contains(id);

  @override
  bool operator ==(Object other) =>
      other is RenderStackView &&
      setEquals(other.bands, bands) &&
      setEquals(other.expanded, expanded) &&
      mapEquals(other.light, light) &&
      setEquals(other.emphasis, emphasis) &&
      setEquals(other.borders, borders) &&
      other.token == token &&
      other.showPixels == showPixels &&
      listEquals(other.arcs, arcs) &&
      other.arcSlowdown == arcSlowdown &&
      other.spotlight == spotlight;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(bands),
    Object.hashAllUnordered(expanded),
    Object.hashAllUnordered(
      light.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(emphasis),
    Object.hashAllUnordered(borders),
    token,
    showPixels,
    Object.hashAll(arcs),
    arcSlowdown,
    spotlight,
  );
}

/// One deck step: a view and what to say about it.
@immutable
class RenderStackStep {
  const RenderStackStep(this.view, {this.caption = ''});

  final RenderStackView view;
  final String caption;
}
