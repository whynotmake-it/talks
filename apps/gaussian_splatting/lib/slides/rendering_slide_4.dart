import 'package:flutter/material.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';




// Pipeline state
// disable(DEPTH_TEST)
// We’re layering transparent, soft blobs. Depth testing would poke holes in later layers. We handle ordering ourselves → turn depth off.
// depthMask(false)
// Don’t write depth. If a blob wrote depth, it would block later blending at that pixel.
// enable(BLEND)
// Lets each blob mix with what’s already on screen (the “airbrush” effect).
// blendFuncSeparate(ONE, ONE_MINUS_SRC_ALPHA, ONE, ONE_MINUS_SRC_ALPHA)
// Premultiplied alpha: add my premultiplied RGB; fade the background by (1−α). This avoids halos at soft edges.
// blendEquationSeparate(FUNC_ADD, FUNC_ADD)
// Use normal addition for both color and alpha. We’re just stacking paint.
// Program + uniforms
// useProgram(_prog)
// Select the splat shaders.
// uniformMatrix4fv(_uProjection, …) / uniformMatrix4fv(_uView, …)
// Camera transforms: where we are and how 3D lands on screen.
// uniform2f(_uFocal, fx, fy)
// Camera intrinsics (zoom in pixels). Needed to size the ellipse correctly.
// uniform2f(_uViewport, width, height)
// Render target size. Converts NDC offsets to pixel offsets and lets us clamp sizes.
// uniform1i(_uSplatCount, count)
// How many splats exist; the VS can bounds-check and early-out safely.
// uniform1f(_uMaxSplatSize, maxPixels)
// Safety cap so a few giant splats don’t nuke fill-rate.
// Textures (data sources)
// TEXTURE0 ← source.texture
// The atlas: per-splat attributes (pos, rot/scale, color, SH). Random access in the VS via texelFetch.
// TEXTURE1 ← order.texture
// The draw order: maps “draw slot” → “splat id” (sorted for blending).
// Geometry (what the rasterizer consumes)
// enableVertexAttribArray(_aPosition) + vertexAttribPointer(_aPosition, 3, FLOAT, …)
// Feed the VS a stream of vec3 per vertex from the VBO.
// x,y = which quad corner (−1/+1). z = local splat index within the batch (0…127).
// (Note: _aPosition is just the attribute location id; the actual x/y/z values live in the VBO.)
// bindBuffer(ELEMENT_ARRAY_BUFFER, _ebo)
// The index buffer saying “connect corners 0-1-2 and 0-2-3” for each quad → two triangles without duplicating vertices.
// Draw
// drawElementsInstanced(TRIANGLES, _indicesPerBatch, UNSIGNED_SHORT, 0, _instanceCount)
// Fire the batched draw. Each instance covers N splats (e.g., 128). The VS uses gl_InstanceID + position.z to find the global splat id, then fetches from the textures.


class RenderingSlide4 extends FlutterDeckSlideWidget {
  const RenderingSlide4({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/rendering-4',
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
 // Pipeline state (viewport already set by main renderer)
    gl
      ..disable(WebGL.DEPTH_TEST)
      ..depthMask(false)
      ..enable(WebGL.BLEND)
      ..blendFuncSeparate(
        WebGL.ONE,
        WebGL.ONE_MINUS_SRC_ALPHA,
        WebGL.ONE,
        WebGL.ONE_MINUS_SRC_ALPHA,
      )
      ..blendEquationSeparate(WebGL.FUNC_ADD, WebGL.FUNC_ADD);

    // Program + uniforms
    gl.useProgram(_prog);
    if (_uProjection != null) {
      gl.uniformMatrix4fv(_uProjection!, false, projectionMatrix.storage);
    }
    if (_uView != null) {
      gl.uniformMatrix4fv(_uView!, false, viewMatrix.storage);
    }
    if (_uFocal != null) {
      gl.uniform2f(_uFocal!, cam.focalXForShader(), cam.focalYForShader());
    }
    if (_uViewport != null) {
      gl.uniform2f(_uViewport!, cam.width.toDouble(), cam.height.toDouble());
    }
    if (_uSplatCount != null) gl.uniform1i(_uSplatCount!, source.splatCount);
    if (_uMaxSplatSize != null) {
      gl.uniform1f(_uMaxSplatSize!, maxSplatPixelSize);
    }

    // Bind textures to the units we fixed above.
    gl
      ..activeTexture(WebGL.TEXTURE0)
      ..bindTexture(WebGL.TEXTURE_2D, source.texture);

    if (order.texture != null) {
      gl
        ..activeTexture(WebGL.TEXTURE1)
        ..bindTexture(WebGL.TEXTURE_2D, order.texture);
    }

    // Geometry
    if (_aPosition != null) {
      gl
        ..enableVertexAttribArray(_aPosition!)
        ..bindBuffer(WebGL.ARRAY_BUFFER, _vbo)
        ..vertexAttribPointer(_aPosition!, 3, WebGL.FLOAT, false, 0, 0);
    }

    gl
      ..bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, _ebo)
      ..drawElementsInstanced(
        WebGL.TRIANGLES,
        _indicesPerBatch,
        WebGL.UNSIGNED_SHORT,
        0,
        _instanceCount,
      );
  ''',
        filename: 'splat_draw_pass.dart',
      ),

      secondaryContent: Image.asset(
        'assets/gpu.png',
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
