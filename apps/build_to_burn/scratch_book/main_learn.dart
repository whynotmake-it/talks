// Scratch book for learning the render stack. Not part of the deck.
//
// Chapter 1: see when Flutter makes a frame, and which phases do work in it.
//
//   flutter run -d macos -t scratch_book/main_learn.dart
//
// Once a second the console prints what happened in that second:
//
//   frames  frames the UI thread began (a vsync the framework asked for)
//   raster  frames the raster thread finished (FrameTiming, from the engine)
//   build   build() calls of LearnApp
//   layout  performLayout() calls of the card
//   paint   paint() calls of the card
//
// Nothing on screen animates on its own, and the buttons have no ink
// splash, so every frame you see is one you caused.

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

var _frames = 0;
var _rasterized = 0;
var _builds = 0;
var _layouts = 0;
var _paints = 0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Called on every frame, after the tickers ran. It never asks for a frame
  // itself, so it only counts frames something else scheduled.
  SchedulerBinding.instance.addPersistentFrameCallback((_) => _frames++);

  // The engine reports finished raster frames in batches (~every 100 ms in
  // debug and profile).
  SchedulerBinding.instance.addTimingsCallback(
    (timings) => _rasterized += timings.length,
  );

  // A Timer is not a Ticker: it runs Dart code but schedules no frame.
  Timer.periodic(const Duration(seconds: 1), (_) {
    debugPrint(
      'frames $_frames  raster $_rasterized  '
      'build $_builds  layout $_layouts  paint $_paints',
    );
    _frames = 0;
    _rasterized = 0;
    _builds = 0;
    _layouts = 0;
    _paints = 0;
  });

  runApp(const LearnApp());
}

class LearnApp extends StatefulWidget {
  const LearnApp({super.key});

  @override
  State<LearnApp> createState() => _LearnAppState();
}

class _LearnAppState extends State<LearnApp>
    with SingleTickerProviderStateMixin {
  // Nothing listens to this controller, so nothing rebuilds or repaints when
  // it ticks. Its Ticker still asks for a frame on every vsync.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  var _blue = true;
  var _narrow = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTicker() {
    setState(() {
      if (_controller.isAnimating) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _builds++;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF1E1E1E),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Card(
              color: _blue ? const Color(0xFF2563EB) : const Color(0xFFEA580C),
              width: _narrow ? 200 : 300,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Button(
                  label: 'setState: new color',
                  onTap: () => setState(() => _blue = !_blue),
                ),
                const SizedBox(width: 16),
                _Button(
                  label: 'setState: narrower',
                  onTap: () => setState(() => _narrow = !_narrow),
                ),
                const SizedBox(width: 16),
                _Button(
                  label: _controller.isAnimating
                      ? 'Stop ticker'
                      : 'Start ticker',
                  onTap: _toggleTicker,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget is only a description. This one describes a colored card, and
/// hands the real work to [_RenderCard].
class _Card extends LeafRenderObjectWidget {
  const _Card({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCard(color, width);

  @override
  void updateRenderObject(BuildContext context, _RenderCard renderObject) {
    renderObject
      ..color = color
      ..width = width;
  }
}

/// The render object: it lives across frames, owns a size, and paints.
class _RenderCard extends RenderBox {
  _RenderCard(this._color, this._width);

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    // A new color needs a new recording, not new sizes.
    markNeedsPaint();
  }

  double _width;
  double get width => _width;
  set width(double value) {
    if (value == _width) return;
    _width = value;
    // A new width can change the size, so layout runs again (and paint
    // follows).
    markNeedsLayout();
  }

  @override
  void performLayout() {
    _layouts++;
    size = constraints.constrain(Size(_width, 120));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paints++;
    // This changes no pixel. It adds "draw a rounded rect" to a recording
    // (a Picture). The GPU draws it much later, on another floor.
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(offset & size, const Radius.circular(24)),
      Paint()..color = _color,
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF9CA3AF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFF3F4F6), fontSize: 16),
        ),
      ),
    );
  }
}
