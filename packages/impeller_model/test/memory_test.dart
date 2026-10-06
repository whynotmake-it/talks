// Memory traffic at device preset sizes. The expected values follow from
// engine facts, not from the model's own output:
// - iOS renders BGRA10_XR (8 B/px), Android Vulkan RGBA8 (4 B/px);
// - the 4x MSAA attachments are transient, only the 1-sample resolve is
//   stored (so no factor of 4 or 5 anywhere);
// - an offscreen texture is stored once and read back once.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeller_model/impeller_model.dart';

/// A full-screen ClipRRect that must use a saveLayer: two overlapping
/// children under Clip.antiAliasWithSaveLayer (validated on device by the
/// clip_savelayer scene).
Widget _fullScreenLayer() => Directionality(
  textDirection: TextDirection.ltr,
  child: ClipRRect(
    clipBehavior: Clip.antiAliasWithSaveLayer,
    borderRadius: BorderRadius.circular(1),
    child: const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.blue),
        Padding(
          padding: EdgeInsets.all(40),
          child: ColoredBox(color: Colors.orange),
        ),
      ],
    ),
  ),
);

Future<GpuReport> _estimate(WidgetTester tester, List<GpuDevice> devices) =>
    estimateGpu(
      tester,
      devices: devices,
      frameDemandWindow: null,
      writeFiles: false,
    );

void main() {
  testWidgets('a plain frame writes the screen once, at the device format', (
    tester,
  ) async {
    await tester.pumpWidget(const ColoredBox(color: Colors.blue));
    final report = await _estimate(tester, [
      GpuDevice.iPhone16,
      GpuDevice.pixel10,
      GpuDevice.iosSimulator,
    ]);
    final [iPhone, pixel, simulator] = report.frames;

    expect(iPhone.traffic.surfaceBytes, 1179 * 2556 * 8);
    expect(pixel.traffic.surfaceBytes, 1080 * 2424 * 4);
    expect(simulator.traffic.surfaceBytes, 1179 * 2556 * 4);
    for (final frame in report.frames) {
      expect(frame.traffic.extraBytes, 0, reason: frame.device.name);
      expect(frame.traffic.relativeToPlainFrame, 1.0);
    }
  });

  testWidgets('a full-screen layer stores and reads one screen, no MSAA', (
    tester,
  ) async {
    await tester.pumpWidget(_fullScreenLayer());
    final report = await _estimate(tester, [
      GpuDevice.iPhone16,
      GpuDevice.pixel9,
      GpuDevice.pixel10,
    ]);
    for (final frame in report.frames) {
      final screen = frame.device.screenBytes;
      expect(frame.renderPasses, 2, reason: frame.device.name);
      // Stored once, read once by the parent pass: 2 screens, not 2 x 4.
      expect(frame.traffic.extraBytes, 2 * screen, reason: frame.device.name);
      expect(frame.traffic.extraScreenEquivalents, 2.0);
    }
    // Same pass shape, twice the bytes per pixel on iOS.
    expect(report.frames[0].traffic.extraBytes, 2 * 1179 * 2556 * 8);
    expect(report.frames[2].traffic.extraBytes, 2 * 1080 * 2424 * 4);
  });

  testWidgets('screen-equivalents depend on the device class', (tester) async {
    // A centered BackdropFilter: the Pixel 10 has no framebuffer fetch and
    // copies the offscreen frame to the screen at the end (measured: one
    // pass more than macOS per frame, scene backdrop_blur).
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.blue),
            Center(
              child: SizedBox(
                width: 280,
                height: 200,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final report = await _estimate(tester, [
      GpuDevice.pixel9,
      GpuDevice.pixel10,
    ]);
    final [pixel9, pixel10] = report.frames;
    expect(pixel10.renderPasses, pixel9.renderPasses + 1);
    expect(
      pixel10.traffic.extraScreenEquivalents,
      greaterThan(pixel9.traffic.extraScreenEquivalents),
    );
  });
}
