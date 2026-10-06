/// The debug labels Impeller puts on its GPU work. These are what Xcode's
/// Metal frame capture and Instruments' Metal System Trace show, so the
/// model names every pass with one of them.
///
/// Labels are only set in builds with `IMPELLER_DEBUG` (debug and profile):
///
/// ```engine impeller/renderer/backend/metal/render_pass_mtl.mm
/// void RenderPassMTL::OnSetLabel(std::string_view label) {
/// #ifdef IMPELLER_DEBUG
/// ```
///
/// On Vulkan they additionally need validation layers, so RenderDoc and AGI
/// captures of a stock build show unlabeled passes:
///
/// ```engine impeller/renderer/backend/vulkan/context_vk.h
///     if (!HasValidationLayers()) {
///       // No-op if validation layers are not enabled.
///       return true;
///     }
/// ```
abstract final class EngineLabels {
  /// Every EntityPass render pass: the onscreen root, an offscreen root, a
  /// saveLayer subpass, and each restart of a pass after a backdrop flip.
  ///
  /// ```engine impeller/entity/inline_pass_context.cc
  ///   pass_->SetLabel("EntityPass Render Pass");
  /// ```
  static const entityPass = 'EntityPass Render Pass';

  /// ```engine impeller/entity/inline_pass_context.cc
  ///   command_buffer_->SetLabel("EntityPass Command Buffer");
  /// ```
  static const entityPassCommandBuffer = 'EntityPass Command Buffer';

  /// Each of the three passes of a Gaussian blur.
  ///
  /// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
  ///     return renderer.MakeSubpass("Gaussian Blur Filter", pass_args.subpass_size,
  /// ```
  static const gaussianBlurFilter = 'Gaussian Blur Filter';

  /// An advanced blend emulated without framebuffer fetch.
  ///
  /// ```engine impeller/entity/contents/filters/blend_filter_contents.cc
  ///       renderer.MakeSubpass("Advanced Blend Filter",            //
  /// ```
  static const advancedBlendFilter = 'Advanced Blend Filter';

  /// The snapshot a Gaussian blur takes of an input that is not already a
  /// texture (e.g. the color filter inside `ImageFilter.compose`).
  ///
  /// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
  ///       input->GetSnapshot("GaussianBlur", renderer, entity,
  /// ```
  static const gaussianBlurInputSnapshot = 'GaussianBlur';

  /// With framebuffer fetch, an advanced blend renders its source draw into
  /// a texture first.
  ///
  /// ```engine impeller/entity/contents/framebuffer_blend_contents.cc
  ///        .label = "FramebufferBlendContents Snapshot"});
  /// ```
  static const framebufferBlendSnapshot = 'FramebufferBlendContents Snapshot';

  /// Without framebuffer fetch, an emulated advanced blend renders its
  /// source draw into a texture before blending. The Pixel 10 validation
  /// confirms the pass (count and size); Vulkan shows no labels, so this
  /// label is from the source only.
  ///
  /// ```engine impeller/entity/contents/filters/blend_filter_contents.cc
  ///         inputs[1]->GetSnapshot("AdvancedBlend(Src)", renderer, entity);
  /// ```
  static const advancedBlendSourceSnapshot = 'AdvancedBlend(Src)';

  /// ```engine impeller/entity/contents/filters/morphology_filter_contents.cc
  ///       renderer.MakeSubpass("Directional Morphology Filter",  //
  /// ```
  static const morphologyFilter = 'Directional Morphology Filter';

  /// Default label of `Contents::RenderToSnapshot`, used for filters the
  /// model does not port.
  ///
  /// ```engine impeller/entity/contents/contents.h
  ///     std::string_view label = "Snapshot";
  /// ```
  static const snapshot = 'Snapshot';

  /// The command buffer that copies an offscreen root to the surface. On
  /// Metal it holds a blit encoder, elsewhere a render pass:
  ///
  /// ```engine impeller/display_list/canvas.cc
  ///   command_buffer->SetLabel("EntityPass Root Command Buffer");
  /// ```
  static const rootCommandBuffer = 'EntityPass Root Command Buffer';

  /// ```engine impeller/display_list/canvas.cc
  ///     render_pass->SetLabel("EntityPass Root Render Pass");
  /// ```
  static const rootCopyPass = 'EntityPass Root Render Pass';

  /// The blit encoder `BlitToOnscreen` creates gets no label of its own.
  static const blitToOnscreen = 'Blit (unlabeled)';
}
