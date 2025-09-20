import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class RenderingSlide1 extends FlutterDeckSlideWidget {
  const RenderingSlide1({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/rendering-1',
          // steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);

    return ContentSlideTemplate(
      title: const Text(
        'Render Journey',
        textAlign: TextAlign.left,
      ),
      mainContent: FlutterDeckCodeHighlight(
        textStyle: theme.textTheme.bodyMedium,
        code: '''

  // Returns: 
  // [0..11 pos]
  // [12..23 scale]
  // [24..27 color]
  // [28..31 quat]
  // [32..79 SH]
  // [80..127 reserved]

  Uint8List processPlyBuffer(Uint8List inputBuffer) {
  ...
  }
  ''',
        fileName: 'file_processor.dart',
      ),

      secondaryContent: Image.asset(
        'assets/binary_splats.png',
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
