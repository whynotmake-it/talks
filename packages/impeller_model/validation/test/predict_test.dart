// Predicts every validation scene for every validation target, writes
// predictions.json for the trace tools, and checks each prediction against
// the last committed trace in results/<target>.json: a model change that
// contradicts a measurement fails here, without a device.
//
//   flutter test test/predict_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeller_model/impeller_model.dart';
import 'package:impeller_validation/scenes.dart';

/// A device the validation app is traced on: its exact physical size and
/// pixel ratio, and the GPU profile Impeller uses there.
class Target {
  const Target(this.name, this.platform, this.physical, this.dpr, this.gpu);
  final String name;
  final TargetPlatform platform;
  final Size physical;
  final double dpr;
  final CapabilityProfile gpu;
}

const targets = [
  // MainFlutterWindow.swift pins a 400x800 pt window; Retina = 2x.
  Target(
    'macos',
    TargetPlatform.macOS,
    Size(800, 1600),
    2,
    CapabilityProfile.macos,
  ),
  // `adb shell wm size` / `wm density`: 1080x2424, 420 dpi.
  Target(
    'pixel10',
    TargetPlatform.android,
    Size(1080, 2424),
    2.625,
    CapabilityProfile.androidVulkanNoFetch,
  ),
];

void main() {
  ImpellerModelBinding.ensureInitialized();
  final predictions = <String, Map<String, Object?>>{};

  for (final target in targets) {
    for (final scene in scenes.values) {
      testWidgets('${target.name} / ${scene.name}', (tester) async {
        tester.view
          ..physicalSize = target.physical
          ..devicePixelRatio = target.dpr;
        addTearDown(tester.view.reset);
        // Build as the traced device does (adaptive widgets read it).
        debugDefaultTargetPlatformOverride = target.platform;
        late final FrameCapture capture;
        try {
          await tester.pumpWidget(
            CupertinoApp(
              debugShowCheckedModeBanner: false,
              home: Builder(builder: scene.build),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          capture = ImpellerModelBinding.instance.captureFrame()!;
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
        final estimate = estimateFrame(
          capture,
          GpuDevice.custom(
            DeviceInfo.genericPhone(
              platform: target.platform,
              id: target.name,
              name: target.name,
              screenSize: target.physical / target.dpr,
              pixelRatio: target.dpr,
            ),
            gpu: target.gpu,
          ),
        );
        (predictions[target.name] ??= {})[scene.name] = {
          'description': scene.description,
          'renderPasses': estimate.renderPasses,
          'renderPassesByLabel': estimate.renderPassesByLabel,
          'blit': estimate.passes.any((p) => !p.isRenderPass),
          'flips': estimate.flips,
          'approximate': estimate.passes.any((p) => p.approximate),
          'passes': [
            for (final p in estimate.passes) _describe(p),
          ],
        };
        final measured = _measured(target.name)[scene.name] as Map?;
        if (measured == null) {
          markTestSkipped('Not traced yet: run the tool for ${target.name}.');
          return;
        }
        if (target.name == 'macos') {
          // Metal System Trace: render encoders per label, plus blits.
          expect(estimate.renderPassesByLabel, measured['measured']);
          expect(
            estimate.passes.any((p) => !p.isRenderPass),
            (measured['measuredBlits'] as int) > 0,
            reason: 'blit to the screen',
          );
        } else {
          // Vulkan pass logger: the multiset of pass sizes, within 2 px.
          final predicted = [
            for (final p in estimate.passes)
              if (p.isRenderPass) [p.size.width.round(), p.size.height.round()],
          ];
          final logged = [
            for (final m in measured['measured'] as List)
              (m as String).split('x').take(2).map(int.parse).toList(),
          ];
          expect(
            _sameSizes(predicted, logged),
            isTrue,
            reason: 'predicted $predicted, measured $logged',
          );
        }
      });
    }
  }

  tearDownAll(() {
    // A filtered run (--plain-name) must not drop the other scenes.
    final complete =
        predictions.length == targets.length &&
        predictions.values.every((p) => p.length == scenes.length);
    if (!complete) {
      return;
    }
    File('predictions.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'flutter': pinnedFlutterVersion, 'targets': predictions})}\n',
    );
  });
}

final _results = <String, Map<String, Object?>>{};

Map<String, Object?> _measured(String target) =>
    _results.putIfAbsent(target, () {
      final f = File('results/$target.json');
      return f.existsSync()
          ? (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>()
          : <String, Object?>{};
    });

/// Same sizes as multisets, each side within 2 px (blur padding rounds
/// differently on the device).
bool _sameSizes(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) return false;
  int byArea(List<int> x, List<int> y) => (x[0] * x[1]).compareTo(y[0] * y[1]);
  final x = [...a]..sort(byArea);
  final y = [...b]..sort(byArea);
  for (var i = 0; i < x.length; i++) {
    if ((x[i][0] - y[i][0]).abs() > 2 || (x[i][1] - y[i][1]).abs() > 2) {
      return false;
    }
  }
  return true;
}

String _describe(ModelPass p) =>
    '${p.engineLabel} ${p.size.width.round()}x${p.size.height.round()} '
    '(${p.role.name})';
