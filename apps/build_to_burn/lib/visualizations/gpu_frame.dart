import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';

/// One step of the GPU chapter: how the GPU paints the demo frame, and why
/// its backdrop blur costs a trip through memory.
enum GpuBeat {
  /// The phone is blank; the GPU is about to paint.
  start,

  /// The background paints a wave of tiles at a time, each tile's pixels at
  /// once. It gets about halfway.
  paint,

  /// A thought experiment: could the blur be painted now? The area it needs
  /// is highlighted, and part of it isn't painted yet.
  needs,

  /// The GPU finishes everything behind the blur first: one pass.
  finish,

  /// The pass ends: the finished picture moves out to memory.
  store,

  /// The blur reads the stored picture and writes a blurred copy, also in
  /// memory.
  read,

  /// A new pass paints the picture again, then the blurred copy on top, then
  /// the field.
  back,

  /// The round trip, on every frame.
  repeat,
}

/// The demo frame on a phone, painted by the GPU, with memory beside it.
///
/// Draws [beat] and animates from the previous beat when it advances by one;
/// any other change jumps. Laid out in a 2000×900 design box that scales to
/// fit.
class GpuFrame extends StatefulWidget {
  const GpuFrame({required this.beat, super.key});

  final GpuBeat beat;

  static const designSize = Size(2000, 900);

  @override
  State<GpuFrame> createState() => _GpuFrameState();
}

class _GpuFrameState extends State<GpuFrame> with TickerProviderStateMixin {
  /// How far the background has painted: halfway when the blur comes up.
  late final _paint = _controller(2600);
  late final _needs = _controller(500);
  late final _store = _controller(1100);
  late final _read = _controller(1800);
  late final _back = _controller(1100);

  /// The blurred copy flying onto the card, then the field.
  late final _top = _controller(1200);

  /// One whole frame, every step again, repeating on the last beat.
  late final _loop = _controller(4200);

  /// Frames the last beat has replayed so far.
  int _frames = 1;
  double _lastLoop = 0;

  /// Where the paint stops for the blur: right at the end of a wave, so no
  /// tile is half painted.
  static final _halfway = 6 / (_columns * _rows / _perWave).ceil();

  AnimationController _controller(int milliseconds) => AnimationController(
    vsync: this,
    duration: Duration(milliseconds: milliseconds),
  );

  List<AnimationController> get _all => [
    _paint,
    _needs,
    _store,
    _read,
    _back,
    _top,
    _loop,
  ];

  @override
  void initState() {
    super.initState();
    _loop.addListener(() {
      if (_loop.value < _lastLoop) _frames++;
      _lastLoop = _loop.value;
    });
    _apply(widget.beat, animate: false);
  }

  @override
  void didUpdateWidget(GpuFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beat != widget.beat) {
      _apply(
        widget.beat,
        animate: widget.beat.index == oldWidget.beat.index + 1,
      );
    }
  }

  /// Sets every controller for [beat], animating the ones that change.
  void _apply(GpuBeat beat, {required bool animate}) {
    final at = beat.index;
    void to(AnimationController controller, double target) {
      if (animate && controller.value != target) {
        controller.animateTo(target);
      } else {
        controller.value = target;
      }
    }

    if (animate && beat == GpuBeat.paint) {
      // Slows down toward the pause, so it reads as a pause, not a stall.
      _paint.animateTo(
        _halfway,
        duration: const Duration(milliseconds: 3200),
        curve: Curves.easeOutQuart,
      );
    } else if (animate && beat == GpuBeat.finish) {
      // Picks up speed again once it goes on.
      _paint.animateTo(
        1,
        duration: const Duration(milliseconds: 2200),
        curve: Curves.easeInQuad,
      );
    } else {
      to(
        _paint,
        at >= GpuBeat.finish.index
            ? 1
            : at >= GpuBeat.paint.index
            ? _halfway
            : 0,
      );
    }
    to(_needs, at >= GpuBeat.needs.index ? 1 : 0);
    to(_store, at >= GpuBeat.store.index ? 1 : 0);
    to(_read, at >= GpuBeat.read.index ? 1 : 0);
    if (animate && beat == GpuBeat.back) {
      // The picture comes back first, then the blurred copy goes on top.
      _top.value = 0;
      _back.animateTo(1).whenComplete(() {
        if (mounted && widget.beat == GpuBeat.back) _top.animateTo(1);
      });
    } else {
      _back.value = at >= GpuBeat.back.index ? 1 : 0;
      _top.value = at >= GpuBeat.back.index ? 1 : 0;
    }
    if (beat == GpuBeat.repeat) {
      _frames = 1;
      _lastLoop = 0;
      _loop.repeat();
    } else {
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    for (final controller in _all) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox.fromSize(
        size: GpuFrame.designSize,
        child: AnimatedBuilder(
          animation: Listenable.merge(_all),
          builder: (context, _) => _picture(context),
        ),
      ),
    );
  }

  Widget _picture(BuildContext context) {
    final p = Palette.of(context);
    final beat = widget.beat;
    final at = beat.index;
    double ease(double t) => Curves.easeInOutCubic.transform(t.clamp(0, 1));

    // On the last beat every step runs again, one frame after another.
    final repeat = beat == GpuBeat.repeat;
    double phase(double from, double to) =>
        ((_loop.value - from) / (to - from)).clamp(0.0, 1.0);
    final paint = repeat ? phase(0, .22) : _paint.value;
    final store = repeat ? phase(.24, .38) : _store.value;
    final read = repeat ? phase(.40, .54) : _read.value;
    final backed = repeat ? phase(.56, .70) : _back.value;
    final top = repeat ? phase(.72, .86) : _top.value;
    final stored = repeat ? store > 0 : at >= GpuBeat.store.index;
    final reading = repeat ? read > 0 : at >= GpuBeat.read.index;
    final returned = repeat ? backed >= 1 : at >= GpuBeat.back.index;
    final back = ease(backed);

    // Where the picture is: on the phone, out in memory, or on its way.
    final out = ease(store) * (1 - back);
    final onPhone = !stored || back >= 1;

    // The blurred copy: in memory while the blur writes it, then onto the
    // card. The field follows once it has landed.
    final fly = ease((top / .7).clamp(0, 1));
    final field = ((top - .7) / .3).clamp(0.0, 1.0);
    final copyRect = Rect.lerp(_blurredSlot, _card, fly)!;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The phone and what it shows.
        Positioned.fromRect(
          rect: _phone,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(52),
              border: Border.all(color: p.text, width: 10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(52),
              child: ColoredBox(
                color: p.inset,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      if (onPhone)
                        _TiledBackground(
                          progress: paint,
                          empty: p.inset,
                          active: p.accent,
                        ),
                      if (at == GpuBeat.needs.index ||
                          at == GpuBeat.finish.index)
                        CustomPaint(
                          painter: _NeedsPainter(
                            progress: paint,
                            presence: _needs.value,
                            color: heat,
                          ),
                        ),
                      // The card waits as an outline until its blurred copy
                      // lands on it.
                      if (_needs.value > 0 && fly < 1)
                        Positioned.fromRect(
                          rect: _card.shift(-_screen.topLeft),
                          child: Opacity(
                            opacity: _needs.value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: p.text, width: 4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (at == GpuBeat.needs.index || at == GpuBeat.finish.index)
          Positioned(
            left: _phone.right + 50,
            top: _card.top - 40,
            child: Opacity(
              opacity: _needs.value,
              child: const _NeedsLegend(),
            ),
          ),

        // Memory, once the picture has to go there.
        if (at >= GpuBeat.store.index)
          Positioned.fromRect(
            rect: _memory,
            child: _MemoryBox(p: p, blurredLabel: reading),
          ),
        // Memory keeps its copy after the trip back.
        if (returned)
          Positioned.fromRect(
            rect: _pictureSlot,
            child: const Opacity(opacity: .35, child: _Background()),
          ),

        // The picture on its way to or from memory, and at rest there: in
        // front of the memory box.
        if (!onPhone)
          Positioned.fromRect(
            rect: Rect.lerp(_screen, _pictureSlot, out)!,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(lerpDouble(42, 6, out)!),
              child: const _Background(),
            ),
          ),

        // The blur reading the stored picture: only the area it needs.
        if (repeat ? read > 0 && read < 1 : at == GpuBeat.read.index)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ReadPainter(
                  progress: read,
                  from: _neededInSlot,
                  to: _blurredSlot,
                  color: p.accent,
                ),
              ),
            ),
          ),

        // The blurred copy: filling up in memory, then flying onto the card.
        if (reading)
          Positioned.fromRect(
            rect: copyRect,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: read,
                child: _BlurredCopy(field: field),
              ),
            ),
          ),

        if (at >= GpuBeat.store.index)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TripsPainter(
                  outward: repeat ? 1.0 : ease(store),
                  inward: repeat || returned ? 1.0 : 0.0,
                  color: heat,
                ),
              ),
            ),
          ),

        // The bill: only the trips the blur adds.
        if (at >= GpuBeat.store.index)
          Positioned(
            left: _memory.left,
            top: _memory.bottom + 24,
            width: _memory.width,
            child: _Bill(
              blur: repeat || reading,
              back: repeat || returned,
              frames: repeat ? _frames : null,
              p: p,
            ),
          ),
      ],
    );
  }
}

// Layout, in design pixels. The screen is the demo's own 360×760, so the
// card and the circles sit where they do on the hook's phone.
const _phone = Rect.fromLTWH(380, 20, 380, 780);
const _screen = Rect.fromLTWH(390, 30, 360, 760);
final _card = Rect.fromCenter(center: _screen.center, width: 252, height: 101);

/// What the blur reads: the card and as far around it as the blur reaches.
final _needed = _card.inflate(30);

const _memory = Rect.fromLTWH(1170, 40, 600, 600);
const _pictureSlot = Rect.fromLTWH(1200, 120, 220, 464);
final _blurredSlot = Rect.fromLTWH(1480, 330, _card.width, _card.height);

/// [_needed], where it lies on the picture stored in [_pictureSlot].
Rect get _neededInSlot {
  final scale = _pictureSlot.width / _screen.width;
  final local = _needed.shift(-_screen.topLeft);
  return Rect.fromLTWH(
    _pictureSlot.left + local.left * scale,
    _pictureSlot.top + local.top * scale,
    local.width * scale,
    local.height * scale,
  );
}

/// Tiles in the stylized grid, and how many the GPU paints at once: about
/// one per core of the iPhone 15 Pro's 6-core GPU (Apple: each tile goes to
/// one GPU core, many at the same time).
const _columns = 6;
const _rows = 13;
const _perWave = 6;

/// The demo's page: blue with three light circles, two of them behind the
/// card so its blur shows. The same as the hook's phone.
class _Background extends StatelessWidget {
  const _Background();

  static const circles = [
    (40.0, 170.0, 150.0),
    (160.0, 290.0, 150.0),
    (30.0, 400.0, 110.0),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = constraints.maxWidth / 360;
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF2563EB)),
          for (final (left, top, size) in circles)
            Positioned(
              left: left * scale,
              top: top * scale,
              child: Container(
                width: size * scale,
                height: size * scale,
                decoration: const BoxDecoration(
                  color: Color(0xFF93C5FD),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// The card's blurred copy: the page behind the card, really blurred, under
/// the frost, with the field once [field] fades in.
class _BlurredCopy extends StatelessWidget {
  const _BlurredCopy({required this.field});

  final double field;

  @override
  Widget build(BuildContext context) {
    final card = _card.shift(-_screen.topLeft);
    return SizedBox.fromSize(
      size: _card.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              left: -card.left,
              top: -card.top,
              width: _screen.width,
              height: _screen.height,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8.4, sigmaY: 8.4),
                child: const _Background(),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0x33FFFFFF))),
            if (field > 0)
              Center(
                child: Opacity(
                  opacity: field,
                  child: Container(
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: 17,
                      color: const Color(0xFF007AFF),
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

/// The background, revealed a wave of tiles at a time: [_perWave] tiles per
/// wave, each tile all at once. The wave being painted is outlined.
class _TiledBackground extends StatelessWidget {
  const _TiledBackground({
    required this.progress,
    required this.empty,
    required this.active,
  });

  final double progress;
  final Color empty;
  final Color active;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const _Background(),
      CustomPaint(
        painter: _TileCoverPainter(
          progress: progress,
          empty: empty,
          active: active,
        ),
      ),
    ],
  );
}

/// Which tiles are painted at [progress], and how far the current wave is.
({int wave, double within}) _waveAt(double progress) {
  final waves = (_columns * _rows / _perWave).ceil();
  // Rounded, so a pause right at the end of a wave shows no half tile.
  final wave = (progress * waves * 1000).round() / 1000;
  return (wave: wave.floor(), within: wave - wave.floor());
}

Rect _tile(int index, Size size) {
  final w = size.width / _columns;
  final h = size.height / _rows;
  return Rect.fromLTWH((index % _columns) * w, (index ~/ _columns) * h, w, h);
}

class _TileCoverPainter extends CustomPainter {
  _TileCoverPainter({
    required this.progress,
    required this.empty,
    required this.active,
  });

  final double progress;
  final Color empty;
  final Color active;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final (:wave, :within) = _waveAt(progress);
    final painting = progress > 0 && within > 0;
    for (var index = 0; index < _columns * _rows; index++) {
      final rect = _tile(index, size);
      final tileWave = index ~/ _perWave;
      if (tileWave < wave) continue;
      if (tileWave == wave && painting) {
        // All of this tile's pixels arrive together.
        canvas
          ..drawRect(rect, Paint()..color = empty.withValues(alpha: 1 - within))
          ..drawRect(
            rect.deflate(2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = active,
          );
      } else {
        canvas.drawRect(rect, Paint()..color = empty);
      }
    }
    // Faint grid lines over what isn't painted yet.
    final grid = Paint()
      ..color = active.withValues(alpha: .15)
      ..strokeWidth = 1.5;
    final w = size.width / _columns;
    final h = size.height / _rows;
    for (var column = 1; column < _columns; column++) {
      canvas.drawLine(
        Offset(column * w, 0),
        Offset(column * w, size.height),
        grid,
      );
    }
    for (var row = 1; row < _rows; row++) {
      canvas.drawLine(Offset(0, row * h), Offset(size.width, row * h), grid);
    }
  }

  @override
  bool shouldRepaint(_TileCoverPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      empty != oldDelegate.empty ||
      active != oldDelegate.active;
}

/// The tiles the blur needs, outlined whole. The ones not painted yet show
/// empty, tinted.
class _NeedsPainter extends CustomPainter {
  _NeedsPainter({
    required this.progress,
    required this.presence,
    required this.color,
  });

  final double progress;
  final double presence;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final area = _needed.shift(-_screen.topLeft);
    final (:wave, within: _) = _waveAt(progress);
    for (var index = 0; index < _columns * _rows; index++) {
      final rect = _tile(index, size);
      if (!rect.overlaps(area)) continue;
      final painted = progress >= 1 || index ~/ _perWave < wave;
      if (!painted) {
        canvas.drawRect(
          rect,
          Paint()..color = color.withValues(alpha: .22 * presence),
        );
      }
      canvas.drawRect(
        rect.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = color.withValues(alpha: presence),
      );
    }
  }

  @override
  bool shouldRepaint(_NeedsPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      presence != oldDelegate.presence ||
      color != oldDelegate.color;
}

void _dashedRect(Canvas canvas, Rect rect, Color color, double width) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = width;
  const dash = 16.0;
  const gap = 10.0;
  void line(Offset a, Offset b) {
    final length = (b - a).distance;
    final step = (b - a) / length;
    for (var t = 0.0; t < length; t += dash + gap) {
      final end = (t + dash).clamp(0.0, length);
      canvas.drawLine(a + step * t, a + step * end, paint);
    }
  }

  line(rect.topLeft, rect.topRight);
  line(rect.topRight, rect.bottomRight);
  line(rect.bottomRight, rect.bottomLeft);
  line(rect.bottomLeft, rect.topLeft);
}

/// Names the marked tiles beside the phone.
class _NeedsLegend extends StatelessWidget {
  const _NeedsLegend();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 40,
        decoration: BoxDecoration(
          color: heat.withValues(alpha: .22),
          border: Border.all(color: heat, width: 4),
        ),
      ),
      const SizedBox(width: 16),
      Text('tiles the blur needs', style: archivo(32, color: heat)),
    ],
  );
}

/// Main memory, off the GPU: the stored picture and the blurred copy.
class _MemoryBox extends StatelessWidget {
  const _MemoryBox({required this.p, required this.blurredLabel});

  final Palette p;
  final bool blurredLabel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: p.surface,
      border: Border.all(color: heat, width: 3),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 24,
          top: 18,
          child: Text(
            'MEMORY  ·  off the GPU',
            style: mono(30, weight: 700, color: heat),
          ),
        ),
        Positioned(
          left: _pictureSlot.left - _memory.left,
          top: _pictureSlot.bottom - _memory.top + 4,
          child: Text('your frame', style: archivo(26, color: p.textSecondary)),
        ),
        if (blurredLabel)
          Positioned(
            left: _blurredSlot.left - _memory.left,
            top: _blurredSlot.top - _memory.top - 40,
            child: Text(
              'blurred copy',
              style: archivo(26, color: p.textSecondary),
            ),
          ),
      ],
    ),
  );
}

/// The blur reading only the area it needs from the stored picture.
class _ReadPainter extends CustomPainter {
  _ReadPainter({
    required this.progress,
    required this.from,
    required this.to,
    required this.color,
  });

  final double progress;
  final Rect from;
  final Rect to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    _dashedRect(canvas, from, color, 4);
    if (progress <= 0 || progress >= 1) return;
    final dot = Paint()..color = color;
    for (var k = 0; k < 5; k++) {
      final t = (progress * 3 + k / 5) % 1;
      canvas.drawCircle(
        Offset.lerp(from.centerRight, to.centerLeft, t)!,
        8,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_ReadPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      from != oldDelegate.from ||
      to != oldDelegate.to ||
      color != oldDelegate.color;
}

/// The arrows between the phone and memory.
class _TripsPainter extends CustomPainter {
  _TripsPainter({
    required this.outward,
    required this.inward,
    required this.color,
  });

  final double outward;
  final double inward;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    void arrow(Offset from, Offset to, double presence) {
      if (presence <= 0) return;
      final paint = Paint()
        ..color = color.withValues(alpha: presence)
        ..strokeWidth = 5;
      canvas.drawLine(from, to, paint);
      final direction = (to - from) / (to - from).distance;
      final normal = Offset(-direction.dy, direction.dx);
      final base = to - direction * 22;
      canvas.drawPath(
        Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo((base + normal * 12).dx, (base + normal * 12).dy)
          ..lineTo((base - normal * 12).dx, (base - normal * 12).dy)
          ..close(),
        Paint()..color = color.withValues(alpha: presence),
      );
    }

    arrow(
      Offset(_phone.right + 30, _memory.top + 60),
      Offset(_memory.left - 20, _memory.top + 60),
      outward,
    );
    arrow(
      Offset(_memory.left - 20, _memory.bottom - 60),
      Offset(_phone.right + 30, _memory.bottom - 60),
      inward,
    );
  }

  @override
  bool shouldRepaint(_TripsPainter oldDelegate) =>
      outward != oldDelegate.outward ||
      inward != oldDelegate.inward ||
      color != oldDelegate.color;
}

/// What the blur adds per frame: the trip out, the blur's own read, and the
/// trip back. Estimates for an iPhone 15 Pro screen in the BGRA10_XR format
/// of our Xcode capture: 8 bytes per pixel, ≈23 MiB per full-screen texture.
class _Bill extends StatelessWidget {
  const _Bill({
    required this.blur,
    required this.back,
    required this.frames,
    required this.p,
  });

  final bool blur;
  final bool back;

  /// The frame count on the last beat, else null.
  final int? frames;
  final Palette p;

  @override
  Widget build(BuildContext context) {
    final line = mono(32, color: p.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Extra per frame, for one blur (estimate)',
          style: archivo(28, color: p.textSecondary),
        ),
        const SizedBox(height: 8),
        Text('→ out   ≈24 MB', style: line),
        Opacity(
          opacity: blur ? 1 : 0,
          child: Text('+ blur  ≈4 MB', style: line),
        ),
        Opacity(
          opacity: back ? 1 : 0,
          child: Text('← back  ≈24 MB', style: line),
        ),
        if (frames case final frames?)
          Text(
            'frame $frames · again, every frame',
            style: mono(32, weight: 700, color: heat),
          ),
      ],
    );
  }
}
