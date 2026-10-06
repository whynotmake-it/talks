import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snaptest/snaptest.dart';

import '../capture/binding.dart';
import '../engine/revision.dart';
import 'frame_demand.dart';
import 'frame_estimate.dart';
import 'gpu_device.dart';
import 'html_report.dart';
import 'on_device.dart';

/// Everything [estimateGpu] found for one screen.
class GpuReport {
  GpuReport({
    required this.name,
    required this.frames,
    this.frameDemand,
    this.screenshot,
    this.files = const [],
  });

  final String name;

  /// One estimate per device, in the order requested.
  final List<FrameEstimate> frames;

  /// Frames requested while idle, measured on the first device.
  final FrameDemand? frameDemand;

  /// Path of the screenshot PNG, relative to the report.
  final String? screenshot;

  /// The JSON and HTML files written.
  final List<File> files;

  /// The estimate for the device named [deviceName].
  FrameEstimate operator [](String deviceName) =>
      frames.firstWhere((f) => f.device.name == deviceName);

  Map<String, Object?> toJson() => {
    'name': name,
    'flutter': pinnedFlutterVersion,
    'engineRevision': pinnedEngineRevision,
    if (screenshot != null) 'screenshot': screenshot,
    'frames': [for (final f in frames) f.toJson()],
    if (frameDemand != null) 'frameDemand': frameDemand!.toJson(),
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  String toHtml() => renderHtmlReport(toJson());
}

/// Estimates the GPU cost of the current screen and writes a report.
///
/// For each of [devices] the test view is resized to that device, the frame
/// is re-laid out and captured, and the Impeller pass model runs with that
/// device's GPU capabilities. Then, unless [frameDemandWindow] is null, the
/// screen is watched for [frameDemandWindow] of fake time on the first
/// device to count the frames it requests on its own (tickers, timers,
/// the caret), after [frameDemandSettle] for entrance animations to end.
///
/// Writes `<name>.json` and `<name>.html` to [outputDir], relative to the
/// test file like snaptest's `.snaptest/`. [name] defaults to the test's
/// description. With [screenshot], a snaptest screenshot of the first
/// device is written next to them and shown in the report. With
/// [writeFiles] false nothing is written, not even the screenshot.
///
/// Requires [ImpellerModelBinding]. Call it after the screen is in the
/// state you want to measure:
///
/// ```dart
/// testWidgets('settings screen', (tester) async {
///   await tester.pumpWidget(const MyApp());
///   final report = await estimateGpu(tester);
///   expect(report.frames.first.renderPasses, lessThanOrEqualTo(2));
/// });
/// ```
///
/// The frame demand window advances the clock, so animations move on.
Future<GpuReport> estimateGpu(
  WidgetTester tester, {
  String? name,
  List<GpuDevice>? devices,
  Duration? frameDemandWindow = const Duration(seconds: 1),
  Duration frameDemandSettle = const Duration(milliseconds: 500),
  int refreshRate = 60,
  bool screenshot = false,
  String outputDir = '.impeller_model',
  bool writeFiles = true,
}) async {
  final binding = ImpellerModelBinding.instance;
  final targets = devices ?? GpuDevice.phones;
  if (targets.isEmpty) {
    throw ArgumentError.value(devices, 'devices', 'must not be empty');
  }
  final reportName = _fileName(name ?? tester.testDescription);

  final frames = <FrameEstimate>[];
  for (final device in targets) {
    final capture = await onDevice(tester, device, () async {
      return binding.captureFrame();
    });
    if (capture == null) {
      throw StateError('No frame was drawn yet. Pump a widget first.');
    }
    frames.add(estimateFrame(capture, device));
  }

  final dir = _outputDirectory(outputDir);
  final written = <File>[];

  FrameDemand? demand;
  if (frameDemandWindow != null) {
    demand = await measureFrameDemand(
      tester,
      window: frameDemandWindow,
      settle: frameDemandSettle,
      refreshRate: refreshRate,
      device: targets.first,
    );
  }

  // After the frame demand: the screenshot renders the layer tree into a
  // scene the binding does not record (OffsetLayer.toImage), and frames
  // estimated after it could not read custom layers' pushes.
  String? screenshotPath;
  if (screenshot && writeFiles) {
    // Built for the first device's platform, like its estimate.
    final files = await onDevice(
      tester,
      targets.first,
      () => snap(
        name: reportName,
        device: targets.first.screen,
        settings: SnaptestSettings.rendered(pathPrefix: outputDir),
      ),
    );
    if (files.isNotEmpty) {
      written.add(files.first);
      screenshotPath = p.relative(files.first.path, from: dir.path);
    }
  }

  final report = GpuReport(
    name: reportName,
    frames: frames,
    frameDemand: demand,
    screenshot: screenshotPath,
    files: written,
  );
  if (writeFiles) {
    dir.createSync(recursive: true);
    written
      ..add(
        File(p.join(dir.path, '$reportName.json'))
          ..writeAsStringSync(report.toJsonString()),
      )
      ..add(
        File(p.join(dir.path, '$reportName.html'))
          ..writeAsStringSync(report.toHtml()),
      );
  }
  return report;
}

String _fileName(String s) =>
    s.replaceAll(RegExp(r'[^\w\-]+'), '_').replaceAll(RegExp('_+'), '_');

/// Resolves [outputDir] next to the running test file, like snaptest.
Directory _outputDirectory(String outputDir) {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    return Directory(p.join(comparator.basedir.toFilePath(), outputDir));
  }
  return Directory(outputDir);
}
