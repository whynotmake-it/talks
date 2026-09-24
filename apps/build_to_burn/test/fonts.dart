import 'package:flutter/services.dart';

/// Loads the bundled fonts, so tests lay out with real glyphs instead of the
/// test font's 1em-wide squares.
Future<void> loadDeckFonts() async {
  for (final (family, file) in [
    ('Archivo', 'Archivo-VariableFont_wdth,wght.ttf'),
    ('JetBrains Mono', 'JetBrainsMono-VariableFont_wght.ttf'),
  ]) {
    await (FontLoader(
      family,
    )..addFont(rootBundle.load('assets/fonts/$file'))).load();
  }
}
