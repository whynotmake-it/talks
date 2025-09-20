import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';
import 'package:flutter_deck/src/theme/widgets/flutter_deck_code_highlight_theme.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/default.dart';
import 'package:flutter_highlight/themes/vs2015.dart';

/// A scrollable version of FlutterDeckCodeHighlight for long code snippets.
///
/// This widget wraps the standard FlutterDeckCodeHighlight in a scrollable
/// container, making it suitable for displaying longer code that might not
/// fit in the available screen space.
///
/// To customize the style of the widget, use [FlutterDeckCodeHighlightTheme].
///
/// Example:
///
/// ```dart
/// FlutterDeckCodeHighlightTheme(
///   data: FlutterDeckCodeHighlightThemeData(
///     backgroundColor: Colors.black87,
///     textStyle: FlutterDeckTheme.of(context).textTheme.bodyMedium,
///   ),
///   child: const ScrollableCodeHighlight(
///     code: '<...>',
///     fileName: 'example.dart',
///     language: 'dart',
///     maxHeight: 400,
///   ),
/// );
/// ```
class ScrollableCodeHighlight extends StatelessWidget {
  /// Creates a scrollable syntax highlighting widget for displaying code.
  ///
  /// Will use [vs2015Theme] for dark theme and [defaultTheme] for light theme.
  ///
  /// For a list of all available [language] values, see:
  /// https://github.com/git-touch/highlight.dart/tree/master/highlight/lib/languages
  const ScrollableCodeHighlight({
    required String code,
    String language = 'dart',
    String? fileName,
    TextStyle? textStyle,
    double? maxHeight,
    super.key,
  }) : _code = code,
       _fileName = fileName,
       _language = language,
       _textStyle = textStyle,
       _maxHeight = maxHeight;

  final String _code;
  final String? _fileName;
  final String _language;
  final TextStyle? _textStyle;
  final double? _maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckCodeHighlightTheme.of(context);
    final textStyle = _textStyle == null || _textStyle!.inherit
        ? theme.textStyle?.merge(_textStyle) ?? _textStyle
        : _textStyle;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_fileName != null) ...[
              Text(_fileName!, style: textStyle),
              const SizedBox(height: 4),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _maxHeight ?? 400,
              ),
              child: SingleChildScrollView(
                child: HighlightView(
                  _code,
                  language: _language,
                  padding: const EdgeInsets.all(16),
                  textStyle: textStyle,
                  theme: Theme.of(context).brightness == Brightness.dark
                      ? vs2015Theme
                      : defaultTheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}