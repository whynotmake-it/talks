import 'package:flutter/material.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class RenderingSlide6 extends FlutterDeckSlideWidget {
  const RenderingSlide6({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/rendering-6',
          speakerNotes: jesperSlideNotesHeader,
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
      mainContent: CodeHighlight(
        code: '''
in vec2 vUV;       // interpolated across the stretched quad
in vec4 vColor;    // sRGB color + base alpha
out vec4 frag;

void main() {
  // Unit-circle mask + smooth weight in local (u,v)
  float r2 = dot(vUV, vUV);
  if (r2 > 1.0) discard;

  float w = exp(-K * r2);                 // cheap circular falloff
  float a = vColor.a * w;
  if (a < 2.0/255.0) discard;

  // Premultiplied output; blend state is (ONE, ONE_MINUS_SRC_ALPHA)
  frag = vec4(vColor.rgb * w, a);
}
  ''',
        filename: 'fragment.glsl',
      ),

      secondaryContent: Image.asset(
        'assets/frag.png',
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
