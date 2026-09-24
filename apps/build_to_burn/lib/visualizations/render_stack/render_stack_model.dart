import 'package:flutter/foundation.dart';

/// Which processor does a plane's work.
enum StackSide { cpu, gpu }

/// One level of the render stack, drawn as an isometric plane.
@immutable
class StackPlane {
  const StackPlane({
    required this.id,
    required this.title,
    required this.side,
    this.subtitle = '',
    this.inputs = '',
    this.outputs = '',
    this.items = const [],
  });

  /// A stable key that views refer to, e.g. `'layers'`.
  final String id;

  final String title;

  /// A short technical label, e.g. the thread it runs on.
  final String subtitle;

  final StackSide side;

  /// What the plane consumes, shown while inputs and outputs are visible.
  final String inputs;

  /// What the plane produces.
  final String outputs;

  /// Contents drawn on the plane while it is open, e.g. the render objects.
  final List<String> items;
}

/// Tone for highlights and pulses.
enum StackTone {
  /// The accent color: normal work.
  work,

  /// The heat color: the expensive part.
  hot,
}

/// A pulse that travels up the stack from [from] to [to] and repeats, to show
/// which planes rerun, e.g. on every repaint or every frame.
@immutable
class LoopPulse {
  const LoopPulse({
    required this.from,
    required this.to,
    required this.label,
    this.period = const Duration(milliseconds: 1400),
    this.tone = StackTone.work,
  });

  /// Plane ids, bottom and top of the loop.
  final String from;
  final String to;

  final String label;
  final Duration period;
  final StackTone tone;

  @override
  bool operator ==(Object other) =>
      other is LoopPulse &&
      other.from == from &&
      other.to == to &&
      other.label == label &&
      other.period == period &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(from, to, label, period, tone);
}

/// Two frames in flight: frame N+1 is being prepared on some planes while
/// frame N is still being drawn on others.
@immutable
class PipelineView {
  const PipelineView({required this.current, required this.next});

  /// Planes busy with frame N.
  final Set<String> current;

  /// Planes busy with frame N+1.
  final Set<String> next;

  @override
  bool operator ==(Object other) =>
      other is PipelineView &&
      setEquals(other.current, current) &&
      setEquals(other.next, next);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(current),
    Object.hashAllUnordered(next),
  );
}

/// Everything `RenderStack` shows at one moment. Changing the view animates
/// from the previous one.
@immutable
class RenderStackView {
  const RenderStackView({
    this.visible = const {},
    this.open = const {},
    this.highlighted = const {},
    this.hot = const {},
    this.spread = 1,
    this.showBorder = false,
    this.showInputsOutputs = false,
    this.pulses = const [],
    this.pipeline,
  });

  /// Planes that are built up so far.
  final Set<String> visible;

  /// Planes that show their [StackPlane.items].
  final Set<String> open;

  /// Planes drawn in the accent color.
  final Set<String> highlighted;

  /// Planes drawn in the heat color. Wins over [highlighted].
  final Set<String> hot;

  /// 0 stacks the planes tightly, 1 explodes them.
  final double spread;

  /// Whether to draw the CPU/GPU border.
  final bool showBorder;

  /// Whether each plane's label shows its inputs and outputs.
  final bool showInputsOutputs;

  final List<LoopPulse> pulses;

  /// When set, a second stack shows frame N+1 next to frame N.
  final PipelineView? pipeline;

  RenderStackView copyWith({
    Set<String>? visible,
    Set<String>? open,
    Set<String>? highlighted,
    Set<String>? hot,
    double? spread,
    bool? showBorder,
    bool? showInputsOutputs,
    List<LoopPulse>? pulses,
    PipelineView? pipeline,
    bool clearPipeline = false,
  }) => RenderStackView(
    visible: visible ?? this.visible,
    open: open ?? this.open,
    highlighted: highlighted ?? this.highlighted,
    hot: hot ?? this.hot,
    spread: spread ?? this.spread,
    showBorder: showBorder ?? this.showBorder,
    showInputsOutputs: showInputsOutputs ?? this.showInputsOutputs,
    pulses: pulses ?? this.pulses,
    pipeline: clearPipeline ? null : pipeline ?? this.pipeline,
  );

  @override
  bool operator ==(Object other) =>
      other is RenderStackView &&
      setEquals(other.visible, visible) &&
      setEquals(other.open, open) &&
      setEquals(other.highlighted, highlighted) &&
      setEquals(other.hot, hot) &&
      other.spread == spread &&
      other.showBorder == showBorder &&
      other.showInputsOutputs == showInputsOutputs &&
      listEquals(other.pulses, pulses) &&
      other.pipeline == pipeline;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(visible),
    Object.hashAllUnordered(open),
    Object.hashAllUnordered(highlighted),
    Object.hashAllUnordered(hot),
    spread,
    showBorder,
    showInputsOutputs,
    Object.hashAll(pulses),
    pipeline,
  );
}

/// One deck step: a view and what to say about it.
@immutable
class RenderStackStep {
  const RenderStackStep(this.view, {this.caption = ''});

  final RenderStackView view;
  final String caption;
}
