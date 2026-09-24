part of 'render_stack.dart';

/// The label list: one row per tier, number and title only. The focused
/// stage expands under its label with its input, output and thread. Rows
/// light up with their planes.
class _LabelList extends StatelessWidget {
  const _LabelList({
    required this.tiers,
    required this.bands,
    required this.view,
    required this.values,
    required this.layout,
    required this.rows,
    required this.frames,
    required this.opacity,
  });

  final List<StackTier> tiers;
  final List<StackBand> bands;
  final RenderStackView view;
  final Map<int, _TierValues> values;
  final _Layout layout;
  final _Rows rows;
  final double frames;
  final double opacity;

  int? get _focused => rows.focus;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final origins = {
      for (final arc in view.arcs)
        if (arc.origin.isNotEmpty) arc.origin,
    };
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (index, tier) in tiers.indexed)
                if (values[tier.number]!.presence > .005)
                  ..._row(p, index, tier),
              if (origins.isNotEmpty)
                Positioned(
                  left: _rowsLeft,
                  top: rows.y(0) - 14,
                  child: Text(
                    '⏱  ${origins.first}',
                    style: mono(18, weight: 600, color: p.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _row(Palette p, int index, StackTier tier) {
    final v = values[tier.number]!;
    final y = rows.y(tier.number.toDouble());
    final focused = _focused == tier.number;
    final lit = _lightColors(p, v.light);
    final frameTint = switch (tier.number) {
      <= 5 => p.accent,
      <= 7 => ExampleTheme.roseQuartz,
      _ => heat,
    };
    final background = Color.lerp(
      Color.lerp(
        const Color(0x00000000),
        v.light > TierLight.dim ? heat.withValues(alpha: .14) : p.accentSoft,
        (v.light / TierLight.dim).clamp(0.0, 1.0),
      ),
      frameTint.withValues(alpha: .14),
      frames,
    )!;
    final bar = Color.lerp(
      Color.lerp(const Color(0x00000000), lit.edge, v.light > 0 ? 1 : 0),
      frameTint,
      frames,
    )!;
    return [
      CustomPaint(
        size: RenderStack.designSize,
        painter: _LeaderPainter(
          from: Offset(_centerX + _halfWidth, layout.center(index)),
          to: Offset(_rowsLeft - 18, y),
          color: p.borderStrong.withValues(alpha: .6 * v.presence),
        ),
      ),
      Positioned(
        left: _rowsLeft - 14,
        top: y - 26,
        width: _rowsRight - _rowsLeft + 14,
        child: Opacity(
          opacity: v.presence,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: background,
              border: Border(left: BorderSide(color: bar, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '${tier.number}  ${tier.title}',
                      style: archivo(
                        24,
                        weight: 500,
                        height: 1.2,
                        color: v.light > .01 ? lit.text : p.text,
                      ),
                    ),
                    if (frames > .01 && tier.number == 5)
                      _chip(p, 'queue ▣▢', frames),
                    if (frames > .01 && tier.number == 9)
                      _chip(p, 'drawables ▣▣▢', frames),
                  ],
                ),
                if (focused && rows.extra > 1)
                  SizedBox(
                    height: rows.extra,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        maxHeight: _focusDetails,
                        child: Opacity(
                          opacity: (rows.extra / _focusDetails).clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${tier.inputs} → ${tier.outputs}',
                                maxLines: 2,
                                overflow: TextOverflow.clip,
                                style: archivo(19, height: 1.25, color: p.text),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tier.where,
                                maxLines: 2,
                                overflow: TextOverflow.clip,
                                style: mono(
                                  15,
                                  height: 1.3,
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _chip(Palette p, String text, double opacity) => Opacity(
    opacity: opacity,
    child: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(text, style: mono(14, weight: 600, color: p.textSecondary)),
    ),
  );
}

/// One bracket beside the label list, from row [from] up to row [to].
@immutable
class _Bracket {
  const _Bracket({
    required this.slot,
    required this.from,
    required this.to,
    required this.color,
    required this.label,
    required this.labelRow,
    this.prominent = false,
    this.dimBelow,
    this.perSecond = 0,
    this.cutNote = '',
    this.id,
  });

  final int slot;
  final double from;
  final double to;
  final Color color;
  final String label;
  final double labelRow;
  final bool prominent;
  final double? dimBelow;
  final double perSecond;
  final String cutNote;

  /// Loop id, for pulses and test keys.
  final String? id;
}

/// Everything that marks tiers, drawn beside the label list: loops, borders,
/// tool spotlights, bands, frames in flight and the feedback arrows.
class _Gutter extends StatelessWidget {
  const _Gutter({
    required this.tiers,
    required this.bands,
    required this.view,
    required this.values,
    required this.rows,
    required this.borders,
    required this.feedback,
    required this.frames,
    required this.bandsSummary,
    required this.framesInFlight,
    required this.opacity,
  });

  final List<StackTier> tiers;
  final List<StackBand> bands;
  final RenderStackView view;
  final Map<int, _TierValues> values;
  final _Rows rows;
  final Map<StackBorder, double> borders;
  final double feedback;
  final double frames;
  final double bandsSummary;
  final FramesInFlight? framesInFlight;
  final double opacity;

  List<(_Bracket, double)> _brackets(Palette p) {
    final result = <(_Bracket, double)>[];
    var slot = 0;
    for (final arc in view.arcs) {
      final rate =
          arc.rateLabel ??
          (arc.perSecond == 0
              ? ''
              : '${arc.perSecond % 1 == 0 ? arc.perSecond.toInt() : arc.perSecond}/s');
      final from = arc.origin.isNotEmpty ? 0.0 : arc.startTier.toDouble();
      result.add((
        _Bracket(
          slot: slot++,
          from: from,
          to: arc.endTier.toDouble(),
          color: arc.endTier >= 6 ? heat : p.accent,
          label: [
            '${arc.id} · ${arc.label}',
            if (rate.isNotEmpty) rate,
          ].join('\n'),
          labelRow: from,
          prominent: arc.prominent,
          dimBelow: arc.activeFromTier?.toDouble(),
          perSecond: arc.perSecond,
          cutNote: arc.cutNote,
          id: arc.id,
        ),
        1,
      ));
    }
    final thread = borders[StackBorder.thread]!;
    if (thread > .01) {
      result
        ..add((
          _Bracket(
            slot: slot,
            from: 1,
            to: 5,
            color: p.textSecondary,
            label: 'UI thread',
            labelRow: 3,
          ),
          thread,
        ))
        ..add((
          _Bracket(
            slot: slot,
            from: 5.55,
            to: 7,
            color: p.accent,
            label: 'Raster thread\nsame CPU, 2-slot queue',
            labelRow: 6.3,
          ),
          thread,
        ));
      slot++;
    }
    final gpu = borders[StackBorder.gpu]!;
    if (gpu > .01) {
      result
        ..add((
          _Bracket(
            slot: slot,
            from: 1,
            to: 6.9,
            color: p.textSecondary,
            label: 'CPU encodes',
            labelRow: 4,
          ),
          gpu,
        ))
        ..add((
          _Bracket(
            slot: slot,
            from: 7.1,
            to: 9,
            color: heat,
            label: 'GPU executes ↑\ncommit at layer 7',
            labelRow: 8.2,
          ),
          gpu,
        ));
      slot++;
    }
    final present = borders[StackBorder.present]!;
    if (present > .01) {
      result.add((
        _Bracket(
          slot: slot++,
          from: 9,
          to: 9.5,
          color: p.textSecondary,
          label: 'present → system compositor',
          labelRow: 9.5,
        ),
        present,
      ));
    }
    if (view.spotlight case final spotlight?) {
      final lit = spotlight.tiers.keys.toList()..sort();
      result.add((
        _Bracket(
          slot: slot++,
          from: lit.first.toDouble(),
          to: lit.last.toDouble(),
          color: p.accent,
          label: '${spotlight.tool}\n${spotlight.shows}',
          labelRow: (lit.first + lit.last) / 2,
        ),
        1,
      ));
    }
    if (bandsSummary > .01) {
      for (final band in bands) {
        final numbers = [
          for (final tier in tiers)
            if (tier.band == band.id) tier.number,
        ];
        if (numbers.isEmpty) continue;
        result.add((
          _Bracket(
            slot: slot,
            from: numbers.first - .3,
            to: numbers.last + .3,
            color: band.connector ? p.textTertiary : p.accent,
            label: band.title,
            labelRow: (numbers.first + numbers.last) / 2,
          ),
          bandsSummary,
        ));
      }
      slot++;
    }
    if (frames > .01 && framesInFlight != null) {
      final limits = framesInFlight!.limits;
      for (final (from, to, color, label) in [
        (
          1.0,
          5.0,
          p.accent,
          'frame N+1\n${limits ? 'one UI thread' : 'UI thread'}',
        ),
        (
          6.0,
          7.0,
          ExampleTheme.roseQuartz,
          'frame N\n${limits ? 'one raster thread' : 'raster thread'}',
        ),
        (
          8.0,
          9.0,
          heat,
          'frame N−1\n${limits ? 'dependent passes' : 'GPU + display'}',
        ),
      ]) {
        result.add((
          _Bracket(
            slot: slot,
            from: from - .3,
            to: to + .3,
            color: color,
            label: label,
            labelRow: (from + to) / 2,
          ),
          frames,
        ));
      }
      slot++;
    }
    return result;
  }

  /// Brackets never reach past the highest layer on the stack.
  List<(_Bracket, double)> _clamped(List<(_Bracket, double)> brackets) {
    final visible = [
      for (final tier in tiers)
        if (values[tier.number]!.presence > .5) tier.number,
    ];
    if (visible.isEmpty) return brackets;
    final ceiling = visible.reduce(math.max) + .45;
    return [
      for (final (b, presence) in brackets)
        if (b.from < ceiling)
          (
            _Bracket(
              slot: b.slot,
              from: b.from,
              to: math.min(b.to, ceiling),
              color: b.color,
              label: b.label,
              labelRow: math.min(b.labelRow, math.min(b.to, ceiling) - .1),
              prominent: b.prominent,
              dimBelow: b.dimBelow,
              perSecond: b.perSecond,
              cutNote: b.cutNote,
              id: b.id,
            ),
            presence,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final brackets = _clamped(_brackets(p));
    final slots = brackets.fold<int>(
      feedback > .01 ? 1 : 0,
      (max, entry) => math.max(max, entry.$1.slot + 1),
    );
    final textLeft = _gutterLeft + slots * _slotWidth + 8;
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (bracket, presence) in brackets)
                _BracketView(
                  key: bracket.id == null ? null : ValueKey(bracket.id),
                  rows: rows,
                  bracket: bracket,
                  presence: presence,
                  textLeft: textLeft,
                  slowdown: view.arcSlowdown,
                ),
              if (feedback > .01)
                _FeedbackArrows(
                  rows: rows,
                  presence: feedback,
                  slot: slots - 1,
                  textLeft: textLeft,
                ),
              if (frames > .01 && (framesInFlight?.limits ?? false))
                Positioned(
                  left: _rowsLeft - 14,
                  top: rows.y(0) - 22,
                  width: 1590 - _rowsLeft,
                  child: Opacity(
                    opacity: frames,
                    child: Text(
                      'Also in parallel: image decode (worker + IO threads), '
                      'pipeline compile (workers).',
                      style: mono(14, height: 1.35, color: p.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

double _slotX(int slot) => _gutterLeft + slot * _slotWidth + 6;

class _BracketView extends StatefulWidget {
  const _BracketView({
    required this.rows,
    required this.bracket,
    required this.presence,
    required this.textLeft,
    required this.slowdown,
    super.key,
  });

  final _Rows rows;
  final _Bracket bracket;
  final double presence;
  final double textLeft;
  final double slowdown;

  @override
  State<_BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<_BracketView> {
  final _phase = Track<double>(.single, initial: 0, debugLabel: 'Pulse');

  static const _travel = Duration(milliseconds: 1200);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final b = widget.bracket;
    final x = _slotX(b.slot);
    final width = b.prominent ? 7.0 : 3.0;
    final top = widget.rows.y(b.to);
    final bottom = widget.rows.y(b.from);
    final activeY = b.dimBelow == null
        ? bottom
        : widget.rows
              .y(
                b.dimBelow!,
              )
              .clamp(math.min(top, bottom), math.max(top, bottom))
              .toDouble();
    final interval = b.perSecond > 0
        ? Duration(
            microseconds: (widget.slowdown * 1000000 / b.perSecond).round(),
          )
        : Duration.zero;
    final textWidth = 1596 - widget.textLeft;
    return Positioned.fill(
      child: Opacity(
        opacity: widget.presence.clamp(0.0, 1.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (activeY < bottom)
              Positioned(
                left: x + width / 2 - 1.5,
                top: activeY,
                width: 3,
                height: bottom - activeY,
                child: ColoredBox(
                  key: b.id == null ? null : ValueKey('arc-dim-${b.id}'),
                  color: b.color.withValues(alpha: .3),
                ),
              ),
            Positioned(
              left: x,
              top: top,
              width: width,
              height: math.max(activeY - top, 0),
              child: ColoredBox(
                key: b.id == null ? null : ValueKey('arc-line-${b.id}'),
                color: b.color.withValues(alpha: .75),
              ),
            ),
            for (final y in {top, bottom})
              Positioned(
                left: _rowsRight - 4,
                top: y - 1.5,
                width: x - _rowsRight + 4,
                height: 3,
                child: ColoredBox(color: b.color.withValues(alpha: .5)),
              ),
            if (interval > Duration.zero)
              TrackBuilder(
                debugLabel: 'Loop ${b.id}',
                loop: .loop,
                animations: [
                  _phase([
                    const .to(0, motion: .linear(Duration(milliseconds: 1))),
                    .to(1, motion: .linear(interval)),
                  ]),
                ],
                builder: (context, value, _) => CustomPaint(
                  size: RenderStack.designSize,
                  painter: _PulsePainter(
                    x: x + width / 2,
                    bottom: bottom,
                    top: top,
                    activeY: activeY,
                    phase: value(_phase).clamp(0.0, 1.0),
                    interval: interval,
                    travel: _travel,
                    color: b.color,
                    radius: b.prominent ? 8 : 5,
                  ),
                ),
              ),
            Positioned(
              left: widget.textLeft,
              width: textWidth,
              top: widget.rows.y(b.labelRow) - (b.prominent ? 22 : 16),
              child: Text(
                b.label,
                style: mono(
                  b.prominent ? 17 : 15,
                  weight: b.prominent ? 700 : 600,
                  height: 1.3,
                  color: b.color,
                ),
              ),
            ),
            if (b.cutNote.isNotEmpty)
              Positioned(
                left: widget.textLeft,
                width: textWidth,
                top: top - 40,
                child: Text(
                  '✂ ${b.cutNote}',
                  style: mono(15, weight: 700, color: p.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Back-pressure and completion: two arrows beside the list, from the GPU
/// row down to the raster rows.
class _FeedbackArrows extends StatelessWidget {
  const _FeedbackArrows({
    required this.rows,
    required this.presence,
    required this.slot,
    required this.textLeft,
  });

  final _Rows rows;
  final double presence;
  final int slot;
  final double textLeft;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final x = _slotX(slot) + 4;
    return Positioned.fill(
      child: Opacity(
        opacity: presence,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: RenderStack.designSize,
              painter: _ArrowsPainter([
                (Offset(x, rows.y(8)), Offset(x, rows.y(6)), heat),
                (
                  Offset(x + 12, rows.y(8)),
                  Offset(x + 12, rows.y(7)),
                  p.accent,
                ),
              ]),
            ),
            Positioned(
              left: textLeft + 12,
              width: 1596 - textLeft - 12,
              top: rows.y(6) - 18,
              child: Text(
                'back-pressure\n3 drawables in flight:\nraster waits',
                style: mono(14, weight: 600, height: 1.3, color: heat),
              ),
            ),
            Positioned(
              left: textLeft + 12,
              width: 1596 - textLeft - 12,
              top: rows.y(8) - 30,
              child: Text(
                'completion\nfrees resources',
                style: mono(14, weight: 600, height: 1.3, color: p.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.x,
    required this.bottom,
    required this.top,
    required this.activeY,
    required this.phase,
    required this.interval,
    required this.travel,
    required this.color,
    required this.radius,
  });

  final double x;
  final double bottom;
  final double top;
  final double activeY;
  final double phase;
  final Duration interval;
  final Duration travel;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final ratio = interval.inMicroseconds / travel.inMicroseconds;
    final count = (1 / ratio).ceil() + 1;
    for (var k = 0; k < count; k++) {
      final progress = (phase + k) * ratio;
      if (progress > 1) continue;
      final y = lerpDouble(bottom, top, progress)!;
      final active = y <= activeY + .5;
      canvas.drawCircle(
        Offset(x, y),
        active ? radius : radius * .6,
        Paint()..color = color.withValues(alpha: active ? 1 : .35),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      phase != oldDelegate.phase ||
      bottom != oldDelegate.bottom ||
      top != oldDelegate.top ||
      activeY != oldDelegate.activeY ||
      color != oldDelegate.color;
}

class _ArrowsPainter extends CustomPainter {
  _ArrowsPainter(this.arrows);

  final List<(Offset, Offset, Color)> arrows;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to, color) in arrows) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(from, to, paint)
        ..drawPath(
          Path()
            ..moveTo(to.dx - 10, to.dy - 14)
            ..lineTo(to.dx, to.dy)
            ..lineTo(to.dx + 10, to.dy - 14),
          paint,
        )
        ..drawCircle(from, 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ArrowsPainter oldDelegate) => true;
}
