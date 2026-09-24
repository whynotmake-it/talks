part of 'render_stack.dart';

/// A stage as its own flat slide, which then lands on the stack as its plane.
///
/// [morph] 0 draws the slide flat over the whole picture; 1 maps it onto the
/// plane's rhombus at [planeTop]. In between, the transform is an elementwise
/// blend of the two affine maps, so the slide tilts and shrinks into place.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.tier,
    required this.previous,
    required this.card,
    required this.morph,
    required this.planeTop,
  });

  final StackTier tier;
  final StackTier? previous;
  final double card;
  final double morph;
  final double planeTop;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final size = Size(_cardRect.width, _cardRect.height);
    final top = Offset(_centerX, planeTop);
    final right = Offset(_centerX + _halfWidth, planeTop + _plane / 2);
    final left = Offset(_centerX - _halfWidth, planeTop + _plane / 2);
    final ex = (right - top) / size.width;
    final ey = (left - top) / size.height;
    final flat = Matrix4.translationValues(_cardRect.left, _cardRect.top, 0);
    final iso = Matrix4(
      ex.dx,
      ex.dy,
      0,
      0, //
      ey.dx,
      ey.dy,
      0,
      0,
      0,
      0,
      1,
      0,
      top.dx,
      top.dy,
      0,
      1,
    );
    final t = morph.clamp(0.0, 1.0);
    final matrix = Matrix4.zero();
    for (var i = 0; i < 16; i++) {
      matrix.storage[i] = lerpDouble(flat.storage[i], iso.storage[i], t)!;
    }
    final entrance = Curves.easeOut.transform(card);
    return Positioned(
      left: 0,
      top: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: card,
          child: Transform(
            transform: matrix,
            child: Transform.scale(
              scale: t > 0 ? 1 : lerpDouble(.97, 1, entrance)!,
              child: SizedBox.fromSize(
                size: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(
                      color: Color.lerp(p.border, p.accent, t)!,
                      width: lerpDouble(2, 14, t)!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: p.text.withValues(alpha: .08 * (1 - t)),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Opacity(
                    opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                    child: tier.detail is CodeDetail
                        ? _CodeView(code: (tier.detail! as CodeDetail).code)
                        : _StageContent(tier: tier, previous: previous),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain editor: the code the audience writes every day.
class _CodeView extends StatelessWidget {
  const _CodeView({required this.code});

  final String code;

  static final _tokens = RegExp(
    r"(//.*)|(@\w+)|(\b(?:class|extends|const|return|super|final|required)\b)"
    r"|(0x[0-9A-Fa-f]+|\b\d+\b)|(\b[A-Z]\w*)|([()\[\]{},;:.])",
  );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in _tokens.allMatches(code)) {
      if (match.start > start) {
        spans.add(TextSpan(text: code.substring(start, match.start)));
      }
      final color = switch (match) {
        _ when match.group(1) != null || match.group(2) != null =>
          p.textTertiary,
        _ when match.group(3) != null => p.accent,
        _ when match.group(4) != null => heat,
        _ when match.group(5) != null => p.text,
        _ => p.textTertiary,
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
    spans.add(TextSpan(text: code.substring(start)));
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
              Text('demo.dart', style: mono(18, color: p.textSecondary)),
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
                style: mono(23, height: 1.38, color: p.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A stage slide: the question, the input it takes (the previous stage's
/// output), one picture, and the output it hands up.
class _StageContent extends StatelessWidget {
  const _StageContent({required this.tier, required this.previous});

  final StackTier tier;
  final StackTier? previous;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 44, 56, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STAGE ${tier.number} · ${tier.title.toUpperCase()}',
            style: mono(20, weight: 600, color: p.accent),
          ),
          const SizedBox(height: 10),
          Text(tier.stage, style: archivo(52, spacing: -1.4, color: p.text)),
          const SizedBox(height: 28),
          Expanded(
            child: Row(
              children: [
                _HandoffChip(
                  label: 'INPUT',
                  value: tier.inputs,
                  note: switch (previous) {
                    final previous? =>
                      'from ${previous.number} ${previous.title}',
                    null => '',
                  },
                  color: p.textSecondary,
                ),
                const _Arrow(),
                Expanded(child: _StagePicture(tier: tier)),
                const _Arrow(),
                _HandoffChip(
                  label: 'OUTPUT',
                  value: tier.outputs,
                  note: tier.example,
                  color: p.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '→ ${tier.handoff}',
            style: mono(22, weight: 500, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HandoffChip extends StatelessWidget {
  const _HandoffChip({
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: mono(16, weight: 700, color: color)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: label == 'OUTPUT' ? p.accentSoft : p.inset,
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              value,
              style: archivo(26, weight: 500, height: 1.2, color: p.text),
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              note,
              style: mono(15, height: 1.4, color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Icon(
      Icons.arrow_forward,
      size: 40,
      color: Palette.of(context).textTertiary,
    ),
  );
}

/// The one picture on a stage slide.
class _StagePicture extends StatelessWidget {
  const _StagePicture({required this.tier});

  final StackTier tier;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final Widget picture = switch (tier.detail) {
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
        width: 460,
        height: 300,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 260,
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
      _ => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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

  static const rect = Rect.fromLTWH(20, 560, 280, 310);

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
                        style: mono(15, weight: 700, color: color),
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
      18,
      weight: _emphasized(text) ? 700 : 450,
      height: 1.4,
      color: _emphasized(text) ? heat : p.text,
    );
    return switch (detail) {
      null || ScreenDetail() => const SizedBox.shrink(),
      CodeDetail(:final code) => Text(
        code.split('\n').take(8).join('\n'),
        style: mono(13, height: 1.35, color: p.text),
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
          Text(label.toUpperCase(), style: mono(13, color: p.textTertiary)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var slot = 0; slot < slots; slot++)
                Container(
                  width: 96,
                  height: 64,
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
                          style: mono(15, weight: 600, color: color),
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
                    width: 34,
                    child: Text(
                      pass.name,
                      style: mono(
                        15,
                        weight: 700,
                        color: pass.hot ? heat : p.text,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 136,
                    child: Text(
                      pass.label,
                      maxLines: 1,
                      softWrap: false,
                      style: mono(14, color: pass.hot ? heat : p.textSecondary),
                    ),
                  ),
                  for (var call = 0; call < pass.drawCalls; call++)
                    Container(
                      width: 8,
                      height: 14,
                      margin: const EdgeInsets.only(right: 3),
                      color: pass.hot ? heat : p.accent,
                    ),
                ],
              ),
            ),
        ],
      ),
    };
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
