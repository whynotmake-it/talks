import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

/// The render stack: widget code at the bottom, pixels at the top, each
/// level an isometric plane, drawn for [view].
///
/// Changing [view] animates every plane, label, border, pulse and the
/// pipeline from where they are. Drive it from deck steps with a list of
/// [RenderStackStep]s, e.g. [renderStackIntro]. The widget scales to its box,
/// keeping [designSize]'s aspect ratio.
class RenderStack extends StatefulWidget {
  const RenderStack({
    required this.view,
    this.planes = renderStackPlanes,
    this.caption,
    super.key,
  });

  final RenderStackView view;

  /// The planes, bottom to top.
  final List<StackPlane> planes;

  /// Shown at the bottom left, if set.
  final String? caption;

  static const designSize = Size(1600, 900);

  @override
  State<RenderStack> createState() => _RenderStackState();
}

class _PlaneTracks {
  _PlaneTracks(String id)
    : presence = Track(.single, initial: 0, debugLabel: '$id presence'),
      open = Track(.single, initial: 0, debugLabel: '$id open'),
      highlight = Track(.single, initial: 0, debugLabel: '$id highlight'),
      hot = Track(.single, initial: 0, debugLabel: '$id hot');

  final Track<double> presence;
  final Track<double> open;
  final Track<double> highlight;
  final Track<double> hot;
}

class _RenderStackState extends State<RenderStack> {
  final _planeTracks = <String, _PlaneTracks>{};
  final _spread = Track<double>(.single, initial: 1, debugLabel: 'Spread');
  final _border = Track<double>(.single, initial: 0, debugLabel: 'Border');
  final _io = Track<double>(.single, initial: 0, debugLabel: 'Inputs/outputs');
  final _pipeline = Track<double>(.single, initial: 0, debugLabel: 'Pipeline');

  /// The last pipeline shown, kept so the second stack can fade out.
  PipelineView? _lastPipeline;

  static const _motion = Motion.smoothSpring();

  _PlaneTracks _tracksOf(String id) =>
      _planeTracks.putIfAbsent(id, () => _PlaneTracks(id));

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    _lastPipeline = view.pipeline ?? _lastPipeline;
    final pipeline = view.pipeline;

    return FittedBox(
      child: SizedBox.fromSize(
        size: RenderStack.designSize,
        child: TrackBuilder(
          debugLabel: 'Render stack',
          animations: [
            for (final plane in widget.planes) ...[
              _tracksOf(plane.id).presence.to(
                view.visible.contains(plane.id) ? 1 : 0,
                motion: _motion,
              ),
              _tracksOf(plane.id).open.to(
                view.open.contains(plane.id) ? 1 : 0,
                motion: _motion,
              ),
              _tracksOf(plane.id).highlight.to(
                (pipeline?.current ?? view.highlighted).contains(plane.id)
                    ? 1
                    : 0,
                motion: _motion,
              ),
              _tracksOf(plane.id).hot.to(
                _isHot(plane, view) ? 1 : 0,
                motion: _motion,
              ),
            ],
            _spread.to(view.spread, motion: _motion),
            _border.to(view.showBorder ? 1 : 0, motion: _motion),
            _io.to(view.showInputsOutputs ? 1 : 0, motion: _motion),
            _pipeline.to(pipeline == null ? 0 : 1, motion: _motion),
          ],
          builder: (context, value, _) => _StackPicture(
            planes: widget.planes,
            planeValues: {
              for (final plane in widget.planes)
                plane.id: _PlaneValues(
                  presence: value(_tracksOf(plane.id).presence),
                  open: value(_tracksOf(plane.id).open),
                  highlight: value(_tracksOf(plane.id).highlight),
                  hot: value(_tracksOf(plane.id).hot),
                ),
            },
            spread: value(_spread),
            border: value(_border),
            io: value(_io),
            pipeline: value(_pipeline),
            lastPipeline: _lastPipeline,
            pulses: view.pulses,
            caption: widget.caption,
          ),
        ),
      ),
    );
  }

  /// In a pipeline, frame N's GPU planes are the hot ones.
  static bool _isHot(StackPlane plane, RenderStackView view) {
    if (view.pipeline case final pipeline?) {
      return pipeline.current.contains(plane.id) && plane.side == StackSide.gpu;
    }
    return view.hot.contains(plane.id);
  }
}

@immutable
class _PlaneValues {
  const _PlaneValues({
    required this.presence,
    required this.open,
    required this.highlight,
    required this.hot,
  });

  final double presence;
  final double open;
  final double highlight;
  final double hot;
}

// Geometry, in design pixels.
const _planeSize = 250.0;
const _cos30 = 0.8660254;
const _halfWidth = _planeSize * _cos30;
const _bottomY = 600.0;
const _collapsedGap = 30.0;
const _explodedGap = 86.0;
const _labelsLeft = 1130.0;
const _labelSlot = 108.0;
const _labelsBottom = 790.0;

/// Maps a flat square onto an isometric rhombus with its top vertex at the
/// origin.
final _isometric = Matrix4(
  _cos30,
  .5,
  0,
  0, //
  -_cos30,
  .5,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1,
);

class _StackPicture extends StatelessWidget {
  const _StackPicture({
    required this.planes,
    required this.planeValues,
    required this.spread,
    required this.border,
    required this.io,
    required this.pipeline,
    required this.lastPipeline,
    required this.pulses,
    required this.caption,
  });

  final List<StackPlane> planes;
  final Map<String, _PlaneValues> planeValues;
  final double spread;
  final double border;
  final double io;
  final double pipeline;
  final PipelineView? lastPipeline;
  final List<LoopPulse> pulses;
  final String? caption;

  double get _gap =>
      lerpDouble(_collapsedGap, _explodedGap, spread.clamp(0, 1.2))!;

  /// Top vertex y of plane [index], before its entrance offset.
  double _planeY(int index) => _bottomY - index * _gap;

  double _labelY(int index) => _labelsBottom - index * _labelSlot;

  int _indexOf(String id) => planes.indexWhere((plane) => plane.id == id);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = pipeline.clamp(0.0, 1.0);
    final mainX = lerpDouble(600, 840, t)!;
    final ghostX = lerpDouble(600, 330, t)!;
    final borderIndex = planes.indexWhere(
      (plane) => plane.side == StackSide.gpu,
    );

    return DefaultTextStyle(
      style: archivo(22, color: p.textSecondary),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (lastPipeline case final ghost? when t > .01)
            ..._stack(
              p,
              centerX: ghostX,
              opacity: t,
              values: (plane) => _PlaneValues(
                presence: planeValues[plane.id]!.presence,
                open: 0,
                highlight: ghost.next.contains(plane.id) ? 1 : 0,
                hot: 0,
              ),
            ),
          if (borderIndex > 0) ..._border(p, borderIndex),
          ..._stack(
            p,
            centerX: mainX,
            opacity: 1,
            values: (plane) => planeValues[plane.id]!,
          ),
          for (final (index, plane) in planes.indexed)
            ..._label(p, index, plane, mainX),
          for (final pulse in pulses)
            if (_indexOf(pulse.from) >= 0 && _indexOf(pulse.to) >= 0)
              _PulseOverlay(
                key: ValueKey(pulse),
                pulse: pulse,
                centerX: mainX,
                fromY: _planeY(_indexOf(pulse.from)),
                toY: _planeY(_indexOf(pulse.to)),
              ),
          if (t > .01) ...[
            _frameLabel(p, 'Frame N', mainX, t),
            _frameLabel(p, 'Frame N+1', ghostX, t),
          ],
          if (caption case final caption?)
            Positioned(
              left: 40,
              bottom: 24,
              width: 1040,
              child: Text(
                caption,
                style: archivo(30, height: 1.3, color: p.text),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _stack(
    Palette p, {
    required double centerX,
    required double opacity,
    required _PlaneValues Function(StackPlane plane) values,
  }) => [
    for (final (index, plane) in planes.indexed)
      if (values(plane).presence > .005)
        _plane(p, index, plane, values(plane), centerX, opacity),
  ];

  Widget _plane(
    Palette p,
    int index,
    StackPlane plane,
    _PlaneValues v,
    double centerX,
    double opacity,
  ) {
    final presence = v.presence.clamp(0.0, 1.0);
    final y = _planeY(index) - (1 - presence) * 60;
    final highlight = v.highlight.clamp(0.0, 1.0);
    final hot = v.hot.clamp(0.0, 1.0);
    final open = v.open.clamp(0.0, 1.0);

    var edge = Color.lerp(p.borderStrong, p.accent, highlight)!;
    edge = Color.lerp(edge, heat, hot)!;
    var fill = Color.lerp(p.surface, p.accentSoft, highlight)!;
    fill = Color.lerp(fill, Color.lerp(p.surface, heat, .12), hot)!;

    return Positioned(
      left: centerX,
      top: y,
      child: Opacity(
        opacity: presence * opacity,
        child: Transform(
          transform: _isometric,
          child: SizedBox.square(
            dimension: _planeSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill.withValues(alpha: .94),
                border: Border.all(
                  color: edge,
                  width: lerpDouble(2, 4, math.max(highlight, hot))!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.text.withValues(alpha: .08),
                    offset: const Offset(10, 10),
                  ),
                ],
              ),
              child: Opacity(
                opacity: open,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in plane.items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: p.inset,
                          child: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mono(17, weight: 500, color: edge),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _label(Palette p, int index, StackPlane plane, double centerX) {
    final v = planeValues[plane.id]!;
    final presence = v.presence.clamp(0.0, 1.0);
    if (presence < .005) return const [];
    final anchor = Offset(
      centerX + _halfWidth,
      _planeY(index) - (1 - presence) * 60 + _planeSize / 2,
    );
    final labelY = _labelY(index);
    final accent = Color.lerp(
      Color.lerp(p.text, p.accent, v.highlight.clamp(0, 1)),
      heat,
      v.hot.clamp(0, 1),
    )!;
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _LeaderPainter(
              from: anchor,
              to: Offset(_labelsLeft - 16, labelY + 18),
              color: p.borderStrong.withValues(alpha: presence),
            ),
          ),
        ),
      ),
      Positioned(
        left: _labelsLeft,
        top: labelY,
        width: 1600 - _labelsLeft - 30,
        child: Opacity(
          opacity: presence,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plane.title,
                style: archivo(28, weight: 500, color: accent),
              ),
              Text(
                plane.subtitle.toUpperCase(),
                style: mono(15, color: p.textTertiary),
              ),
              if (io > .01)
                Opacity(
                  opacity: io.clamp(0, 1),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'in  ${plane.inputs}  →  out  ${plane.outputs}',
                      style: mono(16, color: p.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _border(Palette p, int borderIndex) {
    final opacity = border.clamp(0.0, 1.0);
    if (opacity < .01) return const [];
    final y =
        (_planeY(borderIndex) + _planeY(borderIndex - 1)) / 2 + _planeSize / 2;
    final labelsY = (_labelY(borderIndex) + _labelY(borderIndex - 1)) / 2 + 40;
    return [
      Positioned(
        left: 40,
        width: _labelsLeft - 80,
        top: y,
        height: 2,
        child: Opacity(
          opacity: opacity,
          child: const _Dashes(color: heat),
        ),
      ),
      Positioned(
        left: _labelsLeft,
        right: 30,
        top: labelsY,
        height: 2,
        child: Opacity(
          opacity: opacity,
          child: const _Dashes(color: heat),
        ),
      ),
      Positioned(
        left: 40,
        top: y - 34,
        child: Opacity(
          opacity: opacity,
          child: Text('GPU ↑', style: mono(20, weight: 600, color: heat)),
        ),
      ),
      Positioned(
        left: 40,
        top: y + 12,
        child: Opacity(
          opacity: opacity,
          child: Text(
            'CPU ↓',
            style: mono(20, weight: 600, color: p.textSecondary),
          ),
        ),
      ),
    ];
  }

  Widget _frameLabel(Palette p, String text, double centerX, double t) =>
      Positioned(
        left: centerX - 100,
        width: 200,
        top: _planeY(planes.length - 1) - 56,
        child: Opacity(
          opacity: t,
          child: Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: mono(20, weight: 600, color: p.text),
          ),
        ),
      );
}

/// A plane-shaped outline that travels from [fromY] to [toY] and repeats.
class _PulseOverlay extends StatefulWidget {
  const _PulseOverlay({
    required this.pulse,
    required this.centerX,
    required this.fromY,
    required this.toY,
    super.key,
  });

  final LoopPulse pulse;
  final double centerX;
  final double fromY;
  final double toY;

  @override
  State<_PulseOverlay> createState() => _PulseOverlayState();
}

class _PulseOverlayState extends State<_PulseOverlay> {
  final _progress = Track<double>(.single, initial: 0, debugLabel: 'Pulse');

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = widget.pulse.tone == StackTone.hot ? heat : p.accent;
    final bracketX = widget.centerX - _halfWidth - 70;
    final top = widget.toY + _planeSize / 2;
    final bottom = widget.fromY + _planeSize / 2;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TrackBuilder(
              debugLabel: 'Loop pulse: ${widget.pulse.label}',
              loop: .loop,
              animations: [
                _progress([
                  const .to(0, motion: .linear(Duration(milliseconds: 1))),
                  .to(1, motion: .linear(widget.pulse.period)),
                ]),
              ],
              builder: (context, value, _) {
                final t = value(_progress).clamp(0.0, 1.0);
                final y = lerpDouble(widget.fromY, widget.toY, t)!;
                return CustomPaint(
                  size: RenderStack.designSize,
                  painter: _RhombusPainter(
                    top: Offset(widget.centerX, y),
                    color: color.withValues(alpha: math.sin(math.pi * t)),
                  ),
                );
              },
            ),
            Positioned(
              left: bracketX,
              top: top,
              width: 3,
              height: math.max(bottom - top, 0),
              child: ColoredBox(color: color),
            ),
            Positioned(
              left: bracketX - 190,
              width: 180,
              top: (top + bottom) / 2 - 16,
              child: Text(
                '↻ ${widget.pulse.label}',
                textAlign: TextAlign.right,
                style: mono(20, weight: 600, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RhombusPainter extends CustomPainter {
  _RhombusPainter({required this.top, required this.color});

  final Offset top;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + _halfWidth, top.dy + _planeSize / 2)
      ..lineTo(top.dx, top.dy + _planeSize)
      ..lineTo(top.dx - _halfWidth, top.dy + _planeSize / 2)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = color.withValues(alpha: color.a * .15))
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
  }

  @override
  bool shouldRepaint(_RhombusPainter oldDelegate) =>
      top != oldDelegate.top || color != oldDelegate.color;
}

class _LeaderPainter extends CustomPainter {
  _LeaderPainter({required this.from, required this.to, required this.color});

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final elbow = Offset(to.dx - 40, to.dy);
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(to.dx, to.dy),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_LeaderPainter oldDelegate) =>
      from != oldDelegate.from ||
      to != oldDelegate.to ||
      color != oldDelegate.color;
}

class _Dashes extends StatelessWidget {
  const _Dashes({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashPainter(color),
    size: Size.infinite,
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 10, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => color != oldDelegate.color;
}
