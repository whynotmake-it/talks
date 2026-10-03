part of 'render_stack.dart';

/// A stage as its own flat slide, which then lands on the stack as its plane.
///
/// Landing, the card snaps to a compact square ([shrink]), then its corners
/// snap one by one onto the live [plane] rhombus's vertices ([flights], see
/// [_quad]). Both contents ride that quad: the detailed stage, drawn at
/// [flat] size, cross-fades into the plane face while it shrinks; the face,
/// drawn at the plane's native size, fades its trace to the landed plane's
/// as the corners arrive. Landed, the face is pixel-identical to the
/// [_TierPlane] that replaces it.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.tier,
    required this.band,
    required this.card,
    required this.shrink,
    required this.flights,
    required this.flat,
    required this.plane,
    required this.translucent,
    required this.expand,
    required this.widgetColors,
    required this.light,
    required this.emphasis,
    required this.pixels,
    required this.tiles,
    required this.tilePhase,
  });

  final StackTier tier;
  final StackBand band;
  final double card;

  /// 0 flat, 1 landed on [plane].
  /// 0 flat, 1 shrunk to the compact square. Springs, so may overshoot.
  final double shrink;

  /// Each corner slot's flight, 0 at the compact square, 1 on the plane:
  /// slot 0 is the first corner to leave. Springs, so may overshoot.
  final List<double> flights;

  /// The rect the card rests in while flat; the detailed content is laid out
  /// at its size.
  final Rect flat;

  /// The plane's rhombus on the slide, as the card's topLeft, topRight,
  /// bottomRight and bottomLeft.
  final List<Offset> plane;

  /// Matches the landed plane's look, see [_TierPlane].
  final bool translucent;
  final double expand;

  /// 0-1: code marks fade in over this.
  final double widgetColors;
  final double light;
  final Set<String> emphasis;
  final double pixels;
  final double tiles;
  final TilePhase? tilePhase;

  /// Smoothstep of [t] between [a] and [b].
  static double _ease(double a, double b, double t) {
    final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  static List<Offset> _corners(Rect rect) => [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ];

  /// A model of the staggered flight, as windows of a 0-1 progress, slot by
  /// slot: only used to judge which order folds least.
  static const _model = [(0.0, .6), (.13, .73), (.27, .87), (.4, 1.0)];

  /// Every order the four corners can leave in.
  static final _orders = [
    for (var a = 0; a < 4; a++)
      for (var b = 0; b < 4; b++)
        for (var c = 0; c < 4; c++)
          for (var d = 0; d < 4; d++)
            if ({a, b, c, d}.length == 4) [a, b, c, d],
  ];

  /// The order each tier's corners last left in, kept so a tie can't flip
  /// it mid-flight.
  static final _chosen = <int, List<int>>{};

  /// The quad when corner `order[k]` has flown [progress] `[k]` of the way
  /// from [start] to [plane].
  List<Offset> _flight(
    List<Offset> start,
    List<int> order,
    List<double> progress,
  ) => [
    for (var i = 0; i < 4; i++)
      Offset.lerp(start[i], plane[i], progress[order.indexOf(i)])!,
  ];

  /// How far from folding the flight in [order] gets: the smallest corner
  /// turn (sine of the angle) over the whole flight. Below 0 it folds.
  double _clearance(List<Offset> start, List<int> order) {
    var worst = 1.0;
    for (var step = 0; step <= 24; step++) {
      final t = step / 24;
      final progress = [for (final (a, b) in _model) _ease(a, b, t)];
      worst = math.min(worst, _turn(_flight(start, order, progress)));
    }
    return worst;
  }

  /// The order that keeps the quad furthest from folding. Which corners must
  /// lead depends on where the plane sits relative to the card: roughly,
  /// the corners facing the plane go first and the trailing ones follow.
  List<int> _order(List<Offset> start) {
    var best = _orders.first;
    var bestClearance = double.negativeInfinity;
    for (final order in _orders) {
      final clearance = _clearance(start, order);
      if (clearance > bestClearance) {
        best = order;
        bestClearance = clearance;
      }
    }
    final kept = _chosen[tier.number];
    if (kept != null && _clearance(start, kept) > bestClearance - .1) {
      return kept;
    }
    return _chosen[tier.number] = best;
  }

  /// The card's quad: all four corners shrink together to the compact
  /// square, then each flies to its plane vertex on its own spring, in the
  /// order that doesn't fold.
  ///
  /// Should even the best order fold (a corner overtaking its neighbour,
  /// which the projective warp can't draw), the frame uses the most stagger
  /// that keeps the quad convex, down to none: the corners in lockstep
  /// always make a parallelogram.
  List<Offset> _quad() {
    final compact = _corners(
      Rect.fromCenter(
        center: flat.center,
        width: _compactSide,
        height: _compactSide,
      ),
    );
    final start = [
      for (final (i, corner) in _corners(flat).indexed)
        Offset.lerp(corner, compact[i], shrink)!,
    ];
    if (flights.every((flight) => flight.abs() < 1e-4)) return start;
    final staggered = _flight(start, _order(compact), flights);
    if (_convex(staggered)) return staggered;
    final together = flights.reduce((a, b) => a + b) / 4;
    List<Offset> at(double stagger) => [
      for (var i = 0; i < 4; i++)
        Offset.lerp(
          Offset.lerp(start[i], plane[i], together),
          staggered[i],
          stagger,
        )!,
    ];
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 8; i++) {
      final mid = (lo + hi) / 2;
      if (_convex(at(mid))) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return at(lo);
  }

  /// The smallest corner turn of [quad], as the sine of its angle: positive
  /// all round when it's convex and wound like the flat card (clockwise on
  /// screen).
  static double _turn(List<Offset> quad) {
    var worst = 1.0;
    for (var i = 0; i < 4; i++) {
      final a = quad[i];
      final b = quad[(i + 1) % 4];
      final c = quad[(i + 2) % 4];
      final lengths = (b - a).distance * (c - b).distance;
      if (lengths < 1e-6) return -1;
      final cross = (b - a).dx * (c - b).dy - (b - a).dy * (c - b).dx;
      worst = math.min(worst, cross / lengths);
    }
    return worst;
  }

  /// Whether [quad] is convex and wound like the flat card, with every
  /// corner's angle kept away from 0° and 180°.
  static bool _convex(List<Offset> quad) => _turn(quad) > .05;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = card.clamp(0.0, 1.0);
    final simplify = shrink.clamp(0.0, 1.0);
    final quad = _quad();
    final arrived = flights.reduce(math.min).clamp(0.0, 1.0);
    final detailedOpacity = c * (1 - simplify);
    final faceOpacity = c * simplify;
    // The face's schematic: full while it flies, then the landed plane's.
    final landedDetail = .3 + .7 * expand;
    final detail = 1 + (landedDetail - 1) * _ease(.3, 1, arrived);
    final content = tier.detail is CodeDetail
        ? _CodeView(
            code: (tier.detail! as CodeDetail).code,
            widgetColors: widgetColors,
          )
        : _StageContent(tier: tier);
    final center = Offset(
      (quad[0].dx + quad[2].dx) / 2,
      (quad[0].dy + quad[2].dy) / 2,
    );
    final entrance = c == 1
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(center.dx, center.dy, 0, 1)
            ..scaleByDouble(
              lerpDouble(.97, 1, c)!,
              lerpDouble(.97, 1, c)!,
              1,
              1,
            )
            ..translateByDouble(-center.dx, -center.dy, 0, 1));
    return Positioned.fill(
      child: IgnorePointer(
        child: Transform(
          transform: entrance,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (detailedOpacity > .003)
                Opacity(
                  opacity: detailedOpacity,
                  child: Transform(
                    transform: _quadMatrix(flat.size, quad),
                    child: SizedBox.fromSize(
                      size: flat.size,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.surface,
                          border: Border.all(color: p.border, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: p.text.withValues(alpha: .08),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: content,
                      ),
                    ),
                  ),
                ),
              if (faceOpacity > .003)
                Opacity(
                  opacity: faceOpacity,
                  child: Transform(
                    transform: _quadMatrix(
                      const Size.square(_plane),
                      quad,
                    ),
                    child: _PlaneFace(
                      tier: tier,
                      band: band,
                      light: light,
                      translucent: translucent,
                      // Opaque while the detailed card fades out over it.
                      fillAlpha: translucent
                          ? null
                          : lerpDouble(1, .95, simplify),
                      emphasis: emphasis,
                      pixels: pixels,
                      tiles: tiles,
                      tilePhase: tilePhase,
                      detailOpacity: detail,
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

/// A plain editor: the code the audience writes every day.
class _CodeView extends StatelessWidget {
  const _CodeView({required this.code, this.widgetColors = 0});

  final String code;

  /// 0-1: widget constructor calls fade in, marked in their [DemoWidget]
  /// color. The marks always take the same space, so the code never moves.
  final double widgetColors;

  static final _tokens = RegExp(
    r"(//.*)|(@\w+)|(\b(?:class|extends|const|return|super|final|required)\b)"
    r"|(0x[0-9A-Fa-f]+|\b\d+\b)|(\b[A-Z]\w*)|([()\[\]{},;:.])",
  );

  /// The `<label>(` occurrences of every [DemoWidget], in code order.
  static List<({int start, int end, DemoWidget widget})> _marks(String code) {
    final marks = <({int start, int end, DemoWidget widget})>[];
    for (final widget in DemoWidget.values) {
      final needle = '${widget.label}(';
      var index = code.indexOf(needle);
      while (index >= 0) {
        marks.add((
          start: index,
          end: index + widget.label.length,
          widget: widget,
        ));
        index = code.indexOf(needle, index + widget.label.length);
      }
    }
    marks.sort((a, b) => a.start.compareTo(b.start));
    return [
      for (var i = 0; i < marks.length; i++)
        if (i == 0 || marks[i].start >= marks[i - 1].end) marks[i],
    ];
  }

  void _appendTokens(
    List<InlineSpan> spans,
    String text,
    Palette p,
  ) {
    var start = 0;
    for (final match in _tokens.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final color = switch (match) {
        _ when match.group(1) != null || match.group(2) != null =>
          p.textSecondary,
        _ when match.group(3) != null => p.accent,
        _ when match.group(4) != null => heat,
        _ when match.group(5) != null => p.text,
        _ => p.textSecondary,
      };
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: color,
            fontWeight: match.group(3) != null ? FontWeight.w600 : null,
          ),
        ),
      );
      start = match.end;
    }
    spans.add(TextSpan(text: text.substring(start)));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final mark in _marks(code)) {
      _appendTokens(spans, code.substring(start, mark.start), p);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _WidgetMark(widget: mark.widget, opacity: widgetColors),
        ),
      );
      start = mark.end;
    }
    _appendTokens(spans, code.substring(start), p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: p.inset,
            border: Border(bottom: BorderSide(color: p.border, width: 2)),
          ),
          child: Row(
            children: [
              for (final _ in [0, 1, 2])
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: p.control,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 14),
              Text('demo.dart', style: mono(28, color: p.textSecondary)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 28, 56, 28),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: Text.rich(
                TextSpan(children: spans),
                style: mono(32, height: 1.38, color: p.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A widget constructor call inside [_CodeView], marked in its [DemoWidget]
/// color: tinted fill and a full-color border, or a dashed neutral outline
/// for a widget that creates no render object.
class _WidgetMark extends StatelessWidget {
  const _WidgetMark({required this.widget, required this.opacity});

  final DemoWidget widget;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = widget.color ?? p.textTertiary;
    final o = opacity.clamp(0.0, 1.0);
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(widget.label, style: mono(32, height: 1.38, color: p.text)),
    );
    if (widget.color == null) {
      return CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: color.withValues(alpha: o),
        ),
        child: label,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .2 * o),
        border: Border.all(color: color.withValues(alpha: o), width: 3),
      ),
      child: label,
    );
  }
}

/// A dashed rectangle outline, e.g. for [DemoWidget.positioned] marks.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    void dash(Offset from, Offset to) {
      final length = (to - from).distance;
      for (var d = 0.0; d < length; d += 12) {
        canvas.drawLine(
          Offset.lerp(from, to, d / length)!,
          Offset.lerp(from, to, math.min(d + 7, length) / length)!,
          paint,
        );
      }
    }

    final rect = Offset.zero & size;
    dash(rect.topLeft, rect.topRight);
    dash(rect.topRight, rect.bottomRight);
    dash(rect.bottomRight, rect.bottomLeft);
    dash(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// A stage slide: just its picture, on an inset panel. The slide's caption
/// names the stage; the list rows and chips carry the handoff.
class _StageContent extends StatelessWidget {
  const _StageContent({required this.tier});

  final StackTier tier;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: _StagePicture(tier: tier),
  );
}

/// The one picture on a stage slide.
class _StagePicture extends StatelessWidget {
  const _StagePicture({required this.tier});

  final StackTier tier;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final picture = switch (tier.detail) {
      ScreenDetail() => SizedBox(
        width: 300,
        height: 300,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: p.text, width: 6),
          ),
          child: const _DemoScreen(),
        ),
      ),
      _ when tier.number == 8 => SizedBox(
        width: 680,
        height: 300,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 240,
              child: CustomPaint(
                painter: _TilePainter(
                  progress: 1,
                  color: p.accent,
                  empty: p.control,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _Detail(
                detail: tier.detail,
                emphasis: const {},
                color: p.accent,
              ),
            ),
          ],
        ),
      ),
      RenderTreeDetail(:final root) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _treeColumn(
            'WIDGETS',
            const _WidgetTreeView(root: demoWidgetTree),
            p,
          ),
          const SizedBox(width: 60),
          _treeColumn('RENDER OBJECTS', _RenderTreeView(root: root), p),
        ],
      ),
      PaintDetail(:final ops, :final notes) => _PaintOpsView(
        ops: ops,
        notes: notes,
      ),
      LayerTreeDetail(:final root) => _LayerTreeView(root: root),
      _ => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: _Detail(
          detail: tier.detail,
          emphasis: const {},
          color: p.accent,
        ),
      ),
    };
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: p.inset,
        border: Border.all(color: p.border, width: 2),
      ),
      child: FittedBox(child: picture),
    );
  }

  Widget _treeColumn(String label, Widget tree, Palette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: mono(28, weight: 700, color: p.textTertiary)),
      const SizedBox(height: 16),
      tree,
    ],
  );
}

/// The readable version of an expanded tier's detail, flat at the bottom
/// left, with a leader line to its plane.
class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.tier,
    required this.emphasis,
    required this.presence,
    required this.anchor,
    required this.color,
  });

  final StackTier tier;
  final Set<String> emphasis;
  final double presence;
  final Offset anchor;
  final Color color;

  static const rect = Rect.fromLTWH(1416, 480, 544, 390);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: presence,
          child: Stack(
            children: [
              CustomPaint(
                size: RenderStack.designSize,
                painter: _LeaderPainter(
                  from: anchor,
                  to: Offset(rect.right + 30, rect.top + 24),
                  color: color,
                ),
              ),
              Positioned(
                left: rect.left,
                width: rect.width,
                bottom: RenderStack.designSize.height - rect.bottom,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${tier.number}  ${tier.title}'.toUpperCase(),
                        style: mono(34, weight: 700, color: color),
                      ),
                      const SizedBox(height: 10),
                      _Detail(
                        detail: tier.detail,
                        emphasis: emphasis,
                        color: color,
                      ),
                    ],
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

class _Detail extends StatelessWidget {
  const _Detail({
    required this.detail,
    required this.emphasis,
    required this.color,
  });

  final TierDetail? detail;
  final Set<String> emphasis;
  final Color color;

  bool _emphasized(String text) => emphasis.any(text.contains);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    TextStyle line(String text) => mono(
      34,
      weight: _emphasized(text) ? 700 : 450,
      height: 1.4,
      color: _emphasized(text) ? heat : p.text,
    );
    return switch (detail) {
      null || ScreenDetail() => const SizedBox.shrink(),
      CodeDetail(:final code) => Text(
        code.split('\n').take(8).join('\n'),
        style: mono(32, height: 1.35, color: p.text),
      ),
      RenderTreeDetail(:final root) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 490, maxHeight: 290),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: _RenderTreeView(root: root),
        ),
      ),
      PaintDetail(:final ops, :final notes) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 490, maxHeight: 290),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: _PaintOpsView(ops: ops, notes: notes),
        ),
      ),
      LayerTreeDetail(:final root) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 490, maxHeight: 290),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: _LayerTreeView(root: root),
        ),
      ),
      ChipsDetail(:final items) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: p.inset,
              child: Text(item, style: line(item).copyWith(height: 1.1)),
            ),
        ],
      ),
      LinesDetail(:final lines) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final text in lines)
            Text(text, maxLines: 1, softWrap: false, style: line(text)),
        ],
      ),
      TrayDetail(:final slots, :final label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: mono(34, color: p.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var slot = 0; slot < slots; slot++)
                Container(
                  width: 128,
                  height: 72,
                  margin: const EdgeInsets.only(right: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: slot == 0 ? p.accentSoft : p.surface,
                    border: Border.all(
                      color: slot == 0 ? color : p.border,
                      width: 2,
                    ),
                  ),
                  child: slot == 0
                      ? Text(
                          'Scene',
                          style: mono(34, weight: 600, color: color),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ),
      PassesDetail(:final passes) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final pass in passes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      pass.name,
                      style: mono(
                        34,
                        weight: 700,
                        color: pass.hot ? heat : p.text,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 460,
                    child: Text(
                      pass.label,
                      maxLines: 1,
                      softWrap: false,
                      style: mono(34, color: pass.hot ? heat : p.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    };
  }
}

/// A node box in the widget color's usage: tinted fill, full-color border,
/// text in the palette's text color.
BoxDecoration _widgetBoxDecoration(Palette p, DemoWidget widget) {
  final color = widget.color ?? p.textTertiary;
  return BoxDecoration(
    color: widget.color?.withValues(alpha: .2),
    border: Border.all(color: color, width: 3),
  );
}

/// A circled picture number, ①-④, drawn rather than font-dependent.
class _PictureBadge extends StatelessWidget {
  const _PictureBadge(
    this.number, {
    this.background,
    this.foreground,
  });

  final int number;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? p.text,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: mono(20, weight: 700, color: foreground ?? p.surface),
      ),
    );
  }
}

/// The demo's render tree as a diagram: a staircase of node boxes colored
/// by the widget that created each render object, with elbow connectors.
class _RenderTreeView extends StatelessWidget {
  const _RenderTreeView({required this.root});

  final RenderNode root;

  static const _indent = 52.0;
  static const _elbow = 26.0;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rows = <(RenderNode, int, List<bool>)>[];
    void walk(RenderNode node, int depth, List<bool> lasts) {
      rows.add((node, depth, lasts));
      for (var i = 0; i < node.children.length; i++) {
        walk(node.children[i], depth + 1, [
          ...lasts,
          i == node.children.length - 1,
        ]);
      }
    }

    walk(root, 0, const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (node, depth, lasts) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (depth > 0)
                    SizedBox(
                      width: depth * _indent,
                      child: CustomPaint(
                        painter: _TreeConnectorPainter(
                          depth: depth,
                          lasts: lasts,
                          color: p.borderStrong,
                        ),
                      ),
                    ),
                  _renderNodeBox(node, p),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _renderNodeBox(RenderNode node, Palette p) {
    if (node.count > 1) {
      // One node standing for [count] render objects: a stacked deck, the
      // labelled front card opaque so the back cards only peek out.
      final color = node.widget.color ?? p.textTertiary;
      final decoration = BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: .2), p.surface),
        border: Border.all(color: color, width: 3),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 420,
            height: 74,
            child: Stack(
              children: [
                for (var deck = 2; deck >= 0; deck--)
                  Positioned(
                    left: deck * 10.0,
                    top: (2 - deck) * 9.0,
                    child: Container(
                      width: 380,
                      height: 52,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: decoration,
                      child: deck == 0
                          ? Text(
                              node.name,
                              style: mono(30, weight: 600, color: p.text),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          Text(node.note, style: archivo(24, color: p.textSecondary)),
        ],
      );
    }
    final color = node.widget.color ?? p.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: _widgetBoxDecoration(p, node.widget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(node.name, style: mono(30, weight: 600, color: p.text)),
              if (node.size.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  node.size,
                  style: archivo(24, color: p.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (node.note.isNotEmpty) ...[
          const SizedBox(width: 12),
          CustomPaint(
            foregroundPainter: _DashedBorderPainter(color: color),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                node.note,
                style: archivo(24, color: p.textSecondary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The demo's widget tree beside [_RenderTreeView]: chips in each widget's
/// color, with [DemoWidget.positioned] dashed because it creates no render
/// object.
class _WidgetTreeView extends StatelessWidget {
  const _WidgetTreeView({required this.root});

  final WidgetNode root;

  static const _indent = 44.0;
  static const _elbow = 22.0;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rows = <(WidgetNode, int, List<bool>)>[];
    void walk(WidgetNode node, int depth, List<bool> lasts) {
      rows.add((node, depth, lasts));
      for (var i = 0; i < node.children.length; i++) {
        walk(node.children[i], depth + 1, [
          ...lasts,
          i == node.children.length - 1,
        ]);
      }
    }

    walk(root, 0, const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (node, depth, lasts) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (depth > 0)
                    SizedBox(
                      width: depth * _indent,
                      child: CustomPaint(
                        painter: _TreeConnectorPainter(
                          depth: depth,
                          lasts: lasts,
                          color: p.borderStrong,
                          indent: _indent,
                          elbow: _elbow,
                        ),
                      ),
                    ),
                  _widgetChip(node, p),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _widgetChip(WidgetNode node, Palette p) {
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(node.name, style: mono(30, weight: 600, color: p.text)),
    );
    final chip = node.widget.color == null
        ? CustomPaint(
            foregroundPainter: _DashedBorderPainter(
              color: p.textTertiary,
            ),
            child: label,
          )
        : Container(
            decoration: _widgetBoxDecoration(p, node.widget),
            child: label,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        chip,
        if (node.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              node.note,
              style: archivo(22, color: p.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// The elbow connectors beside one render-tree row: ancestor verticals and
/// the node's own ├ or └.
class _TreeConnectorPainter extends CustomPainter {
  _TreeConnectorPainter({
    required this.depth,
    required this.lasts,
    required this.color,
    this.indent = _RenderTreeView._indent,
    this.elbow = _RenderTreeView._elbow,
  });

  final int depth;

  /// For each ancestor depth 1..depth, whether that node is the last child.
  final List<bool> lasts;
  final Color color;
  final double indent;
  final double elbow;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var a = 1; a < depth; a++) {
      if (lasts[a - 1]) continue;
      final x = a * indent - elbow;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final x = depth * indent - elbow;
    canvas
      ..drawLine(
        Offset(x, 0),
        Offset(x, lasts.last ? mid : size.height),
        paint,
      )
      ..drawLine(Offset(x, mid), Offset(depth * indent, mid), paint);
  }

  @override
  bool shouldRepaint(_TreeConnectorPainter oldDelegate) =>
      depth != oldDelegate.depth ||
      !listEquals(lasts, oldDelegate.lasts) ||
      color != oldDelegate.color ||
      indent != oldDelegate.indent ||
      elbow != oldDelegate.elbow;
}

/// The demo's paint calls in order: a colored pill per render object, then
/// what it did — a draw call with a picture badge, or an outlined layer
/// chip for a push.
class _PaintOpsView extends StatelessWidget {
  const _PaintOpsView({required this.ops, required this.notes});

  final List<PaintOp> ops;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final op in ops)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: _widgetBoxDecoration(p, op.widget),
                  child: Text(
                    op.renderObject,
                    style: mono(28, weight: 600, color: p.text),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 30,
                    color: p.textTertiary,
                  ),
                ),
                _action(op, p),
              ],
            ),
          ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              note,
              style: archivo(26, height: 1.2, color: p.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _action(PaintOp op, Palette p) {
    final color = op.widget.color ?? p.textTertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (op.pushes case final pushes?)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              'push $pushes',
              style: mono(26, color: p.textSecondary),
            ),
          ),
        if (op.picture case final picture?)
          Padding(
            padding: EdgeInsets.only(top: op.pushes != null ? 6 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(op.action, style: mono(28, color: p.text)),
                const SizedBox(width: 10),
                _PictureBadge(picture),
              ],
            ),
          ),
      ],
    );
  }
}

/// The layer tree paint pushed: nested boxes, each outlined in its pusher's
/// color, children top to bottom in paint order, pictures as filled tiles
/// striped with their sources' colors.
class _LayerTreeView extends StatelessWidget {
  const _LayerTreeView({required this.root});

  final LayerNode root;

  @override
  Widget build(BuildContext context) => _layerBox(root, Palette.of(context));

  Widget _layerBox(LayerNode node, Palette p) {
    if (node.picture != null) return _pictureTile(node, p);
    final color = node.widget?.color ?? p.textTertiary;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(node.name, style: mono(30, weight: 600, color: p.text)),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in node.children)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _layerBox(child, p),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pictureTile(LayerNode node, Palette p) {
    return Container(
      width: 210,
      height: 64,
      decoration: BoxDecoration(color: p.text.withValues(alpha: .85)),
      child: Row(
        children: [
          for (final source in node.sources)
            Container(
              width: 8,
              color: source.color ?? p.textTertiary,
            ),
          const SizedBox(width: 12),
          _PictureBadge(
            node.picture!,
            background: p.surface,
            foreground: p.text,
          ),
          const SizedBox(width: 8),
          Text('Picture', style: mono(26, color: p.surface)),
        ],
      ),
    );
  }
}

/// The spec's demo: a frosted card with a caret over a blue page.
class _DemoScreen extends StatelessWidget {
  const _DemoScreen();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF2563EB)),
        Positioned(
          left: 30,
          top: 40,
          child: Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFF93C5FD),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 26,
          bottom: 36,
          child: Container(
            width: 110,
            height: 60,
            color: const Color(0xFF1E3A8A),
          ),
        ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 200,
                height: 80,
                color: const Color(0x33FFFFFF),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.centerLeft,
                child: Container(width: 3, height: 30, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
