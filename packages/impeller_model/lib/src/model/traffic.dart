/// Memory traffic caused by pass breaks.
///
/// A plain frame writes the screen surface once. Every other pass stores
/// its texture to memory when it ends, and that texture is read back once
/// by whatever consumes it (the parent pass, the restarted pass, the blit).
/// The blur downsample additionally reads its whole source. MSAA samples
/// never leave the GPU (see [ModelPass.storedBytes]).
///
/// The headline unit is the **screen-equivalent**: bytes moved divided by
/// the bytes of one full-screen write. Every texture of a frame uses the
/// same pixel format, so this ratio does not depend on the format. It does
/// depend on the device: screen size changes blur and layer sizes relative
/// to the screen, and devices without framebuffer fetch add passes.
/// Bytes follow for a concrete device, as
/// `ratio × width × height × bytesPerPixel`.
///
/// It is an upper bound on attachment traffic, not a bandwidth
/// measurement: it ignores framebuffer compression (lossy on A15/M2 and
/// newer Apple GPUs and where Vulkan drivers offer fixed-rate compression,
/// lossless on most GPUs), caches, and partial repaint.
library;

import 'dart:ui' as ui;

import '../engine/canvas.dart';

class MemoryTraffic {
  MemoryTraffic._({
    required this.surfaceBytes,
    required this.storedBytes,
    required this.readBytes,
    required this.bytesPerPixel,
  });

  factory MemoryTraffic.of(
    PassTimeline timeline,
    ui.Size screenSize,
  ) {
    final bpp = timeline.profile.colorFormat.bytesPerPixel;
    var stored = 0;
    var read = 0;
    for (final p in timeline.passes) {
      stored += p.storedBytes(bpp);
      read += p.readBytes(bpp);
    }
    return MemoryTraffic._(
      surfaceBytes: (screenSize.width * screenSize.height * bpp).round(),
      storedBytes: stored,
      readBytes: read,
      bytesPerPixel: bpp,
    );
  }

  /// The write of the screen surface that every frame pays.
  final int surfaceBytes;

  /// Offscreen textures written to memory by pass ends.
  final int storedBytes;

  /// Offscreen textures read back.
  final int readBytes;

  final int bytesPerPixel;

  /// Bytes moved beyond the plain frame.
  int get extraBytes => storedBytes + readBytes;

  /// Extra traffic in full-screen writes. 0 for a single-pass frame, 2.0
  /// for one full-screen offscreen pass (stored once, read once).
  double get extraScreenEquivalents =>
      surfaceBytes == 0 ? 0 : extraBytes / surfaceBytes;

  /// Total traffic relative to a plain frame: 1.0 is a plain frame.
  double get relativeToPlainFrame => 1 + extraScreenEquivalents;

  Map<String, Object?> toJson() => {
    'bytesPerPixel': bytesPerPixel,
    'surfaceBytes': surfaceBytes,
    'storedBytes': storedBytes,
    'readBytes': readBytes,
    'extraBytes': extraBytes,
    'extraScreenEquivalents': double.parse(
      extraScreenEquivalents.toStringAsFixed(3),
    ),
  };
}
