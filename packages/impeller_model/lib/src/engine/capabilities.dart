/// The GPU capabilities the pass model is evaluated against.
///
/// Everything here is a fact the engine decides per device at startup. Each
/// field quotes where. Run `dart run tool/engine_refs.dart` after an SDK
/// bump to see which quotes moved.
library;

/// Impeller rendering backend.
enum GpuBackend { metal, vulkan, gles }

/// The color format Impeller uses for the onscreen surface AND every
/// offscreen pass texture (saveLayers, blur intermediates).
///
/// On iOS the offscreen format follows the layer's format:
///
/// ```engine shell/platform/darwin/ios/ios_surface_metal_impeller.mm
///   impeller_context_->UpdateOffscreenLayerPixelFormat(
///       impeller::FromMTLPixelFormat(layer_.pixelFormat));
/// ```
///
/// and the layer is wide gamut whenever the screen supports it:
///
/// ```engine shell/platform/darwin/ios/framework/Source/FlutterView.mm
///     if (_isWideGamutEnabled && self.isWideGamutSupported) {
///       fml::CFRef<CGColorSpaceRef> srgb(CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB));
///       layer.colorspace = srgb;
///       layer.pixelFormat = MTLPixelFormatBGRA10_XR;
/// ```
///
/// `FLTEnableWideGamut` defaults to YES on devices, and the simulator is
/// always sRGB:
///
/// ```engine shell/platform/darwin/ios/framework/Source/FlutterDartProject.mm
///   BOOL enableWideGamut =
///       (nsEnableWideGamut ? nsEnableWideGamut.boolValue : YES) && DoesHardwareSupportWideGamut();
/// ```
///
/// Vulkan picks RGBA8:
///
/// ```engine impeller/renderer/backend/vulkan/capabilities_vk.cc
///   if (HasSuitableColorFormat(device, vk::Format::eR8G8B8A8Unorm)) {
///     default_color_format_ = PixelFormat::kR8G8B8A8UNormInt;
/// ```
enum PixelFormat {
  /// `MTLPixelFormatBGRA10_XR`, iOS/macOS wide gamut.
  bgra10XR('BGRA10_XR', 8),

  /// `MTLPixelFormatBGRA8Unorm`, sRGB Metal (simulator, wide gamut off).
  bgra8Unorm('BGRA8Unorm', 4),

  /// `VK_FORMAT_R8G8B8A8_UNORM` / GL RGBA8.
  rgba8Unorm('RGBA8Unorm', 4);

  const PixelFormat(this.label, this.bytesPerPixel);

  /// The name Xcode / RenderDoc show for the format.
  final String label;

  /// ```engine impeller/core/formats.h
  ///     case PixelFormat::kR16G16B16A16Float:
  ///     case PixelFormat::kB10G10R10A10XR:
  ///       return 8u;
  /// ```
  final int bytesPerPixel;
}

class CapabilityProfile {
  const CapabilityProfile({
    required this.name,
    required this.backend,
    required this.supportsFramebufferFetch,
    required this.colorFormat,
    this.lossyCompressedPassTextures = false,
    this.maxAttachmentSize = 16384,
  });

  final String name;
  final GpuBackend backend;

  /// `Capabilities::SupportsFramebufferFetch`. Decides whether advanced
  /// blends and the last backdrop filter can stay in the current pass.
  ///
  /// Metal (simulator always false):
  ///
  /// ```engine impeller/renderer/backend/metal/context_mtl.mm
  /// #if FML_OS_IOS_SIMULATOR
  ///   // The iOS simulator lies about supporting framebuffer fetch.
  ///   return false;
  /// #else   // FML_OS_IOS_SIMULATOR
  /// ```
  ///
  /// Vulkan (off on Adreno <= 630 and every PowerVR GPU):
  ///
  /// ```engine impeller/renderer/backend/vulkan/workarounds_vk.cc
  ///     if (adreno_gpu.value() <= AdrenoGPU::kAdreno630) {
  ///       workarounds.input_attachment_self_dependency_broken = true;
  /// ```
  ///
  /// ```engine impeller/renderer/backend/vulkan/workarounds_vk.cc
  ///   } else if (powervr_gpu.has_value()) {
  ///     workarounds.input_attachment_self_dependency_broken = true;
  ///   }
  /// ```
  ///
  /// ```engine impeller/renderer/backend/vulkan/capabilities_vk.cc
  ///   has_framebuffer_fetch_ = !workarounds.input_attachment_self_dependency_broken;
  /// ```
  ///
  /// GLES (extension-gated):
  ///
  /// ```engine impeller/renderer/backend/gles/capabilities_gles.cc
  ///   supports_framebuffer_fetch_ = desc->HasExtension(kFramebufferFetchExt);
  /// ```
  final bool supportsFramebufferFetch;

  /// Format of the surface and of every offscreen pass texture.
  final PixelFormat colorFormat;

  /// Whether EntityPass textures (saveLayers, offscreen roots) are known to
  /// be stored with lossy compression, roughly half the nominal bytes:
  /// Apple8+ GPUs on Metal. Blur intermediates are not. Vulkan requests the
  /// same through fixed-rate compression where the driver supports it,
  /// which varies per device, so Vulkan profiles leave this false. Traffic
  /// figures stay nominal either way.
  ///
  /// ```engine impeller/renderer/render_target.cc
  ///     color0_resolve_tex_desc.compression_type = CompressionType::kLossy;
  /// ```
  /// ```engine impeller/renderer/backend/metal/allocator_mtl.mm
  ///   return [device supportsFamily:MTLGPUFamilyApple8];
  /// ```
  final bool lossyCompressedPassTextures;

  /// `GetMaximumRenderPassAttachmentSize` — the saveLayer size clamp.
  ///
  /// ```engine impeller/display_list/canvas.cc
  ///   subpass_size = subpass_size.Min(renderer_.GetContext()
  ///                                       ->GetCapabilities()
  ///                                       ->GetMaximumRenderPassAttachmentSize());
  /// ```
  final int maxAttachmentSize;

  /// Whether an offscreen root is copied to the surface with a blit
  /// encoder (Metal) or with an extra render pass (everything else).
  ///
  /// ```engine impeller/display_list/canvas.cc
  /// bool Canvas::SupportsBlitToOnscreen() const {
  ///   return renderer_.GetContext()
  ///              ->GetCapabilities()
  ///              ->SupportsTextureToTextureBlits() &&
  ///          renderer_.GetContext()->GetBackendType() ==
  ///              Context::BackendType::kMetal;
  /// ```
  bool get supportsBlitToOnscreen => backend == GpuBackend.metal;

  Map<String, Object?> toJson() => {
    'name': name,
    'backend': backend.name,
    'framebufferFetch': supportsFramebufferFetch,
    'blitToOnscreen': supportsBlitToOnscreen,
    'colorFormat': colorFormat.label,
    'bytesPerPixel': colorFormat.bytesPerPixel,
    if (lossyCompressedPassTextures) 'lossyCompressedPassTextures': true,
  };

  /// iPhone / iPad with an A15 or newer (Apple8+): Metal, framebuffer
  /// fetch, wide gamut, lossy-compressed pass textures.
  static const iosDevice = CapabilityProfile(
    name: 'ios-metal',
    backend: GpuBackend.metal,
    supportsFramebufferFetch: true,
    colorFormat: PixelFormat.bgra10XR,
    lossyCompressedPassTextures: true,
  );

  /// iPhone / iPad with an A14 or older: as [iosDevice], uncompressed.
  static const iosDeviceA14 = CapabilityProfile(
    name: 'ios-metal-a14',
    backend: GpuBackend.metal,
    supportsFramebufferFetch: true,
    colorFormat: PixelFormat.bgra10XR,
  );

  /// iOS Simulator: Metal without framebuffer fetch, sRGB.
  static const iosSimulator = CapabilityProfile(
    name: 'ios-simulator',
    backend: GpuBackend.metal,
    supportsFramebufferFetch: false,
    colorFormat: PixelFormat.bgra8Unorm,
  );

  /// Apple-silicon Mac on a P3 display (the validation Mac's built-in
  /// display): same Metal decisions as an iPhone. Impeller and wide gamut are
  /// on by default on macOS too, but wide gamut follows the window's
  /// screen, so an sRGB external display renders BGRA8 (4 B/px):
  ///
  /// ```engine shell/platform/darwin/macos/framework/Source/FlutterDartProject.mm
  /// - (BOOL)enableWideGamut {
  ///   return self.enableImpeller && DoesHardwareSupportWideGamut();
  /// ```
  ///
  /// ```engine shell/platform/darwin/macos/framework/Source/FlutterViewController.mm
  ///   BOOL screenSupportsP3 = [screen canRepresentDisplayGamut:NSDisplayGamutP3];
  ///   [self.flutterView setEnableWideGamut:screenSupportsP3];
  /// ```
  static const macos = CapabilityProfile(
    name: 'macos-metal',
    backend: GpuBackend.metal,
    supportsFramebufferFetch: true,
    colorFormat: PixelFormat.bgra10XR,
    lossyCompressedPassTextures: true,
  );

  /// Android Vulkan with framebuffer fetch (Mali, Adreno 660+, Xclipse).
  static const androidVulkan = CapabilityProfile(
    name: 'android-vulkan',
    backend: GpuBackend.vulkan,
    supportsFramebufferFetch: true,
    colorFormat: PixelFormat.rgba8Unorm,
  );

  /// Android Vulkan without framebuffer fetch: PowerVR GPUs such as the
  /// Pixel 10's DXT-48 (see [supportsFramebufferFetch] for the workaround).
  /// A Pixel 10 runs Vulkan only with driver 25.1 or newer; older drivers
  /// fall back to OpenGL ES ([androidGlesNoFetch]):
  ///
  /// ```engine impeller/renderer/backend/vulkan/driver_info_vk.cc
  ///   if (vendor_ == VendorVK::kPowerVR && device_id_ == kPixel10DeviceID &&
  ///       driver_version_ < kPixel10MinDriverVersion) {
  /// ```
  static const androidVulkanNoFetch = CapabilityProfile(
    name: 'android-vulkan-no-fbf',
    backend: GpuBackend.vulkan,
    supportsFramebufferFetch: false,
    colorFormat: PixelFormat.rgba8Unorm,
  );

  /// Android OpenGL ES without `GL_EXT_shader_framebuffer_fetch`.
  ///
  /// Impeller falls back to GLES where Vulkan is missing or blocklisted,
  /// which includes every Adreno up to 650 (Snapdragon 865 and older):
  ///
  /// ```engine impeller/renderer/backend/vulkan/driver_info_vk.cc
  ///   if (adreno_gpu_ && *adreno_gpu_ <= AdrenoGPU::kAdreno650) {
  ///     return true;
  ///   }
  /// ```
  ///
  /// Whether such a device has framebuffer fetch depends on its GL driver
  /// exposing the extension; this profile assumes it does not.
  static const androidGlesNoFetch = CapabilityProfile(
    name: 'android-gles-no-fbf',
    backend: GpuBackend.gles,
    supportsFramebufferFetch: false,
    colorFormat: PixelFormat.rgba8Unorm,
  );
}
