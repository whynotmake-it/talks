// Traces every validation scene on a real GPU and compares the render
// passes per frame with what impeller_model predicted.
//
//   flutter test test/predict_test.dart        # writes predictions.json
//   dart run tool/validate.dart macos [--no-build] [--scene <name>]
//
// Uses Instruments' Metal System Trace (xctrace, headless). Every
// Impeller render encoder carries its label (debug and profile builds),
// e.g. "EntityPass Render Pass" or "Gaussian Blur Filter". The app keeps
// redrawing the same scene, so each trace holds ~hundreds of identical
// frames; encoders of one frame arrive in a burst and are grouped by time.
//
// Writes results/<target>.md and results/<target>.json.
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

/// The pinned SDK (3.47.1): set FLUTTER, or run with that SDK on PATH.
final _flutter = Platform.environment['FLUTTER'] ?? 'flutter';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first != 'macos') {
    stderr.writeln(
      'usage: dart run tool/validate.dart macos [--no-build] [--scene name]',
    );
    exitCode = 2;
    return;
  }
  const target = 'macos';
  final build = !args.contains('--no-build');
  final only = args.contains('--scene')
      ? args[args.indexOf('--scene') + 1]
      : null;
  const predictionTarget = 'macos';

  final predictions =
      ((jsonDecode(File('predictions.json').readAsStringSync())
                  as Map)['targets']
              as Map)[predictionTarget]
          as Map;

  if (build) {
    await _run(_flutter, ['build', 'macos', '--profile']);
  }
  const app = 'build/macos/Build/Products/Profile/impeller_validation.app';

  // A --scene run updates that scene and keeps the other results.
  final results = <String, Map<String, Object?>>{
    if (only != null && File('results/$target.json').existsSync())
      for (final e
          in (jsonDecode(File('results/$target.json').readAsStringSync())
                  as Map)
              .entries)
        e.key as String: (e.value as Map).cast<String, Object?>(),
  };
  for (final entry in predictions.entries) {
    final scene = entry.key as String;
    if (only != null && scene != only) continue;
    final predicted = entry.value as Map;
    stdout.writeln('== $scene');
    final trace = 'build/traces/$target-$scene.trace';
    Directory(trace).parent.createSync(recursive: true);
    if (Directory(trace).existsSync()) {
      Directory(trace).deleteSync(recursive: true);
    }
    await _run(
      'xcrun',
      [
        'xctrace',
        'record',
        '--template',
        'Metal System Trace',
        '--time-limit',
        '4s',
        '--output',
        trace,
        '--env',
        'IMPELLER_SCENE=$scene',
        '--launch',
        '--',
        app,
        // 54: "Run issues were detected (trace is still ready to be viewed)".
      ],
      okExitCodes: {0, 54},
    );
    // The launched app outlives the recording.
    Process.runSync('pkill', ['-x', 'impeller_validation']);
    final frames = _framesFromTrace(trace);
    final measured = _steadyFrame(frames);
    final expected = {
      for (final e in (predicted['renderPassesByLabel'] as Map).entries)
        e.key as String: e.value as int,
    };
    // The copy of an offscreen root to the screen is a blit on Metal, not
    // a render encoder: compare it separately.
    final match =
        _sameCounts(measured.renderPasses, expected) &&
        (predicted['blit'] == true) == (measured.blits > 0);
    results[scene] = {
      'match': match,
      'predicted': expected,
      'measured': measured.renderPasses,
      'measuredBlits': measured.blits,
      'predictedBlit': predicted['blit'],
      'framesInTrace': frames.length,
      'framesLikeThis': measured.count,
      'approximate': predicted['approximate'],
    };
    stdout.writeln(
      '   ${match ? 'MATCH' : 'DIFF '} predicted $expected '
      'blit=${predicted['blit']}, measured ${measured.renderPasses} '
      'blits=${measured.blits} '
      '(${measured.count}/${frames.length} frames)',
    );
  }

  Directory('results').createSync();
  File('results/$target.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(results)}\n',
  );
  File('results/$target.md').writeAsStringSync(_markdown(target, results));
  stdout.writeln('Wrote results/$target.md');
}

class _Frame {
  _Frame(this.renderPasses, this.blits);
  final Map<String, int> renderPasses;
  final int blits;
  String get key =>
      '${(renderPasses.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).join(',')} blits=$blits';
}

class _Steady {
  _Steady(this.renderPasses, this.blits, this.count);
  final Map<String, int> renderPasses;
  final int blits;
  final int count;
}

/// Encoders from the app process, grouped into frames: a gap of more than
/// 2 ms between encoder creations starts a new frame.
List<_Frame> _framesFromTrace(String trace) {
  final xml =
      Process.runSync('xcrun', [
            'xctrace',
            'export',
            '--input',
            trace,
            '--xpath',
            '/trace-toc/run[@number="1"]/data/table[@schema="metal-application-encoders-list"]',
          ]).stdout
          as String;
  final doc = XmlDocument.parse(xml);
  final columns = [
    for (final c in doc.findAllElements('col'))
      c.getElement('mnemonic')!.innerText,
  ];
  final values = <String, String>{};
  String value(XmlElement e) {
    final ref = e.getAttribute('ref');
    if (ref != null) return values[ref] ?? '';
    for (final d in [e, ...e.descendantElements]) {
      final id = d.getAttribute('id');
      if (id != null) values[id] = d.getAttribute('fmt') ?? d.innerText;
    }
    return e.getAttribute('fmt') ?? e.innerText;
  }

  final rows = <({int t, String encoder})>[];
  for (final row in doc.findAllElements('row')) {
    final cells = row.childElements.toList();
    String col(String name) {
      final i = columns.indexOf(name);
      return i < 0 || i >= cells.length ? '' : value(cells[i]);
    }

    final start = int.tryParse(
      cells[columns.indexOf('start')].innerText.trim(),
    );
    // Resolve every cell in order so ids defined in this row are known.
    for (final c in cells) {
      value(c);
    }
    if (start == null) continue;
    rows.add((t: start, encoder: col('encoder-label')));
  }
  rows.sort((a, b) => a.t.compareTo(b.t));

  final frames = <_Frame>[];
  var current = <String, int>{};
  var blits = 0;
  int? last;
  void flush() {
    if (current.isNotEmpty || blits > 0) frames.add(_Frame(current, blits));
    current = {};
    blits = 0;
  }

  for (final r in rows) {
    if (last != null && r.t - last > 2000000) flush();
    last = r.t;
    const prefix = 'RenderPass & ';
    if (r.encoder.startsWith(prefix)) {
      final label = r.encoder.substring(prefix.length);
      current[label] = (current[label] ?? 0) + 1;
    } else if (r.encoder.toLowerCase().contains('blit')) {
      blits++;
    }
  }
  flush();
  return frames;
}

/// The most common frame shape after the first second (startup frames
/// upload glyphs and shaders).
_Steady _steadyFrame(List<_Frame> frames) {
  final steady = frames.length > 40 ? frames.sublist(20) : frames;
  final counts = <String, int>{};
  final byKey = <String, _Frame>{};
  for (final f in steady) {
    counts[f.key] = (counts[f.key] ?? 0) + 1;
    byKey[f.key] = f;
  }
  if (counts.isEmpty) return _Steady({}, 0, 0);
  final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  final f = byKey[best.key]!;
  return _Steady(f.renderPasses, f.blits, best.value);
}

bool _sameCounts(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

String _markdown(String target, Map<String, Map<String, Object?>> results) {
  final b = StringBuffer()
    ..writeln('# Validation: $target')
    ..writeln()
    ..writeln(
      'Render passes per frame, by Impeller label: impeller_model '
      'prediction vs. Metal System Trace of the validation app '
      '(`dart run tool/validate.dart $target`).',
    )
    ..writeln()
    ..writeln(
      '| Scene | Predicted | Measured | Blit predicted / measured | '
      'Frames like this | |',
    )
    ..writeln('|---|---|---|---|---|---|');
  String fmt(Object? m) => (m as Map).isEmpty
      ? '–'
      : [for (final e in m.entries) '${e.value}× ${e.key}'].join('<br>');
  var matches = 0;
  for (final e in results.entries) {
    final r = e.value;
    if (r['match'] == true) matches++;
    b.writeln(
      '| `${e.key}` | ${fmt(r['predicted'])} | '
      '${fmt(r['measured'])} | '
      '${r['predictedBlit'] == true ? 'yes' : 'no'} / '
      '${(r['measuredBlits'] as int? ?? 0) > 0 ? 'yes' : 'no'} | '
      '${r['framesLikeThis']}/${r['framesInTrace']} | '
      '${r['match'] == true ? '✓' : '✗'}${r['approximate'] == true ? ' (approx.)' : ''} |',
    );
  }
  b
    ..writeln()
    ..writeln('$matches of ${results.length} scenes match.');
  return b.toString();
}

Future<void> _run(
  String exe,
  List<String> args, {
  Set<int> okExitCodes = const {0},
}) async {
  final p = await Process.start(exe, args, mode: ProcessStartMode.inheritStdio);
  final code = await p.exitCode;
  if (!okExitCodes.contains(code)) {
    throw ProcessException(exe, args, 'exit $code', code);
  }
}
