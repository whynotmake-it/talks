import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class RenderingSlide2 extends FlutterDeckSlideWidget {
  const RenderingSlide2({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/rendering-2',
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
// --- P0: pos.xyz + packed quat ---
writeTexel(0, px, py, pz, quatPackedF32);

// --- P1: scale.xyz + packed color ---
writeTexel(1, sx, sy, sz, colorPackedF32);

// --- P2..P4: 12 SH floats (R,G,B × 4 coeffs) ---
writeTexel(2, sh[0], sh[1], sh[2], sh[3]);
writeTexel(3, sh[4], sh[5], sh[6], sh[7]);
writeTexel(4, sh[8], sh[9], sh[10], sh[11]);

  ''',
        fileName: 'splat_source.dart',
      ),

      secondaryContent: Image.asset(
        'assets/splat_texture.png',
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
