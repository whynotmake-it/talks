/// Device capability profiles the pass model is evaluated against.
///
/// Sources:
///  - Metal: framebuffer fetch on Apple2+, off on iOS Simulator
///    (impeller/renderer/backend/metal/context_mtl.mm)
///  - Vulkan: on except Adreno <= 630 and PowerVR
///    (impeller/renderer/backend/vulkan/workarounds_vk.cc)
///  - GLES: only with GL_EXT_shader_framebuffer_fetch
///    (impeller/renderer/backend/gles/capabilities_gles.cc)
///  - BlitToOnscreen: only on Metal (canvas.cc:2531 SupportsBlitToOnscreen:
///    SupportsTextureToTextureBlits && backend == kMetal)
class CapabilityProfile {
  const CapabilityProfile({
    required this.name,
    required this.supportsFramebufferFetch,
    required this.supportsBlitToOnscreen,
    this.msaaSamples = 4,
    this.maxAttachmentSize = 16384,
  });

  final String name;

  /// `DeviceCapabilities::SupportsFramebufferFetch`.
  final bool supportsFramebufferFetch;

  /// `Canvas::SupportsBlitToOnscreen` — texture-to-texture blit + Metal.
  /// When false, readback produces an extra render pass instead of a blit.
  final bool supportsBlitToOnscreen;

  /// MSAA sample count for pass targets (memory traffic estimate only).
  final int msaaSamples;

  /// `GetMaximumRenderPassAttachmentSize` (canvas.cc:1788 clamp).
  final int maxAttachmentSize;

  /// Modern iPhone (A13+/Apple4 family): Metal, framebuffer fetch, blit.
  static const iphone = CapabilityProfile(
    name: 'metal-apple4',
    supportsFramebufferFetch: true,
    supportsBlitToOnscreen: true,
  );

  /// iOS Simulator: Metal without framebuffer fetch.
  static const iosSimulator = CapabilityProfile(
    name: 'metal-simulator',
    supportsFramebufferFetch: false,
    supportsBlitToOnscreen: true,
  );

  /// Vulkan with framebuffer fetch (most modern Android + SwiftShader).
  static const vulkanFetch = CapabilityProfile(
    name: 'vulkan-fbf',
    supportsFramebufferFetch: true,
    supportsBlitToOnscreen: false,
  );

  /// Vulkan without framebuffer fetch (Adreno <= 630, PowerVR).
  static const vulkanNoFetch = CapabilityProfile(
    name: 'vulkan-adreno<=630',
    supportsFramebufferFetch: false,
    supportsBlitToOnscreen: false,
  );

  /// GLES without EXT_shader_framebuffer_fetch.
  static const glesNoFetch = CapabilityProfile(
    name: 'gles-no-fbf',
    supportsFramebufferFetch: false,
    supportsBlitToOnscreen: false,
  );
}
