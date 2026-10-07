import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart';

/// The demo frame from its layer tree to render passes, one stage slide per
/// [EngineStage], in beats:
///
/// - [EngineStage.scene]: the layer tree paint built, in Dart; its pictures
///   are in C++ already and Dart keeps a handle; the SceneBuilder copies the
///   layers across FFI and each picture snaps into place; the raster thread
///   takes the Scene.
/// - [EngineStage.displayList]: the raster thread walks the tree and writes
///   a DisplayList; read in order, it describes the screen; the backdrop
///   blur is one line in it.
/// - [EngineStage.passes]: Impeller reads that list into render passes, and
///   the backdrop blur ends the first one. The slide shows the finished plan
///   ([beat] 3) at once and announces the live demo.
///
/// The screen the list describes is sketched in outlines, not pixels:
/// nothing is drawn until the GPU.
///
/// Each beat plays once when it is reached forward; going back shows it
/// finished. Laid out at [size] and scaled by the stage card.
class EngineStageView extends StatefulWidget {
  const EngineStageView({required this.stage, required this.beat, super.key});

  final EngineStage stage;
  final int beat;

  static const size = Size(1360, 1000);

  @override
  State<EngineStageView> createState() => _EngineStageViewState();
}

class _EngineStageViewState extends State<EngineStageView>
    with SingleTickerProviderStateMixin {
  // The passes slide shows its finished plan at once, without a reveal.
  late final _t = AnimationController(
    vsync: this,
    duration: _duration(widget.stage, widget.beat),
    value: widget.stage == EngineStage.passes ? 1 : 0,
  )..forward();

  static Duration _duration(EngineStage stage, int beat) => Duration(
    milliseconds: switch ((stage, beat)) {
      (EngineStage.scene, 0) => 1600,
      (EngineStage.scene, 1) => 3600,
      (EngineStage.scene, 2) => 6000,
      (EngineStage.displayList, 1) => _ListStage.writeMs.round(),
      (EngineStage.displayList, 2) => _ListStage.readMs.round(),
      (EngineStage.passes, 3) => 2800,
      _ => 2200,
    },
  );

  @override
  void didUpdateWidget(EngineStageView old) {
    super.didUpdateWidget(old);
    if (old.stage == widget.stage && old.beat == widget.beat) return;
    _t.duration = _duration(widget.stage, widget.beat);
    if (old.stage == widget.stage && widget.beat > old.beat) {
      _t.forward(from: 0);
    } else {
      _t.value = 1;
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: EngineStageView.size,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final p = Palette.of(context);
          final beat = widget.beat;
          final t = _t.value;
          return DefaultTextStyle(
            style: mono(26, color: p.text),
            child: switch (widget.stage) {
              EngineStage.scene => _SceneStage(beat: beat, t: t),
              EngineStage.displayList => _ListStage(beat: beat, t: t),
              EngineStage.passes => _PassesStage(beat: beat, t: t),
            },
          );
        },
      ),
    );
  }
}

/// 0 before [a], 1 after [b], eased in between.
double _seg(double t, double a, double b) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Up, then down again, over [a]..[b].
double _bump(double t, double a, double b) =>
    math.sin(math.pi * ((t - a) / (b - a)).clamp(0.0, 1.0));

// What the pictures draw, as sketches on the demo screen.

/// One thing a picture draws, or an effect a layer applies, in the demo
/// screen's coordinates ([_screen]).
enum _Part {
  /// Picture ①: the ColoredBox page.
  page,

  /// The ClipRRect's rounded clip.
  clip,

  /// Where the BackdropFilter blurs what's behind.
  blur,

  /// Picture ②: the frost tint and the field's rounded background.
  card,

  /// Picture ③: the field's text.
  text,

  /// Picture ④: the caret.
  caret,
}

/// The demo screen's size, in sketch coordinates.
const _screen = Rect.fromLTWH(0, 0, 300, 560);
final _cardShape = RRect.fromLTRBR(
  40,
  230,
  260,
  330,
  const Radius.circular(18),
);
final _fieldShape = RRect.fromLTRBR(
  56,
  252,
  244,
  308,
  const Radius.circular(10),
);
const _caretRect = Rect.fromLTWH(70, 262, 4, 36);

/// Draws [parts] at their opacity, from [source] fitted into the box.
class _SketchPainter extends CustomPainter {
  _SketchPainter({
    required this.parts,
    required this.source,
    required this.ink,
    this.blurHeat = 0,
  });

  final Map<_Part, double> parts;
  final Rect source;

  /// The color of text and outlines without a widget color.
  final Color ink;

  /// 0..1: the blur area turns to heat.
  final double blurHeat;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / source.width,
      size.height / source.height,
    );
    canvas
      ..save()
      ..translate(
        (size.width - source.width * scale) / 2,
        (size.height - source.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-source.left, -source.top);
    final px = 1 / scale;

    Paint stroke(Color color, double opacity, [double width = 3]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * px
      ..color = color.withValues(alpha: opacity);

    Paint fill(Color color, double opacity) =>
        Paint()..color = color.withValues(alpha: opacity);

    for (final MapEntry(key: part, value: opacity) in parts.entries) {
      if (opacity <= 0) continue;
      final o = opacity.clamp(0.0, 1.0);
      switch (part) {
        case _Part.page:
          final color = DemoWidget.coloredBox.color!;
          canvas
            ..drawRect(_screen, fill(color, .1 * o))
            ..drawRect(_screen.deflate(1.5 * px), stroke(color, o));
        case _Part.clip:
          final color = DemoWidget.clipRRect.color!;
          _dashedRRect(canvas, _cardShape, stroke(color, o), 10 * px);
        case _Part.blur:
          final color = Color.lerp(
            DemoWidget.backdropFilter.color,
            heat,
            blurHeat,
          )!;
          canvas
            ..save()
            ..clipRRect(_cardShape);
          final hatch = stroke(color, .6 * o, 2 + 2 * blurHeat);
          final box = _cardShape.outerRect;
          for (var x = box.left - box.height; x < box.right; x += 14) {
            canvas.drawLine(
              Offset(x, box.bottom),
              Offset(x + box.height, box.top),
              hatch,
            );
          }
          canvas.restore();
        case _Part.card:
          canvas
            ..drawRRect(
              _cardShape,
              fill(DemoWidget.container.color!, .12 * o),
            )
            ..drawRRect(_cardShape, stroke(DemoWidget.container.color!, o))
            ..drawRRect(_fieldShape, stroke(DemoWidget.textField.color!, o));
        case _Part.text:
          TextPainter(
              text: TextSpan(
                text: 'Search',
                style: archivo(
                  26,
                  weight: 500,
                  color: DemoWidget.textField.color!.withValues(alpha: o),
                ),
              ),
              textDirection: TextDirection.ltr,
            )
            ..layout()
            ..paint(canvas, const Offset(82, 263))
            ..dispose();
        case _Part.caret:
          canvas.drawRect(_caretRect, fill(DemoWidget.textField.color!, o));
      }
    }
    canvas.restore();
  }

  void _dashedRRect(Canvas canvas, RRect shape, Paint paint, double dash) {
    final path = Path()..addRRect(shape);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 2) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SketchPainter old) =>
      !mapEquals(parts, old.parts) ||
      source != old.source ||
      ink != old.ink ||
      blurHeat != old.blurHeat;
}

// The demo's layer tree, as on slide 7, one row per layer.

class _Layer {
  const _Layer(
    this.dart,
    this.cpp,
    this.depth, {
    this.widget,
    this.picture,
    this.call = '',
  });

  /// The framework's class, in Dart.
  final String dart;

  /// The engine's class the SceneBuilder makes from it, in C++.
  final String cpp;
  final int depth;
  final DemoWidget? widget;
  final int? picture;

  /// The SceneBuilder call that sends it across.
  final String call;

  bool get isPicture => picture != null;
}

const _layers = [
  _Layer('OffsetLayer', 'TransformLayer', 0, call: 'pushOffset'),
  _Layer('Picture', 'DisplayListLayer', 1, picture: 1, call: 'addPicture'),
  _Layer(
    'ClipRRectLayer',
    'ClipRRectLayer',
    1,
    widget: DemoWidget.clipRRect,
    call: 'pushClipRRect',
  ),
  _Layer(
    'BackdropFilterLayer',
    'BackdropFilterLayer',
    2,
    widget: DemoWidget.backdropFilter,
    call: 'pushBackdropFilter',
  ),
  _Layer('Picture', 'DisplayListLayer', 3, picture: 2, call: 'addPicture'),
  _Layer(
    'OffsetLayer',
    'TransformLayer',
    3,
    widget: DemoWidget.textField,
    call: 'pushOffset',
  ),
  _Layer('Picture', 'DisplayListLayer', 4, picture: 3, call: 'addPicture'),
  _Layer(
    'OffsetLayer',
    'TransformLayer',
    4,
    widget: DemoWidget.textField,
    call: 'pushOffset',
  ),
  _Layer('Picture', 'DisplayListLayer', 5, picture: 4, call: 'addPicture'),
];

const _rowTop = 120.0;
const _rowStep = 76.0;
const _rowHeight = 60.0;
const _indent = 34.0;
const _columnWidth = 560.0;

/// The left column, the FFI line, and the right column.
const _dartX = 0.0;
const _ffiX = 680.0;
const _cppX = 800.0;

double _rowY(int row) => _rowTop + row * _rowStep;
double _indentX(int row) => _layers[row].depth * _indent;

Color _layerColor(_Layer layer, Palette p) =>
    layer.widget?.color ?? p.textTertiary;

Widget _at(double x, double y, Widget child, {double opacity = 1}) =>
    Positioned(
      left: x,
      top: y,
      child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
    );

Widget _header(String text, Palette p) =>
    Text(text, style: mono(26, weight: 700, color: p.textTertiary));

/// A layer as a box in its widget's color, like slide 6's pushes.
Widget _layerBox(String name, Color color, Palette p, {double width = 400}) =>
    Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color, width: 3),
      ),
      child: Text(
        name,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: mono(26, weight: 600, color: p.text),
      ),
    );

Widget _badge(int number, {required Color background, required Color fg}) =>
    Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text('$number', style: mono(22, weight: 700, color: fg)),
    );

const _pictureWidth = 210.0;

/// A picture: its number and its name.
Widget _picture(int number, Palette p, {Color? border}) => Container(
  width: _pictureWidth,
  height: _rowHeight,
  padding: const EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(
    color: p.surface,
    border: Border.all(color: border ?? p.text, width: border == null ? 3 : 5),
  ),
  child: Row(
    children: [
      _badge(number, background: p.text, fg: p.surface),
      const SizedBox(width: 10),
      Text('Picture', style: mono(24, weight: 600, color: p.text)),
    ],
  ),
);

/// What Dart keeps of a picture once its recording is in C++: a handle.
Widget _handle(int number, Palette p) => Container(
  width: _pictureWidth,
  height: _rowHeight,
  padding: const EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(
    color: p.surface,
    border: Border.all(color: p.textTertiary, width: 3),
  ),
  child: Row(
    children: [
      _badge(number, background: p.textSecondary, fg: p.surface),
      const SizedBox(width: 10),
      Text('Picture', style: mono(24, weight: 600, color: p.textSecondary)),
      const Spacer(),
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: p.text, shape: BoxShape.circle),
      ),
    ],
  ),
);

/// The layer tree, then a Scene.
class _SceneStage extends StatelessWidget {
  const _SceneStage({required this.beat, required this.t});

  final int beat;
  final double t;

  /// Where each picture waits in C++ before its layer arrives: on its row,
  /// but not yet in place.
  static const _unplaced = {
    1: (260.0, -.06),
    2: (40.0, .05),
    3: (300.0, -.04),
    4: (120.0, .07),
  };

  /// Beat 1: when picture [k] (0-3) crosses.
  static (double, double) _crossWindow(int k) {
    final a = .06 + k * .2;
    return (a, a + .3);
  }

  /// Beat 2: when the SceneBuilder sends layer [row].
  static (double, double) _callWindow(int row) {
    final a = .03 + row * .1;
    return (a, a + .13);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pictureRows = [
      for (final (row, layer) in _layers.indexed)
        if (layer.isPicture) row,
    ];

    double crossed(int k) {
      if (beat > 1) return 1;
      if (beat < 1) return 0;
      final (a, b) = _crossWindow(k);
      return _seg(t, a, b);
    }

    double copied(int row) {
      if (beat > 2) return 1;
      if (beat < 2) return 0;
      final (a, b) = _callWindow(row);
      return _seg(t, a, b);
    }

    // Beat 0 shows only the Dart tree, its rows coming in one by one.
    double rowIn(int row) => beat > 0 ? 1 : _seg(t, row * .06, row * .06 + .3);
    final engine = switch (beat) {
      0 => 0.0,
      1 => _seg(t, 0, .15),
      _ => 1.0,
    };
    final handoff = beat >= 3 ? _seg(t, 0, .6) : 0.0;
    final dartFade = 1 - .7 * handoff;

    // The SceneBuilder call being made right now, beat 2.
    var call = '';
    var callOpacity = 0.0;
    if (beat == 2) {
      for (final (row, layer) in _layers.indexed) {
        final (a, b) = _callWindow(row);
        if (t >= a && t <= b) {
          call = 'SceneBuilder.${layer.call}()';
          callOpacity = math.min(1, 1.6 * _bump(t, a, b));
        }
      }
    }

    // Each picture's position and turn on the C++ side.
    (Offset, double) pictureAt(int row) {
      final number = _layers[row].picture!;
      final k = pictureRows.indexOf(row);
      final (dx, turn) = _unplaced[number]!;
      final from = Offset(_dartX + _indentX(row), _rowY(row));
      final waiting = Offset(_cppX + dx, _rowY(row));
      final placed = Offset(_cppX + _indentX(row), _rowY(row));
      final c = Curves.easeInOutCubic.transform(crossed(k));
      final s = Curves.easeInOutCubic.transform(copied(row));
      final at = Offset.lerp(Offset.lerp(from, waiting, c), placed, s)!;
      return (at, turn * c * (1 - s));
    }

    final children = <Widget>[
      _at(_dartX, 20, _header('DART · UI THREAD', p), opacity: dartFade),
      _at(_cppX, 20, _header('C++ · ENGINE', p), opacity: engine),
      _at(_ffiX - 26, 20, _header('FFI', p), opacity: engine),
      Positioned.fill(
        child: CustomPaint(
          painter: _ScenePainter(
            p: p,
            boundary: engine,
            links: [
              for (final (k, row) in pictureRows.indexed)
                if (crossed(k) > 0)
                  (
                    Offset(
                      _dartX + _indentX(row) + _pictureWidth - 22,
                      _rowY(row) + _rowHeight / 2,
                    ),
                    pictureAt(row).$1 + const Offset(0, _rowHeight / 2),
                    _seg(crossed(k), .3, .6) * dartFade,
                  ),
            ],
          ),
        ),
      ),
    ];

    // Dart: the layers stay; each picture leaves a handle behind.
    for (final (row, layer) in _layers.indexed) {
      final x = _dartX + _indentX(row);
      if (layer.isPicture) {
        children.add(
          _at(
            x,
            _rowY(row),
            _handle(layer.picture!, p),
            opacity: _seg(crossed(pictureRows.indexOf(row)), .2, .5) * dartFade,
          ),
        );
        continue;
      }
      children.add(
        _at(
          x,
          _rowY(row),
          _layerBox(
            layer.dart,
            _layerColor(layer, p),
            p,
            width: _columnWidth - _indentX(row),
          ),
          opacity: dartFade * rowIn(row),
        ),
      );
    }

    // C++: the layers copied across.
    for (final (row, layer) in _layers.indexed) {
      if (layer.isPicture) continue;
      final c = copied(row);
      if (c <= 0) continue;
      final width = _columnWidth - _indentX(row);
      final flyX = lerpDouble(
        _dartX + _indentX(row),
        _cppX + _indentX(row),
        Curves.easeInOutCubic.transform(c),
      )!;
      final color = _layerColor(layer, p);
      children.add(
        _at(
          flyX,
          _rowY(row),
          Stack(
            children: [
              Opacity(
                opacity: 1 - _seg(c, .4, .6),
                child: _layerBox(layer.dart, color, p, width: width),
              ),
              Opacity(
                opacity: _seg(c, .4, .6),
                child: _layerBox(layer.cpp, color, p, width: width),
              ),
            ],
          ),
          opacity: _seg(c, 0, .15),
        ),
      );
    }

    // The pictures, on top: in Dart, crossing, waiting, then in place.
    for (final row in pictureRows) {
      final (at, turn) = pictureAt(row);
      children.add(
        Positioned(
          left: at.dx,
          top: at.dy,
          child: Opacity(
            opacity: rowIn(row),
            child: Transform.rotate(
              angle: turn,
              child: _picture(
                _layers[row].picture!,
                p,
                border: copied(row) > .5 ? p.accent : null,
              ),
            ),
          ),
        ),
      );
    }

    // Beat 2: the call on its way.
    if (callOpacity > 0) {
      children.add(
        Positioned(
          left: _ffiX - 300,
          width: 600,
          top: 62,
          child: Opacity(
            opacity: callOpacity,
            child: Text(
              call,
              textAlign: TextAlign.center,
              style: mono(26, weight: 700, color: p.accent),
            ),
          ),
        ),
      );
    }

    // Beat 3: Scene, handed to the raster thread.
    if (handoff > 0) {
      const frame = Rect.fromLTRB(_cppX - 20, _rowTop - 20, 1380, 808);
      children
        ..add(
          Positioned.fromRect(
            rect: frame,
            child: Opacity(
              opacity: handoff,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: p.accent, width: 5),
                ),
              ),
            ),
          ),
        )
        ..add(
          _at(
            frame.right - 160,
            frame.top - 52,
            Container(
              width: 160,
              height: 52,
              alignment: Alignment.center,
              color: p.accent,
              child: Text(
                'Scene',
                style: mono(28, weight: 700, color: p.onAccent),
              ),
            ),
            opacity: handoff,
          ),
        )
        ..add(
          _at(
            frame.left,
            frame.bottom + 18,
            Text(
              '↓ raster thread',
              style: mono(28, weight: 700, color: p.accent),
            ),
            opacity: _seg(t, .3, .8),
          ),
        );
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }
}

/// Slide 8's lines: the FFI boundary, and each handle's link to its picture.
class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.p, required this.boundary, required this.links});

  final Palette p;

  /// The FFI line's opacity.
  final double boundary;

  /// From a handle to its picture, at an opacity.
  final List<(Offset, Offset, double)> links;

  @override
  void paint(Canvas canvas, Size size) {
    if (boundary > 0) {
      _dashed(
        canvas,
        const Offset(_ffiX, 60),
        const Offset(_ffiX, 820),
        Paint()
          ..color = p.borderStrong.withValues(alpha: boundary)
          ..strokeWidth = 4,
        dash: 18,
      );
    }
    for (final (from, to, opacity) in links) {
      if (opacity <= 0) continue;
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = p.text.withValues(alpha: .6 * opacity)
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      !listEquals(links, old.links) || boundary != old.boundary || p != old.p;
}

void _dashed(
  Canvas canvas,
  Offset from,
  Offset to,
  Paint paint, {
  double dash = 12,
}) {
  final length = (to - from).distance;
  if (length == 0) return;
  final dir = (to - from) / length;
  for (var d = 0.0; d < length; d += dash * 2) {
    canvas.drawLine(
      from + dir * d,
      from + dir * math.min(d + dash, length),
      paint,
    );
  }
}

// The DisplayList the raster thread writes from the tree.

class _Op {
  const _Op(this.text, this.depth, this.row, {this.faint = false, this.part});

  final String text;
  final int depth;

  /// The layer in [_layers] that writes it.
  final int row;

  /// Bookkeeping for an offset, drawn faint.
  final bool faint;

  /// What it adds to the screen, if anything.
  final _Part? part;
}

const _ops = [
  _Op('save · translate', 0, 0, faint: true),
  _Op('draw picture ①', 1, 1, part: _Part.page),
  _Op('save · clipRRect', 1, 2, part: _Part.clip),
  _Op('saveLayer · backdrop blur', 2, 3, part: _Part.blur),
  _Op('draw picture ②', 3, 4, part: _Part.card),
  _Op('save · translate', 3, 5, faint: true),
  _Op('draw picture ③', 4, 6, part: _Part.text),
  _Op('save · translate', 4, 7, faint: true),
  _Op('draw picture ④', 5, 8, part: _Part.caret),
  _Op('restore', 4, 7, faint: true),
  _Op('restore', 3, 5, faint: true),
  _Op('restore', 2, 3),
  _Op('restore', 1, 2),
  _Op('restore', 0, 0, faint: true),
];

/// The backdrop blur's saveLayer in [_ops].
const _blurOpen = 3;

const _listX = 760.0;
const _opTop = 120.0;
const _opStep = 50.0;
const _opIndent = 30.0;

double _opY(int index) => _opTop + index * _opStep;

Widget _opText(_Op op, Palette p, {Color? color, bool bold = false}) => Text(
  op.text,
  maxLines: 1,
  softWrap: false,
  style: mono(
    28,
    weight: bold ? 700 : 450,
    color: color ?? (op.faint ? p.textTertiary : p.text),
  ),
);

/// The C++ layer tree, as slide 8 left it.
List<Widget> _cppTree(
  Palette p, {
  double opacity = 1,
  int? highlight,
  double highlightOpacity = 0,
}) => [
  for (final (row, layer) in _layers.indexed)
    _at(
      _indentX(row),
      _rowY(row),
      Stack(
        children: [
          if (layer.isPicture)
            _picture(layer.picture!, p)
          else
            _layerBox(
              layer.cpp,
              _layerColor(layer, p),
              p,
              width: _columnWidth - _indentX(row),
            ),
          if (row == highlight)
            Positioned.fill(
              child: Opacity(
                opacity: highlightOpacity.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: p.accent, width: 6),
                  ),
                ),
              ),
            ),
        ],
      ),
      opacity: opacity,
    ),
];

/// Where slide 9 sketches the screen the list describes.
const _miniScreen = Rect.fromLTWH(160, 120, 330, 616);

/// Slide 9: DisplayList.
class _ListStage extends StatelessWidget {
  const _ListStage({required this.beat, required this.t});

  final int beat;
  final double t;

  // In milliseconds: a slow, steady step per line, so it can be followed
  // while it's being said, but quick fades.
  static const _fadeMs = 450.0;
  static const _writeStartMs = 300.0;
  static const _writeStepMs = 1300.0;
  static const _readStartMs = 800.0;
  static const _readStepMs = 900.0;

  /// How long beat 1 writes and beat 2 reads.
  static const _flattenMs = 900.0;
  static double get writeMs =>
      _writeStartMs + _ops.length * _writeStepMs + _fadeMs + _flattenMs;
  static double get readMs =>
      _readStartMs + _ops.length * _readStepMs + _fadeMs;

  /// Beat 1: when line [index] is written.
  static (double, double) _writeWindow(int index) {
    final a = (_writeStartMs + index * _writeStepMs) / writeMs;
    return (a, a + _fadeMs / writeMs);
  }

  /// Beat 2: when line [index] is read onto the screen.
  static (double, double) _readWindow(int index) {
    final a = (_readStartMs + index * _readStepMs) / readMs;
    return (a, a + _fadeMs / readMs);
  }

  /// Beat 1 or 2: the line started last, until its step is over.
  int? _current() {
    if (beat != 1 && beat != 2) return null;
    final (start, step, total) = beat == 1
        ? (_writeStartMs, _writeStepMs, writeMs)
        : (_readStartMs, _readStepMs, readMs);
    final index = ((t * total - start) / step).floor();
    return index >= 0 && index < _ops.length ? index : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    // Beat 0 arrives with the tree and an empty list.
    double written(int index) {
      if (beat > 1) return 1;
      if (beat < 1) return 0;
      final (a, b) = _writeWindow(index);
      return _seg(t, a, b);
    }

    double read(int index) {
      if (beat > 2) return 1;
      if (beat < 2) return 0;
      final (a, b) = _readWindow(index);
      return _seg(t, a, b);
    }

    // The line being written (beat 1) or read (beat 2) right now.
    final active = _current();
    const activeOpacity = 1.0;

    // Once written, the indents go: a flat list, not a tree.
    final flat = switch (beat) {
      < 1 => 0.0,
      1 => _seg(t, 1 - _flattenMs / writeMs, 1),
      _ => 1.0,
    };

    final screen = switch (beat) {
      < 2 => 0.0,
      2 => _seg(t, 0, 600 / readMs),
      _ => 1.0,
    };
    final focus = beat >= 3 ? _seg(t, 0, .6) : 0.0;

    final children = <Widget>[
      _at(0, 20, _header('THE SCENE · RASTER THREAD', p), opacity: 1 - screen),
      _at(0, 20, _header('WHAT THE LIST DESCRIBES', p), opacity: screen),
      _at(_listX, 20, _header('DisplayList', p)),
      ..._cppTree(
        p,
        opacity: 1 - _seg(screen, 0, .5),
        highlight: beat == 1 && active != null ? _ops[active].row : null,
        highlightOpacity: activeOpacity,
      ),
    ];

    if (screen > 0) {
      children.add(
        Positioned.fromRect(
          rect: _miniScreen,
          child: Opacity(
            opacity: screen,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: p.borderStrong, width: 3),
              ),
              child: CustomPaint(
                painter: _SketchPainter(
                  parts: {
                    for (final (index, op) in _ops.indexed)
                      if (op.part case final part?) part: read(index),
                  },
                  source: _screen,
                  ink: p.text,
                  blurHeat: focus,
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final (index, op) in _ops.indexed) {
      final w = written(index);
      if (w <= 0) continue;
      // Only the blur's own line turns red, not its restore.
      final blur = index == _blurOpen;
      children.add(
        _at(
          _listX + op.depth * _opIndent * (1 - flat) + 30 * (1 - w),
          _opY(index),
          _opText(
            op,
            p,
            color: index == active
                ? p.accent
                : blur && focus > .5
                ? heat
                : null,
            bold: index == active || (blur && focus > .5),
          ),
          opacity: w,
        ),
      );
    }

    // Beat 2: a dot jumps from line to line as the list is read.
    if (beat == 2 && active != null) {
      children.add(
        _at(
          _listX - 36,
          _opY(active) + 10,
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
          ),
        ),
      );
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }
}

/// Slide 10: the list, read into render passes.
class _PassesStage extends StatelessWidget {
  const _PassesStage({required this.beat, required this.t});

  final int beat;
  final double t;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    // Which line the reader is at, as a fractional index.
    final read = switch (beat) {
      0 => lerpDouble(0, 2, _seg(t, .1, .9))!,
      1 => lerpDouble(2, _blurOpen.toDouble(), _seg(t, 0, .4))!,
      2 => _blurOpen.toDouble(),
      _ => lerpDouble(
        _blurOpen.toDouble(),
        _ops.length - 1.0,
        _seg(t, .1, .9),
      )!,
    };
    final cut = switch (beat) {
      0 => 0.0,
      1 => _seg(t, .35, .7),
      _ => 1.0,
    };
    final blurGroup = switch (beat) {
      < 2 => 0.0,
      2 => _seg(t, 0, .7),
      _ => 1.0,
    };
    final pass2 = beat >= 3 ? _seg(t, .1, .9) : 0.0;

    const bracketX = _listX - 40;
    final pass1Bottom = beat == 0
        ? _opY(0) + (read + 1) * _opStep - 10
        : _opY(_blurOpen) - 10;
    final pass2Top = _opY(_blurOpen);
    final pass2Bottom = lerpDouble(
      pass2Top + _opStep - 10,
      _opY(_ops.length - 1) + _opStep - 10,
      pass2,
    )!;

    final children = <Widget>[
      _at(0, 20, _header('IMPELLER · RASTER THREAD', p)),
      _at(_listX, 20, _header('DisplayList', p)),
      for (final (index, op) in _ops.indexed)
        _at(
          _listX,
          _opY(index),
          _opText(
            op,
            p,
            color: index == _blurOpen && cut > .5 ? heat : null,
            bold: index == _blurOpen && cut > .5,
          ),
        ),
      // The reader.
      _at(
        _listX - 26,
        _opY(0) + read * _opStep + 4,
        Text('▶', style: mono(24, color: p.accent)),
        opacity: switch (beat) {
          2 => .3,
          >= 3 => 0,
          _ => 1,
        },
      ),
      // The pass behind the blur.
      _bracket(_opY(0) - 6, pass1Bottom, p.accent),
      _at(
        0,
        (_opY(0) + pass1Bottom) / 2 - 36,
        SizedBox(
          width: bracketX - 30,
          child: Text(
            'Pass',
            textAlign: TextAlign.right,
            style: mono(30, weight: 700, height: 1.25, color: p.accent),
          ),
        ),
      ),
    ];

    if (cut > 0) {
      final y = _opY(_blurOpen) - 6;
      children.add(
        Positioned.fill(
          child: CustomPaint(
            painter: _CutPainter(
              from: Offset(lerpDouble(_listX, 300, cut)!, y),
              to: Offset(lerpDouble(_listX, 1360, cut)!, y),
            ),
          ),
        ),
      );
    }

    if (blurGroup > 0) {
      children.add(
        _at(
          bracketX - 30 - 3 * 150 + 10,
          _opY(_blurOpen) + 40,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Blur · 3 passes',
                style: mono(28, weight: 700, color: heat),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, name) in [
                    'shrink',
                    'vertical',
                    'horiz.',
                  ].indexed)
                    Opacity(
                      opacity: _seg(blurGroup, i * .2, i * .2 + .5),
                      child: Container(
                        width: 140,
                        height: 56,
                        margin: const EdgeInsets.only(left: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: heat.withValues(alpha: .12),
                          border: Border.all(color: heat, width: 3),
                        ),
                        child: Text(
                          name,
                          style: mono(24, weight: 600, color: p.text),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          opacity: blurGroup,
        ),
      );
    }

    if (pass2 > 0) {
      children
        ..add(_bracket(pass2Top, pass2Bottom, p.accent, opacity: pass2))
        ..add(
          _at(
            0,
            _opY(8) - 10,
            SizedBox(
              width: bracketX - 30,
              child: Text(
                'New pass',
                textAlign: TextAlign.right,
                style: mono(30, weight: 700, height: 1.25, color: p.accent),
              ),
            ),
            opacity: _seg(pass2, .3, .8),
          ),
        );
    }

    // The finished plan leads into the live demo.
    if (beat >= 3) {
      children.add(
        Positioned(
          right: 0,
          top: 900,
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: heat,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'NEXT: LIVE ON THE PHONE',
                style: mono(28, weight: 700, color: heat),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// A pass's bracket beside the list, from [top] to [bottom].
  static Widget _bracket(
    double top,
    double bottom,
    Color color, {
    double opacity = 1,
  }) => Positioned(
    left: _listX - 50,
    top: top,
    width: 22,
    height: math.max(0, bottom - top),
    child: Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: 8),
            top: BorderSide(color: color, width: 4),
            bottom: BorderSide(color: color, width: 4),
          ),
        ),
      ),
    ),
  );
}

/// Where the blur cuts the list: a dashed line across.
class _CutPainter extends CustomPainter {
  _CutPainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    _dashed(
      canvas,
      from,
      to,
      Paint()
        ..color = heat
        ..strokeWidth = 5,
      dash: 16,
    );
  }

  @override
  bool shouldRepaint(_CutPainter old) => from != old.from || to != old.to;
}
