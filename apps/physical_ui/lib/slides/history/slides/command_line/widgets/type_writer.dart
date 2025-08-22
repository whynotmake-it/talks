// ignore_for_file: prefer_int_literals

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class TypeWriter extends StatelessWidget {
  const TypeWriter({
    required this.lines,
    super.key,
    this.textStyle,
    this.typeSpeed = const Duration(milliseconds: 60),
    this.deleteSpeed = const Duration(milliseconds: 48),
    this.pauseAtFull = const Duration(milliseconds: 1200),
    this.pauseAfterDelete = const Duration(milliseconds: 300),
    this.loop = true,
    this.forceMarquee = false,
    this.marqueeVelocity = 48.0, // px/s
    this.marqueeGap = 32.0, // px between copies when overflowing
    this.marqueeLoops = 2,
    this.stagger = const Duration(milliseconds: 120),
    this.edgeFade = true,
    this.edgeFadeWidth = 16.0,
    this.caretWidthFactor = 0.6,
    this.caretHeightFactor = 1.1,
    this.hideCursorWhenInactive = false,
    this.onLineFullyVisible,
    this.onDone,
  });

  final List<String> lines;
  final TextStyle? textStyle;

  final Duration typeSpeed;
  final Duration deleteSpeed;
  final Duration pauseAtFull;
  final Duration pauseAfterDelete;
  final bool loop;

  final bool forceMarquee;
  final double marqueeVelocity;
  final double marqueeGap;
  final int marqueeLoops;

  final Duration stagger;
  final bool edgeFade;
  final double edgeFadeWidth;

  final double caretWidthFactor;
  final double caretHeightFactor;

  final bool hideCursorWhenInactive;

  final void Function(int lineIndex, String text)? onLineFullyVisible;

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? DefaultTextStyle.of(context).style;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < lines.length; i++)
          _TypewriterLine(
            key: ValueKey('tw_line_$i'),
            index: i,
            text: lines[i],
            textStyle: style,
            typeSpeed: typeSpeed,
            deleteSpeed: deleteSpeed,
            pauseAtFull: pauseAtFull,
            pauseAfterDelete: pauseAfterDelete,
            loop: loop,
            forceMarquee: forceMarquee,
            marqueeVelocity: marqueeVelocity,
            marqueeGap: marqueeGap,
            marqueeLoops: marqueeLoops,
            startDelay: stagger * i,
            edgeFade: edgeFade,
            edgeFadeWidth: edgeFadeWidth,
            caretWidthFactor: caretWidthFactor,
            caretHeightFactor: caretHeightFactor,
            hideCursorWhenInactive: hideCursorWhenInactive,
            onFullyVisible: onLineFullyVisible,
            onLineDone: i == lines.length - 1 && !loop ? onDone : null,
          ),
      ],
    );
  }
}

enum _Phase { waiting, typing, pauseFull, marquee, deleting }

class _TypewriterLine extends StatefulWidget {
  const _TypewriterLine({
    required this.index,
    required this.text,
    required this.textStyle,
    required this.typeSpeed,
    required this.deleteSpeed,
    required this.pauseAtFull,
    required this.pauseAfterDelete,
    required this.loop,
    required this.forceMarquee,
    required this.marqueeVelocity,
    required this.marqueeGap,
    required this.marqueeLoops,
    required this.startDelay,
    required this.edgeFade,
    required this.edgeFadeWidth,
    required this.caretWidthFactor,
    required this.caretHeightFactor,
    required this.hideCursorWhenInactive,
    this.onFullyVisible,
    this.onLineDone,
    super.key,
  });

  final int index;
  final String text;
  final TextStyle textStyle;
  final Duration typeSpeed;
  final Duration deleteSpeed;
  final Duration pauseAtFull;
  final Duration pauseAfterDelete;
  final bool loop;

  final bool forceMarquee;
  final double marqueeVelocity;
  final double marqueeGap;
  final int marqueeLoops;

  final Duration startDelay;
  final bool edgeFade;
  final double edgeFadeWidth;

  final double caretWidthFactor;
  final double caretHeightFactor;

  final bool hideCursorWhenInactive;

  final void Function(int lineIndex, String text)? onFullyVisible;

  final VoidCallback? onLineDone;

  @override
  State<_TypewriterLine> createState() => _TypewriterLineState();
}

class _TypewriterLineState extends State<_TypewriterLine>
    with TickerProviderStateMixin {
  late final List<String> _graphemes;
  int _visible = 0;
  _Phase _phase = _Phase.waiting;

  Timer? _timer;
  Ticker? _ticker;

  // Layout snapshot (updated in build)
  double _lastMaxWidth = 0;

  // Marquee metrics (frozen at marquee start)
  double _mBaseOverflow = 0;
  double _mGap = 0;
  double _mTravel = 0;
  double _mOffset = 0; // [0, _mTravel)
  int _marqueeCycles = 0;

  Duration _lastTick = Duration.zero;
  bool _firedFullCallbackThisCycle = false;

  @override
  void initState() {
    super.initState();
    _graphemes = widget.text.characters.toList();
    if (widget.startDelay > Duration.zero) {
      _timer = Timer(widget.startDelay, _startTyping);
    } else {
      _startTyping();
    }
  }

  @override
  void didUpdateWidget(covariant _TypewriterLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.forceMarquee != widget.forceMarquee ||
        oldWidget.marqueeLoops != widget.marqueeLoops ||
        oldWidget.marqueeVelocity != widget.marqueeVelocity ||
        oldWidget.marqueeGap != widget.marqueeGap ||
        oldWidget.typeSpeed != widget.typeSpeed ||
        oldWidget.deleteSpeed != widget.deleteSpeed ||
        oldWidget.pauseAtFull != widget.pauseAtFull ||
        oldWidget.pauseAfterDelete != widget.pauseAfterDelete ||
        oldWidget.hideCursorWhenInactive != widget.hideCursorWhenInactive) {
      _resetAndStart();
    }
  }

  void _resetAndStart() {
    _cancelAll();
    _visible = 0;
    _phase = _Phase.typing;
    _mOffset = 0;
    _marqueeCycles = 0;
    _firedFullCallbackThisCycle = false;
    _startTyping();
  }

  void _startTyping() {
    _phase = _Phase.typing;
    _scheduleTypeTick();
  }

  void _scheduleTypeTick() {
    _timer?.cancel();
    if (_visible < _graphemes.length) {
      _timer = Timer(widget.typeSpeed, () {
        if (!mounted) return;
        setState(() => _visible++);
        _scheduleTypeTick();
      });
    } else {
      if (!_firedFullCallbackThisCycle) {
        _firedFullCallbackThisCycle = true;
        widget.onFullyVisible?.call(widget.index, widget.text);
      }
      _phase = _Phase.pauseFull;
      _timer = Timer(widget.pauseAtFull, () {
        if (!mounted) return;
        setState(_decideAfterPause);
      });
    }
  }

  // ---- decisions ----
  double _caretReserveWidth() {
    final fs = widget.textStyle.fontSize ?? 14.0;
    return fs * widget.caretWidthFactor;
  }

  double _caretHeight() {
    final fs = widget.textStyle.fontSize ?? 14.0;
    return fs * widget.caretHeightFactor;
  }

  double _textWidth(String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: widget.textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  void _decideAfterPause() {
    // Ensure we have a real width; if not, wait a frame.
    if (_lastMaxWidth <= 0 || _lastMaxWidth.isInfinite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_decideAfterPause);
      });
      return;
    }

    final fullW = _textWidth(widget.text) + _caretReserveWidth();
    final willOverflow = fullW > _lastMaxWidth;
    final shouldMarquee =
        widget.marqueeLoops > 0 && (widget.forceMarquee || willOverflow);

    if (!shouldMarquee) {
      _startDeleting();
      return;
    }

    // Freeze metrics for the whole marquee run.
    _mBaseOverflow = math.max(0.0, fullW - _lastMaxWidth);
    final rightPad = math.max(0.0, _lastMaxWidth - fullW);
    _mGap = (willOverflow || !widget.forceMarquee)
        ? widget.marqueeGap
        : rightPad;
    _mTravel = fullW + _mGap;
    _mOffset = 0;
    _marqueeCycles = 0;

    if (_mTravel <= 0 || _mTravel.isNaN || _mTravel.isInfinite) {
      _startDeleting();
      return;
    }

    _phase = _Phase.marquee;
    _startMarquee();
  }

  // ---- marquee ----
  void _startMarquee() {
    _ticker?.dispose();
    _lastTick = Duration.zero;
    _ticker = createTicker(_onMarqueeTick)..start();
  }

  void _onMarqueeTick(Duration elapsed) {
    if (!mounted || _phase != _Phase.marquee) return;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    _mOffset += widget.marqueeVelocity * dt;

    if (_mOffset >= _mTravel) {
      final loopsCrossed = (_mOffset / _mTravel).floor();
      _mOffset -= _mTravel * loopsCrossed;
      _marqueeCycles += loopsCrossed;
      if (_marqueeCycles >= widget.marqueeLoops) {
        _finishMarquee();
        return;
      }
    }
    setState(() {});
  }

  void _finishMarquee() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _phase = _Phase.deleting;
    _mOffset = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startDeleting();
    });
  }

  // ---- deleting ----
  void _startDeleting() {
    _phase = _Phase.deleting;
    _timer?.cancel();
    if (_visible > 0) {
      _timer = Timer(widget.deleteSpeed, () {
        if (!mounted) return;
        setState(() => _visible--);
        _startDeleting();
      });
    } else {
      _timer = Timer(widget.pauseAfterDelete, () {
        if (!mounted) return;
        _firedFullCallbackThisCycle = false;
        if (widget.loop) {
          _resetAndStart();
        } else {
          setState(() => _phase = _Phase.waiting);
          widget.onLineDone?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }

  void _cancelAll() {
    _timer?.cancel();
    _timer = null;
    _ticker?.dispose();
    _ticker = null;
  }

  // ---- UI ----
  String _visibleText() =>
      _visible <= 0 ? '' : _graphemes.take(_visible).join();

  bool get _caretIsActive =>
      _phase == _Phase.typing || _phase == _Phase.deleting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastMaxWidth = constraints.maxWidth;

        final caretW = _caretReserveWidth();
        final caretH = _caretHeight();

        final partial = _visibleText();
        final full = _graphemes.join();
        final renderText =
            (_phase == _Phase.marquee || _phase == _Phase.pauseFull)
            ? full
            : partial;

        // Keep caret visible while typing/deleting.
        final currentWidth = _textWidth(renderText) + caretW;
        final baseOverflowCurrent = math.max(
          0.0,
          currentWidth - constraints.maxWidth,
        );

        final caretVisible = !widget.hideCursorWhenInactive || _caretIsActive;

        Widget single(String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t,
              style: widget.textStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
            Container(
              width: caretW,
              height: caretH,
              margin: const EdgeInsets.only(left: 2),
              color: caretVisible
                  ? (widget.textStyle.color ?? Colors.white)
                  : Colors.transparent,
            ),
          ],
        );

        final movingChild = (_phase == _Phase.marquee)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  single(full),
                  SizedBox(width: _mGap),
                  single(full),
                ],
              )
            : single(renderText);

        final dx = switch (_phase) {
          _Phase.waiting ||
          _Phase.typing ||
          _Phase.pauseFull ||
          _Phase.deleting => baseOverflowCurrent,
          _Phase.marquee => _mBaseOverflow + _mOffset,
        };

        final lineHeight = math.max(
          caretH,
          (widget.textStyle.fontSize ?? 14.0) * 1.25,
        );

        return SizedBox(
          height: lineHeight,
          width: double.infinity,
          child: Stack(
            children: [
              ClipRect(
                child: OverflowBox(
                  minWidth: 0,
                  maxWidth: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(-dx, 0),
                    child: movingChild,
                  ),
                ),
              ),
              if (widget.edgeFade && _phase == _Phase.marquee) ...[
                _EdgeFade(
                  width: widget.edgeFadeWidth,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  isLeft: true,
                ),
                _EdgeFade(
                  width: widget.edgeFadeWidth,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  isLeft: false,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({
    required this.width,
    required this.color,
    required this.isLeft,
  });

  final double width;
  final Color color;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            width: width,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
