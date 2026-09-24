import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

/// The stages of one frame, in the order [FramePipeline] reveals them.
enum FrameStage {
  vsync(
    'Vsync',
    'A ticker asked for a frame, so at the next vsync the engine wakes the UI '
        'thread (the platform main thread on iOS and Android).',
  ),
  buildLayout(
    'Build + layout',
    'Build and layout run on the UI thread. This is the part DevTools and '
        'most performance advice cover.',
  ),
  paint(
    'Paint',
    'Paint records drawing commands into DisplayLists, grouped in layers. '
        'Nothing is drawn yet.',
  ),
  scene(
    'New Scene',
    'The UI thread describes the layer tree as a new Scene and hands it to '
        'the raster thread. This step is cheap.',
  ),
  raster(
    'Raster',
    'The raster thread flattens the whole layer tree into one DisplayList '
        'and encodes GPU commands: all of it, every frame.',
  ),
  gpu(
    'GPU passes',
    'The GPU runs render passes. A BackdropFilter blur ends the pass, runs '
        '3 blur passes, then restarts it with a full-screen redraw.',
  ),
  display(
    'Display',
    'The frame is shown at the next vsync. DevTools times the UI and raster '
        'threads on the CPU. The GPU half stays hidden.',
  );

  const FrameStage(this.label, this.caption);

  /// A short name, e.g. for a stepper.
  final String label;

  /// One or two sentences that explain the stage.
  final String caption;
}

/// One Flutter frame on three lanes (UI thread, raster thread, GPU) over a
/// 120 Hz vsync ruler, revealed stage by stage up to [stage].
///
/// Drive it from deck steps, e.g. `FramePipeline(stage: FrameStage.values[step
/// - 1])`. Going back animates the stages out again. The widget scales to
/// whatever box it gets, keeping its aspect ratio.
///
/// Timings are illustrative, not measured.
class FramePipeline extends StatelessWidget {
  const FramePipeline({this.stage, this.showCaption = true, super.key});

  /// The last visible stage, or null for an empty timeline.
  final FrameStage? stage;

  /// Whether to show the current stage's caption under the lanes.
  final bool showCaption;

  static const designSize = Size(1600, 640);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox.fromSize(
        size: designSize,
        child: PhaseTrackBuilder<int>(
          debugLabel: 'Frame pipeline',
          timeline: _timeline,
          currentPhase: stage == null ? 0 : stage!.index + 1,
          builder: (context, value, phase, child) => _PipelinePicture(
            value: value,
            caption: showCaption ? stage?.caption : null,
          ),
        ),
      ),
    );
  }
}

// Layout of the picture, in design pixels.
const _labelWidth = 300.0;
const _timelineLeft = 320.0;
const _timelineWidth = 1240.0;
const _timelineMs = 20.0;
const _vsyncMs = 1000 / 120;
const _rulerHeight = 64.0;
const _laneTop = 96.0;
const _laneHeight = 96.0;
const _laneGap = 28.0;

double _x(double ms) => _timelineLeft + ms / _timelineMs * _timelineWidth;
double _laneY(int lane) => _laneTop + lane * (_laneHeight + _laneGap);

enum _Lane {
  ui('Platform main thread', 'UI · Dart'),
  raster('Raster thread', 'C++ · CPU'),
  gpu('GPU', 'render passes');

  const _Lane(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// A span of work on one lane, revealed at [stage].
class _Block {
  const _Block(
    this.stage,
    this.lane,
    this.from,
    this.to,
    this.label, {
    this.hot = false,
  });

  final FrameStage stage;
  final _Lane lane;
  final double from;
  final double to;
  final String label;

  /// Whether this is the expensive part (drawn in [heat]).
  final bool hot;
}

const _blocks = [
  _Block(FrameStage.buildLayout, _Lane.ui, .3, 1.6, 'Build'),
  _Block(FrameStage.buildLayout, _Lane.ui, 1.6, 2.4, 'Layout'),
  _Block(FrameStage.paint, _Lane.ui, 2.4, 3.5, 'Paint'),
  _Block(FrameStage.scene, _Lane.ui, 3.5, 4.1, 'Scene'),
  _Block(FrameStage.raster, _Lane.raster, 4.4, 7.6, 'Flatten + encode'),
  _Block(FrameStage.gpu, _Lane.gpu, 5.6, 7.2, 'Pass 1'),
  _Block(FrameStage.gpu, _Lane.gpu, 7.2, 10.4, 'Blur × 3', hot: true),
  _Block(FrameStage.gpu, _Lane.gpu, 10.4, 12.2, 'Pass 2'),
];

final _blockTracks = [
  for (final block in _blocks)
    Track<double>(.single, initial: 0, debugLabel: block.label),
];

/// The vsync pulse, the Scene handoff arrow, and the display marker.
final _vsyncPulse = Track<double>(.single, initial: 0, debugLabel: 'Vsync');
final _handoff = Track<double>(.single, initial: 0, debugLabel: 'Handoff');
final _display = Track<double>(.single, initial: 0, debugLabel: 'Display');

const _reveal = Motion.smoothSpring();

final _timeline = TrackPhaseTimeline<int>({
  for (var phase = 0; phase <= FrameStage.values.length; phase++)
    phase: [
      for (final (index, block) in _blocks.indexed)
        _blockTracks[index].to(
          block.stage.index < phase ? 1 : 0,
          motion: _reveal,
        ),
      _vsyncPulse.to(phase >= 1 ? 1 : 0, motion: _reveal),
      _handoff.to(phase > FrameStage.scene.index ? 1 : 0, motion: _reveal),
      _display.to(phase > FrameStage.display.index ? 1 : 0, motion: _reveal),
    ],
});

class _PipelinePicture extends StatelessWidget {
  const _PipelinePicture({required this.value, required this.caption});

  final TrackValueReader value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final display = value(_display).clamp(0.0, 1.0);
    return DefaultTextStyle(
      style: archivo(22, color: p.textSecondary),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._ruler(p),
          for (final lane in _Lane.values) ..._lane(p, lane, display),
          for (final (index, block) in _blocks.indexed)
            _blockWidget(p, block, value(_blockTracks[index])),
          _handoffArrow(p, value(_handoff)),
          _displayMarker(p, display),
          if (caption case final caption?)
            Positioned(
              left: _timelineLeft,
              right: 40,
              top: _laneY(3) + 8,
              child: Text(
                caption,
                style: archivo(30, height: 1.35, color: p.text),
              ),
            ),
          Positioned(
            left: 0,
            top: _laneY(3) + 12,
            width: _labelWidth,
            child: Text(
              'Illustrative timings\n120 Hz · mobile Impeller',
              style: p.caption.copyWith(fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _ruler(Palette p) {
    final pulse = value(_vsyncPulse).clamp(0.0, 1.0);
    return [
      Positioned(
        left: _timelineLeft,
        width: _timelineWidth,
        top: _rulerHeight - 2,
        height: 2,
        child: ColoredBox(color: p.borderStrong),
      ),
      for (var i = 0; i * _vsyncMs <= _timelineMs; i++) ...[
        Positioned(
          left: _x(i * _vsyncMs) - 1,
          top: 24,
          width: 2,
          height: _laneY(3) - 24,
          child: ColoredBox(
            color: i == 0 ? Color.lerp(p.border, p.accent, pulse)! : p.border,
          ),
        ),
        Positioned(
          left: _x(i * _vsyncMs) + 10,
          top: 20,
          child: Text(
            'vsync ${(i * _vsyncMs).toStringAsFixed(1)} ms',
            style: mono(
              18,
              color: i == 0
                  ? Color.lerp(p.textTertiary, p.accent, pulse)
                  : p.textTertiary,
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _lane(Palette p, _Lane lane, double display) {
    final top = _laneY(lane.index);
    final seenByDevTools = lane != _Lane.gpu;
    return [
      Positioned(
        left: 0,
        top: top,
        width: _labelWidth,
        height: _laneHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(lane.title, style: archivo(26, weight: 500, color: p.text)),
            const SizedBox(height: 4),
            Text(
              lane.subtitle.toUpperCase(),
              style: mono(16, color: p.textTertiary),
            ),
          ],
        ),
      ),
      Positioned(
        left: _timelineLeft,
        top: top,
        width: _timelineWidth,
        height: _laneHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.inset,
            border: Border.all(
              color: Color.lerp(
                p.border,
                seenByDevTools ? p.accent : heat,
                display,
              )!,
              width: 2,
            ),
          ),
        ),
      ),
      Positioned(
        right: 40 + 12,
        top: top + (_laneHeight - 40) / 2,
        height: 40,
        child: Opacity(
          opacity: display,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            color: seenByDevTools ? p.accentSoft : heat.withValues(alpha: .12),
            child: Text(
              seenByDevTools ? 'IN DEVTOOLS' : 'HIDDEN FROM DEVTOOLS',
              style: mono(
                16,
                weight: 600,
                color: seenByDevTools ? p.accent : heat,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _blockWidget(Palette p, _Block block, double progress) {
    final t = progress.clamp(0.0, 1.0);
    final width = (_x(block.to) - _x(block.from)) * t;
    final color = block.hot ? heat : p.accent;
    return Positioned(
      left: _x(block.from),
      top: _laneY(block.lane.index) + 14,
      width: width,
      height: _laneHeight - 28,
      child: Opacity(
        opacity: t,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            border: Border.all(color: color, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          child: Text(
            block.label,
            maxLines: 2,
            overflow: TextOverflow.clip,
            style: mono(17, weight: 600, height: 1.1, color: color),
          ),
        ),
      ),
    );
  }

  Widget _handoffArrow(Palette p, double progress) {
    final t = progress.clamp(0.0, 1.0);
    final from = Offset(_x(4.1), _laneY(0) + _laneHeight - 14);
    final to = Offset(_x(4.4), _laneY(1) + 14);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ArrowPainter(
            from: from,
            to: Offset.lerp(from, to, t)!,
            color: p.accent.withValues(alpha: t),
          ),
        ),
      ),
    );
  }

  Widget _displayMarker(Palette p, double display) {
    final x = _x(2 * _vsyncMs);
    return Positioned(
      left: x - 2,
      top: 24,
      width: 4,
      height: _laneY(3) - 24,
      child: Opacity(
        opacity: display,
        child: ColoredBox(color: p.text),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.from, required this.to, required this.color});

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if ((to - from).distance < 1) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final direction = (to - from) / (to - from).distance;
    final normal = Offset(-direction.dy, direction.dx);
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        (to - direction * 14 + normal * 8).dx,
        (to - direction * 14 + normal * 8).dy,
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        (to - direction * 14 - normal * 8).dx,
        (to - direction * 14 - normal * 8).dy,
      );
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      from != oldDelegate.from ||
      to != oldDelegate.to ||
      color != oldDelegate.color;
}
