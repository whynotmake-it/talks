import 'dart:ui' as ui;

import 'package:device_frame/device_frame.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

import '../engine/capabilities.dart';

/// A device class to estimate a frame for: a screen (size, pixel ratio,
/// platform, from `device_frame`, the same presets snaptest uses) plus the
/// GPU decisions Impeller makes on it.
///
/// The test view is resized to [screen] before the frame is captured, so
/// layout, clips and pass sizes are those of the device.
class GpuDevice {
  const GpuDevice({
    required this.name,
    required this.screen,
    required this.gpu,
    this.note,
  });

  /// Pair any `device_frame` screen with a GPU profile.
  factory GpuDevice.custom(
    DeviceInfo screen, {
    required CapabilityProfile gpu,
    String? name,
    String? note,
  }) => GpuDevice(
    name: name ?? screen.name,
    screen: screen,
    gpu: gpu,
    note: note,
  );

  final String name;
  final DeviceInfo screen;
  final CapabilityProfile gpu;

  /// What the preset assumes, shown in the report.
  final String? note;

  ui.Size get physicalSize => screen.screenSize * screen.pixelRatio;

  /// The platform adaptive widgets build for, from the screen preset.
  TargetPlatform get platform => screen.identifier.platform;

  /// Bytes of one full-screen texture on this device.
  int get screenBytes =>
      (physicalSize.width * physicalSize.height * gpu.colorFormat.bytesPerPixel)
          .round();

  Map<String, Object?> toJson() => {
    'name': name,
    'logicalSize': [screen.screenSize.width, screen.screenSize.height],
    'pixelRatio': screen.pixelRatio,
    'physicalSize': [physicalSize.width, physicalSize.height],
    'gpu': gpu.toJson(),
    if (note != null) 'note': note,
  };

  /// iPhone 16 (A18): Metal, framebuffer fetch, wide gamut (8 B/px).
  static final GpuDevice iPhone16 = GpuDevice(
    name: 'iPhone 16',
    screen: Devices.ios.iPhone16,
    gpu: CapabilityProfile.iosDevice,
  );

  /// iPhone 16 Pro (A18 Pro).
  static final GpuDevice iPhone16Pro = GpuDevice(
    name: 'iPhone 16 Pro',
    screen: Devices.ios.iPhone16Pro,
    gpu: CapabilityProfile.iosDevice,
  );

  /// iPhone 16 Pro Max: the largest iPhone screen.
  static final GpuDevice iPhone16ProMax = GpuDevice(
    name: 'iPhone 16 Pro Max',
    screen: Devices.ios.iPhone16ProMax,
    gpu: CapabilityProfile.iosDevice,
  );

  /// iPhone SE: the smallest current iPhone screen (@2x).
  static final GpuDevice iPhoneSE = GpuDevice(
    name: 'iPhone SE',
    screen: Devices.ios.iPhoneSE,
    gpu: CapabilityProfile.iosDevice,
  );

  /// iPad Pro 13" (M4).
  static final GpuDevice iPadPro13 = GpuDevice(
    name: 'iPad Pro 13"',
    screen: Devices.ios.iPadPro13InchesM4,
    gpu: CapabilityProfile.iosDevice,
  );

  /// iPhone 16 screen on the iOS Simulator: no framebuffer fetch, sRGB.
  /// Useful to explain why the simulator looks worse than a device.
  static final GpuDevice iosSimulator = GpuDevice(
    name: 'iOS Simulator (iPhone 16)',
    screen: Devices.ios.iPhone16,
    gpu: CapabilityProfile.iosSimulator,
  );

  /// Pixel 9 (Mali GPU): Vulkan with framebuffer fetch, RGBA8.
  static final GpuDevice pixel9 = GpuDevice(
    name: 'Pixel 9',
    screen: Devices.android.googlePixel9,
    gpu: CapabilityProfile.androidVulkan,
  );

  /// Galaxy S25 (Adreno 830): Vulkan with framebuffer fetch.
  static final GpuDevice galaxyS25 = GpuDevice(
    name: 'Galaxy S25',
    screen: Devices.android.samsungGalaxyS25,
    gpu: CapabilityProfile.androidVulkan,
  );

  /// Pixel 10 (PowerVR DXT-48): Vulkan without framebuffer fetch, so every
  /// backdrop filter and advanced blend splits passes. Same 1080×2424 @2.625
  /// panel as the Pixel 9 preset. Assumes GPU driver 25.1 or newer; with an
  /// older driver Impeller uses OpenGL ES ([olderAndroidGles]).
  /// Validated against traces of a Pixel 10.
  static final GpuDevice pixel10 = GpuDevice(
    name: 'Pixel 10',
    screen: Devices.android.googlePixel9,
    gpu: CapabilityProfile.androidVulkanNoFetch,
  );

  /// An Adreno 650-or-older phone (Snapdragon 865 and older), which Impeller
  /// runs on OpenGL ES. Generic phone size from device_frame.
  static final GpuDevice olderAndroidGles = GpuDevice(
    name: 'Android on OpenGL ES',
    screen: Devices.android.mediumPhone,
    gpu: CapabilityProfile.androidGlesNoFetch,
    note: 'Generic phone size; assumes no GL_EXT_shader_framebuffer_fetch.',
  );

  /// One phone per GPU behavior: iPhone, Android with and without
  /// framebuffer fetch.
  static List<GpuDevice> get phones => [iPhone16, pixel9, pixel10];
}
