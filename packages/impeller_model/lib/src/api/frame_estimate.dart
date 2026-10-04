import '../capture/binding.dart';
import '../capture/layer_walk.dart';
import '../engine/canvas.dart';
import '../engine/display_list.dart';
import '../engine/dl_dispatcher.dart';
import '../model/traffic.dart';
import 'gpu_device.dart';

/// Passes and traffic charged to one widget (or one engine reason).
class CostCenter {
  CostCenter(this.label);

  /// `BackdropFilter (lib/home.dart:42)`, or an engine reason.
  final String label;

  /// Render passes beyond the frame's own surface pass.
  int renderPasses = 0;

  /// Store + readback bytes charged here.
  int extraBytes = 0;

  final Set<PassRole> roles = {};

  Map<String, Object?> toJson() => {
    'label': label,
    'renderPasses': renderPasses,
    'extraBytes': extraBytes,
    'roles': [for (final r in roles) r.name],
  };
}

/// The estimate of one captured frame on one device.
class FrameEstimate {
  FrameEstimate._({
    required this.device,
    required this.timeline,
    required this.traffic,
    required this.layerTree,
    required this.missingPictures,
  });

  final GpuDevice device;
  final PassTimeline timeline;
  final MemoryTraffic traffic;
  final CapturedLayer layerTree;

  /// Picture layers whose draws were unknown (should be 0).
  final int missingPictures;

  List<ModelPass> get passes => timeline.passes;

  /// Render passes in the frame. A plain frame has 1.
  int get renderPasses => timeline.renderPassCount;

  /// Times a pass was ended early to read it back (backdrop filters,
  /// emulated blends).
  int get flips => timeline.flips;

  /// Render pass count per Impeller label: compare these with the render
  /// encoders of one frame in a GPU capture.
  Map<String, int> get renderPassesByLabel => timeline.renderPassesByLabel;

  /// Where the passes and traffic come from, most expensive first.
  List<CostCenter> get costCenters {
    final bpp = timeline.profile.colorFormat.bytesPerPixel;
    final centers = <String, CostCenter>{};
    for (final p in passes) {
      if (p.writesSurface) {
        continue;
      }
      final c = centers.putIfAbsent(p.chargedTo, () => CostCenter(p.chargedTo));
      if (p.isRenderPass) {
        c.renderPasses++;
      }
      c.extraBytes += p.storedBytes(bpp) + p.readBytes(bpp);
      c.roles.add(p.role);
    }
    return centers.values.toList()
      ..sort((a, b) => b.extraBytes.compareTo(a.extraBytes));
  }

  Map<String, Object?> toJson() => {
    'device': device.toJson(),
    'renderPasses': renderPasses,
    'renderPassesByLabel': renderPassesByLabel,
    'flips': flips,
    'traffic': traffic.toJson(),
    if (missingPictures > 0) 'missingPictures': missingPictures,
    'costCenters': [for (final c in costCenters) c.toJson()],
    'passes': [for (final p in passes) p.toJson()],
    'roles': {
      for (final r in PassRole.values)
        r.name: {'title': r.title, 'explanation': r.explanation},
    },
  };
}

/// Runs the model on [capture] for [device].
///
/// [capture] must have been taken with the test view sized like [device]:
/// pass sizes come from the layer tree, so a mismatch would report one
/// screen's passes as another's. [estimateGpu] sizes the view; for a test
/// view of another size, describe it with [GpuDevice.custom] and
/// `DeviceInfo.genericPhone`.
FrameEstimate estimateFrame(FrameCapture capture, GpuDevice device) {
  final expected = device.physicalSize;
  final actual = capture.physicalSize;
  if ((expected.width - actual.width).abs() > 1 ||
      (expected.height - actual.height).abs() > 1) {
    throw ArgumentError(
      'The frame was captured at ${actual.width.round()}x'
      '${actual.height.round()} px, but ${device.name} is '
      '${expected.width.round()}x${expected.height.round()} px. Size the '
      'test view like the device (estimateGpu does), or pass a device that '
      'matches the test view.',
    );
  }
  final ops = LayerSynthesizer().synthesize(
    capture.root,
    capture.physicalSize,
  );
  final timeline = replayFrame(ops, device.gpu);
  return FrameEstimate._(
    device: device,
    timeline: timeline,
    traffic: MemoryTraffic.of(timeline, capture.physicalSize),
    layerTree: capture.root,
    missingPictures: capture.missingPictures,
  );
}
