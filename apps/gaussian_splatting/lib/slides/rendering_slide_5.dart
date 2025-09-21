import 'package:flutter/material.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class RenderingSlide5 extends FlutterDeckSlideWidget {
  const RenderingSlide5({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/rendering-5',
          // steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    FlutterDeckTheme.of(context);

    return ContentSlideTemplate(
      title: const Text(
        'Render Journey',
        textAlign: TextAlign.left,
      ),
      mainContent: CodeHighlight(
        code: '''
// Inputs
in vec3 aPosition;                  // (x,y) ∈ {-1,+1}, z = local splat index
uniform sampler2D u_texture;        // atlas: 5 texels per splat, 512 splats/row
uniform usampler2D u_orderTexture;  // permutation (draw order)
uniform mat4 uViewProj;
uniform vec2 uViewport;
uniform int  uSplatCount;
const int BATCH = 128;

// Outputs to fragment
out vec2 vUV;        // unit-square coords (become unit-circle in FS)
out vec4 vColor;     // sRGB color, alpha from data/SH

void main() {
  // 1) Which splat does this vertex belong to?
  int slot = gl_InstanceID * BATCH + int(aPosition.z + 0.5);

  // 2) slot → splat id (indirection through order texture)
  ivec2 orderUV = ivec2(slot & 0x1ff, slot >> 9); // %512, /512
  int id = int(texelFetch(u_orderTexture, orderUV, 0).r);

  // 3) id → atlas coords (5 texels per splat, 512 per row)
  ivec2 baseUV = ivec2((id & 0x1ff) * 5, id >> 9);
  vec4 P0 = texelFetch(u_texture, baseUV + ivec2(0,0), 0); // pos.xyz + quat(u32)
  vec4 P1 = texelFetch(u_texture, baseUV + ivec2(1,0), 0); // scale.xyz + color(u32)
  // (optionally: SH in baseUV+(2..4))

  // 4) Decode attributes
  vec3  centerWS = P0.xyz;
  mat3  R        = quatToMat3(unpackQuat(P0.w));
  vec3  sigma    = P1.xyz;
  vec4  baseRGBA = unpackRGBA8(P1.w); // sRGB color, alpha

  // 5) Project ellipsoid → screen ellipse axes (pixels)

  // 6) Place the corner on the stretched/rotated quad

  vUV    = corner;                   // unit square → FS does circular falloff
  vColor = applySHIfEnabled(baseRGBA, centerWS); // optional SH tint
}

  ''',
        filename: 'vertex.glsl',
      ),

      secondaryContent: Image.asset(
        'assets/vertex.png',
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
