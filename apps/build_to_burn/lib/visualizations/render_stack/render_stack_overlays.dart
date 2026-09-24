part of 'render_stack.dart';

/// The hook: the demo on a phone in front of the dimmed stack, with a vote.
class _HookPhoneOverlay extends StatelessWidget {
  const _HookPhoneOverlay({required this.phone, required this.presence});

  final HookPhone phone;
  final double presence;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Positioned.fill(
      child: Opacity(
        opacity: presence,
        child: Transform.translate(
          offset: Offset(0, (1 - presence) * 40),
          child: Stack(
            children: [
              Positioned(
                left: _centerX - 180,
                top: 70,
                width: 360,
                height: 760,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(52),
                    border: Border.all(color: p.text, width: 10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(52),
                    child: const _HookScreen(),
                  ),
                ),
              ),
              Positioned(
                left: _centerX + 260,
                top: 250,
                width: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phone.question,
                      style: archivo(40, weight: 500, color: p.text),
                    ),
                    const SizedBox(height: 28),
                    for (final option in phone.options)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: p.surface,
                          border: Border.all(color: p.border, width: 2),
                        ),
                        child: Text(
                          option,
                          style: archivo(28, color: p.text),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The spec's demo at phone size: a blue page, a frosted card with a white
/// field and hairline border, and a fading iOS caret.
class _HookScreen extends StatelessWidget {
  const _HookScreen();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF2563EB)),
        for (final (left, top, size) in [
          (40.0, 170.0, 150.0),
          (200.0, 470.0, 120.0),
        ])
          Positioned(
            left: left,
            top: top,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Color(0xFF93C5FD),
                shape: BoxShape.circle,
              ),
            ),
          ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.4, sigmaY: 8.4),
              child: Container(
                width: 252,
                height: 101,
                color: const Color(0x33FFFFFF),
                alignment: Alignment.center,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0x33000000),
                      width: .5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  child: const _FadingCaret(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An iOS-style caret: holds, fades out, holds, fades in, once a second.
class _FadingCaret extends StatelessWidget {
  const _FadingCaret();

  static final _opacity = Track<double>(
    .single,
    initial: 1,
    debugLabel: 'Hook caret',
  );

  static const _fade = Motion.linear(Duration(milliseconds: 150));

  @override
  Widget build(BuildContext context) => TrackBuilder(
    debugLabel: 'Hook caret',
    loop: .loop,
    animations: [
      _opacity(const [
        .hold(Duration(milliseconds: 500)),
        .to(0, motion: _fade),
        .hold(Duration(milliseconds: 200)),
        .to(1, motion: _fade),
      ]),
    ],
    builder: (context, value, child) =>
        Opacity(opacity: value(_opacity).clamp(0, 1), child: child),
    child: Container(width: 2, height: 17, color: const Color(0xFF007AFF)),
  );
}

/// The GPU tier's tile memory: tiles light up as the pass renders.
class _TilePainter extends CustomPainter {
  _TilePainter({
    required this.progress,
    required this.color,
    required this.empty,
  });

  final double progress;
  final Color color;
  final Color empty;

  static const _grid = 7;
  static const _margin = 14.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final tile = (size.width - 2 * _margin - (_grid - 1) * _gap) / _grid;
    final lit = (progress * _grid * _grid).floor();
    for (var row = 0; row < _grid; row++) {
      for (var column = 0; column < _grid; column++) {
        final index = row * _grid + column;
        canvas.drawRect(
          Rect.fromLTWH(
            _margin + column * (tile + _gap),
            _margin + row * (tile + _gap),
            tile,
            tile,
          ),
          Paint()
            ..color = index < lit
                ? color.withValues(alpha: .85)
                : empty.withValues(alpha: .6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TilePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      empty != oldDelegate.empty;
}

/// DRAM next to the GPU band, with the frame streaming out (flush) or back
/// in (re-seed).
class _DramOverlay extends StatefulWidget {
  const _DramOverlay({
    required this.phase,
    required this.presence,
    required this.tierCenter,
  });

  final TilePhase phase;
  final double presence;
  final double tierCenter;

  @override
  State<_DramOverlay> createState() => _DramOverlayState();
}

class _DramOverlayState extends State<_DramOverlay> {
  final _flow = Track<double>(.single, initial: 0, debugLabel: 'DRAM flow');

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final box = Rect.fromLTWH(10, widget.tierCenter - 250, 300, 160);
    final plane = Offset(_centerX - _halfWidth, widget.tierCenter);
    final port = Offset(box.right, box.bottom - 20);
    final outward = widget.phase == TilePhase.flush;
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: widget.presence,
          child: Stack(
            children: [
              TrackBuilder(
                debugLabel: 'DRAM flow',
                loop: .loop,
                animations: [
                  _flow(const [
                    .to(0, motion: .linear(Duration(milliseconds: 1))),
                    .to(1, motion: .linear(Duration(milliseconds: 700))),
                  ]),
                ],
                builder: (context, value, _) => CustomPaint(
                  size: RenderStack.designSize,
                  painter: _FlowPainter(
                    from: outward ? plane : port,
                    to: outward ? port : plane,
                    phase: value(_flow).clamp(0.0, 1.0),
                    color: heat,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: box,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(color: heat, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DRAM', style: mono(22, weight: 700, color: heat)),
                      const SizedBox(height: 6),
                      Text(
                        outward
                            ? 'store T0: 1179×2556 RGBA8 ≈ 12 MB'
                            : 're-seed: full-screen redraw from T0',
                        style: archivo(17, height: 1.3, color: p.text),
                      ),
                      Text(
                        '× 120/s ≈ 3–4 GB/s [estimate]',
                        style: mono(14, color: p.textSecondary),
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

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.from,
    required this.to,
    required this.phase,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: .35)
        ..strokeWidth = 3,
    );
    final dot = Paint()..color = color;
    for (var k = 0; k < 4; k++) {
      final t = (phase + k / 4) % 1;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.lerp(from, to, t)!,
          width: 14,
          height: 14,
        ),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_FlowPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      from != oldDelegate.from ||
      to != oldDelegate.to ||
      color != oldDelegate.color;
}

/// Frames in flight on the finished stack: N+1 on the UI planes, N on the
/// raster planes, N-1 on the GPU and display. When animated, every frame
/// moves up one stage per (slowed) vsync.
class _FrameTokens extends StatefulWidget {
  const _FrameTokens({
    required this.layout,
    required this.presence,
    required this.frames,
  });

  final _Layout layout;
  final double presence;
  final FramesInFlight frames;

  @override
  State<_FrameTokens> createState() => _FrameTokensState();
}

class _FrameTokensState extends State<_FrameTokens> {
  final _step = Track<double>(.single, initial: 0, debugLabel: 'Vsync step');

  static const _move = Motion.curved(Duration(milliseconds: 900), easeInOut);

  double _mid(int a, int b) {
    final layout = widget.layout;
    return (layout.center(layout.indexOf(a)) +
            layout.center(layout.indexOf(b))) /
        2;
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    if ([1, 3, 6, 7, 8, 9].any((tier) => layout.indexOf(tier) < 0)) {
      return const SizedBox.shrink();
    }
    final positions = [
      layout.center(layout.indexOf(1)) + 90,
      layout.center(layout.indexOf(3)),
      _mid(6, 7),
      _mid(8, 9),
      layout.top(layout.indexOf(9)) - 70,
    ];
    Widget picture(double t) => _TokensPainter(
      positions: positions,
      t: t,
      presence: widget.presence,
    );
    if (!widget.frames.animated) return picture(0);
    return TrackBuilder(
      debugLabel: 'Frames in flight',
      loop: .loop,
      animations: [
        _step(const [
          .to(0, motion: .linear(Duration(milliseconds: 1))),
          .hold(Duration(milliseconds: 700)),
          .to(1, motion: _move),
        ]),
      ],
      builder: (context, value, _) => picture(value(_step).clamp(0.0, 1.0)),
    );
  }
}

class _TokensPainter extends StatelessWidget {
  const _TokensPainter({
    required this.positions,
    required this.t,
    required this.presence,
  });

  final List<double> positions;
  final double t;
  final double presence;

  static const labels = ['N+2', 'N+1', 'N', 'N−1'];

  static List<Color> colors(Palette p) => [
    p.accent,
    p.accent,
    ExampleTheme.roseQuartz,
    heat,
  ];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final palette = colors(p);
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (var k = 0; k < 4; k++)
              Positioned(
                left: _centerX - 70,
                width: 140,
                top: lerpDouble(positions[k], positions[k + 1], t)! - 26,
                child: Opacity(
                  opacity:
                      presence *
                      switch (k) {
                        0 => t,
                        3 => 1 - t,
                        _ => 1.0,
                      },
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: palette[k],
                        boxShadow: [
                          BoxShadow(
                            color: palette[k].withValues(alpha: .5),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                      child: Text(
                        'frame ${labels[k]}',
                        style: mono(18, weight: 700, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
