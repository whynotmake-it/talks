import 'dart:convert';
import '../capture/binding.dart';
import 'canvas_replay.dart';
import 'capabilities.dart';
import 'driver.dart';
import 'synthesize.dart';

/// One frame's full estimate across capability profiles.
class FrameReport {
  FrameReport({required this.timelines, required this.meta});

  final List<PassTimeline> timelines;
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => {
    'meta': meta,
    'profiles': timelines.map((t) => t.toJson()).toList(),
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Run the model on a [FrameCapture] for every given profile.
FrameReport analyzeFrame(
  FrameCapture capture, {
  List<CapabilityProfile> profiles = const [
    CapabilityProfile.iphone,
    CapabilityProfile.iosSimulator,
    CapabilityProfile.vulkanFetch,
    CapabilityProfile.vulkanNoFetch,
  ],
}) {
  if (capture.root == null) {
    return FrameReport(timelines: const [], meta: {'error': 'no layer tree'});
  }
  final synth = LayerSynthesizer(pictures: capture.pictures);
  final ops = synth.synthesize(capture.root!, capture.physicalSize);
  final timelines = profiles
      .map((p) => replayFrame(ops, p))
      .toList(growable: false);
  return FrameReport(
    timelines: timelines,
    meta: {
      'physicalSize': [capture.physicalSize.width, capture.physicalSize.height],
      // Pinned semantics — see FEASIBILITY.md (the engine source verified
      // against is the 3.47.1 FVM checkout).
      'engineRevision': 'flutter-3.47.1',
      'dpr': capture.devicePixelRatio,
      'opCount': ops.ops.length,
      'rootHasBackdropFilter': ops.rootHasBackdropFilter,
      'maxRootBlendMode': ops.maxRootBlendMode.name,
      if (capture.pictureMismatch != null)
        'pictureMismatch':
            'layers=${capture.pictureMismatch!.pictureLayers} recorders=${capture.pictureMismatch!.recorders}',
      // The raw frame description — captured layer tree + recorded op
      // stream — for inspection against the model output.
      'layerTree': capture.root!.toJson(),
      'pictures': [
        for (var i = 0; i < capture.pictures.length; i++)
          [for (final op in capture.pictures[i]) op.toJson()],
      ],
    },
  );
}

/// A minimal static HTML/SVG timeline of passes per profile.
///
/// Rows = passes in submission order, width = target size relative to the
/// screen, color = reason.
String renderTimelineHtml(FrameReport report) {
  const colors = {
    'root': '#3b82f6',
    'root-readback': '#3b82f6',
    'flip-restart': '#f59e0b',
    'flip→onscreen': '#22c55e',
    'onscreen-blit': '#a855f7',
    'onscreen-copy-pass': '#a855f7',
  };
  String colorFor(String reason) =>
      colors[reason] ??
      (reason.startsWith('backdrop')
          ? '#ef4444'
          : reason.startsWith('blur') || reason.startsWith('shared')
          ? '#ef4444'
          : reason.startsWith('blend') || reason.startsWith('restore-blend')
          ? '#f97316'
          : '#64748b');

  final buf = StringBuffer()
    ..writeln('<!doctype html><meta charset="utf-8">')
    ..writeln('<title>Impeller pass estimate</title>')
    ..writeln(
      '<style>body{font-family:ui-monospace,monospace;background:'
      '#0f172a;color:#e2e8f0;padding:16px}'
      '.pass{display:flex;align-items:center;margin:3px 0;gap:8px}'
      '.bar{height:18px;border-radius:3px;min-width:3px}'
      '.meta{opacity:.7;font-size:12px}'
      'h2{font-size:14px;margin:18px 0 6px}</style>',
    );

  final screenW = report.meta['physicalSize'] is List
      ? (report.meta['physicalSize'] as List).first as num
      : 400;
  for (final t in report.timelines) {
    buf.writeln(
      '<h2>${_esc(t.profile.name)} — ${t.passes.length} passes, '
      '${t.flips} flips, ~${_mb(t.estimatedTrafficBytes)} MB traffic</h2>',
    );
    for (final p in t.passes) {
      final w = screenW <= 0
          ? 560
          : (p.size.width / screenW * 520).clamp(3, 560);
      buf.writeln(
        '<div class="pass">'
        '<div class="bar" style="width:${w}px;background:${colorFor(p.reason)}"></div>'
        '<span>${_esc(p.label)} <span class="meta">'
        '${p.size.width.round()}×${p.size.height.round()} · ${_esc(p.reason)} · '
        '${p.drawCount} draws · ~${_mb(p.estimatedTrafficBytes)} MB'
        '</span></span></div>',
      );
    }
  }
  return buf.toString();
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
