import 'package:flutter/widgets.dart';

/// Archivo's x-height, as a fraction of the font size.
const _xHeight = .52;

/// A small mark, like a bullet or a dot, centered on the x-height of text at
/// [fontSize].
///
/// It reports an alphabetic baseline, so in a [Row] with
/// [CrossAxisAlignment.baseline] it lines up with the text next to it.
class InlineMark extends StatelessWidget {
  const InlineMark({
    required this.fontSize,
    required this.size,
    required this.child,
    super.key,
  });

  final double fontSize;

  /// The height of [child].
  final double size;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, height: 1),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            // The placeholder sits on the baseline; lift it so its center
            // meets the middle of the x-height.
            child: Transform.translate(
              offset: Offset(0, size / 2 - fontSize * _xHeight / 2),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
