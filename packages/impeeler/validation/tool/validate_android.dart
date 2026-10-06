// Runs every validation scene on an attached Android device with a Vulkan
// layer that logs each frame's render passes, and compares them with what
// impeeler predicted for the Pixel 10 (PowerVR, no framebuffer
// fetch).
//
//   flutter test test/predict_test.dart        # writes predictions.json
//   dart run tool/validate_android.dart [--no-build] [--scene <name>]
//
// Vulkan builds of Impeller carry no debug labels, so the comparison is
// the number of render passes per frame and their sizes. The layer
// (tool/vk_pass_logger) is built with the NDK and copied into the app's
// data directory, which Android only allows for debuggable apps, hence the
// debug build. The pass structure does not depend on the build mode.
//
// The script enables GPU debug layers for this one app through
// `settings put global` and deletes those settings again when it ends.
//
// Writes results/pixel10.md and results/pixel10.json.
import 'dart:convert';
import 'dart:io';

/// The pinned SDK (3.47.1): set FLUTTER, or run with that SDK on PATH.
final _flutter = Platform.environment['FLUTTER'] ?? 'flutter';
const _package = 'it.whynotmake.impeller_validation';
const _layer = 'VK_LAYER_impeller_pass_logger';
const _layerFile = 'libVkLayer_impeller_pass_logger.so';

Future<void> main(List<String> args) async {
  final build = !args.contains('--no-build');
  final only = args.contains('--scene')
      ? args[args.indexOf('--scene') + 1]
      : null;
  final predictions =
      ((jsonDecode(File('predictions.json').readAsStringSync())
                  as Map)['targets']
              as Map)['pixel10']
          as Map;

  if (build) {
    await _run(_flutter, ['build', 'apk', '--debug']);
  }
  final so = '${Directory.systemTemp.path}/$_layerFile';
  await _run(_ndkClang(), [
    '-shared',
    '-fPIC',
    '-O2',
    '-std=c++17',
    '-static-libstdc++',
    'tool/vk_pass_logger/pass_logger.cpp',
    '-llog',
    '-o',
    so,
  ]);
  await _run('adb', [
    'install',
    '-r',
    'build/app/outputs/flutter-apk/app-debug.apk',
  ]);
  await _run('adb', ['push', so, '/data/local/tmp/$_layerFile']);
  await _run('adb', [
    'shell',
    'run-as',
    _package,
    'cp',
    '/data/local/tmp/$_layerFile',
    '.',
  ]);

  // A --scene run updates that scene and keeps the other results.
  final results = <String, Map<String, Object?>>{
    if (only != null && File('results/pixel10.json').existsSync())
      for (final e
          in (jsonDecode(File('results/pixel10.json').readAsStringSync())
                  as Map)
              .entries)
        e.key as String: (e.value as Map).cast<String, Object?>(),
  };
  try {
    for (final kv in {
      'enable_gpu_debug_layers': '1',
      'gpu_debug_app': _package,
      'gpu_debug_layers': _layer,
    }.entries) {
      await _run('adb', [
        'shell',
        'settings',
        'put',
        'global',
        kv.key,
        kv.value,
      ]);
    }
    for (final entry in predictions.entries) {
      final scene = entry.key as String;
      if (only != null && scene != only) continue;
      final predicted = entry.value as Map;
      stdout.writeln('== $scene');
      // A sleeping or locked phone renders nothing.
      await _run('adb', ['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP']);
      await _run('adb', ['shell', 'wm', 'dismiss-keyguard']);
      await _run('adb', ['shell', 'am', 'force-stop', _package]);
      await _run('adb', ['logcat', '-c']);
      await _run('adb', [
        'shell',
        'am',
        'start',
        '-n',
        '$_package/.MainActivity',
        '--es',
        'route',
        '/$scene',
      ]);
      await Future<void>.delayed(const Duration(seconds: 5));
      final log =
          Process.runSync('adb', [
                'logcat',
                '-d',
                '-s',
                'ImpellerPasses:I',
              ]).stdout
              as String;
      final frames = _frames(log);
      if (frames.isEmpty) {
        throw StateError(
          'No frames logged for $scene. Is the phone unlocked, and does the '
          'app start? (adb logcat -s ImpellerPasses)',
        );
      }
      final steady = _steady(frames);
      final expected = [
        for (final p in predicted['passes'] as List)
          if (!(p as String).startsWith('Blit')) _sizeOf(p),
      ]..sort();
      final match = _sameSizes(steady.sizes, expected);
      results[scene] = {
        'match': match,
        'predicted': predicted['passes'],
        'predictedSizes': expected,
        'measured': steady.passes,
        'framesInLog': frames.length,
        'framesLikeThis': steady.count,
      };
      stdout.writeln(
        '   ${match ? 'MATCH' : 'DIFF '} predicted ${expected.length} '
        '$expected, measured ${steady.passes.length} ${steady.passes} '
        '(${steady.count}/${frames.length} frames)',
      );
    }
  } finally {
    await _run('adb', ['shell', 'am', 'force-stop', _package]);
    for (final key in [
      'enable_gpu_debug_layers',
      'gpu_debug_app',
      'gpu_debug_layers',
    ]) {
      await _run('adb', ['shell', 'settings', 'delete', 'global', key]);
    }
  }

  Directory('results').createSync();
  File('results/pixel10.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(results)}\n',
  );
  File('results/pixel10.md').writeAsStringSync(_markdown(results));
  stdout.writeln('Wrote results/pixel10.md');
}

String _ndkClang() {
  final sdk =
      Platform.environment['ANDROID_HOME'] ??
      '${Platform.environment['HOME']}/Library/Android/sdk';
  final ndks = Directory('$sdk/ndk').listSync().map((e) => e.path).toList()
    ..sort();
  final host = Platform.isMacOS ? 'darwin-x86_64' : 'linux-x86_64';
  return '${ndks.last}/toolchains/llvm/prebuilt/$host/bin/'
      'aarch64-linux-android29-clang++';
}

/// "EntityPass Render Pass 1080x2424 (offscreenRoot)" -> "1080x2424".
String _sizeOf(String pass) =>
    RegExp(r'(\d+x\d+) \(').firstMatch(pass)!.group(1)!;

/// One list of "WxHxSamples" per logged frame, for the device that
/// rendered the most passes (Flutter's, not HWUI's).
List<List<String>> _frames(String log) {
  final re = RegExp(r'device (\d+) frame \d+: \d+ passes:(.*)$');
  final byDevice = <String, List<List<String>>>{};
  for (final line in const LineSplitter().convert(log)) {
    final m = re.firstMatch(line);
    if (m == null) continue;
    final passes = m.group(2)!.trim().split(' ').where((p) => p.isNotEmpty);
    byDevice.putIfAbsent(m.group(1)!, () => []).add(passes.toList());
  }
  if (byDevice.isEmpty) return [];
  return byDevice.values.reduce(
    (a, b) =>
        a.fold<int>(0, (n, f) => n + f.length) >=
            b.fold<int>(0, (n, f) => n + f.length)
        ? a
        : b,
  );
}

class _Steady {
  _Steady(this.passes, this.count);
  final List<String> passes;
  final int count;
  List<String> get sizes =>
      [for (final p in passes) p.substring(0, p.lastIndexOf('x'))]..sort();
}

_Steady _steady(List<List<String>> frames) {
  final steady = frames.length > 40 ? frames.sublist(20) : frames;
  final counts = <String, int>{};
  for (final f in steady) {
    final k = f.join(' ');
    counts[k] = (counts[k] ?? 0) + 1;
  }
  if (counts.isEmpty) return _Steady([], 0);
  final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return _Steady(best.key.split(' '), best.value);
}

/// Same number of passes, and every size within 2 px (sizes are rounded
/// differently in a few places).
bool _sameSizes(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  List<int> wh(String s) => s.split('x').map(int.parse).toList();
  for (var i = 0; i < a.length; i++) {
    final x = wh(a[i]);
    final y = wh(b[i]);
    if ((x[0] - y[0]).abs() > 2 || (x[1] - y[1]).abs() > 2) return false;
  }
  return true;
}

String _markdown(Map<String, Map<String, Object?>> results) {
  final b = StringBuffer()
    ..writeln(
      '# Validation: Pixel 10 (PowerVR DXT-48, Vulkan, no framebuffer fetch)',
    )
    ..writeln()
    ..writeln(
      'Render passes per frame: impeeler prediction vs. a Vulkan '
      'layer logging `vkCmdBeginRenderPass` in the validation app '
      '(`dart run tool/validate_android.dart`). Vulkan passes carry no '
      'labels, so sizes are compared (sorted; `×4` = 4x MSAA).',
    )
    ..writeln()
    ..writeln('| Scene | Predicted | Measured | Frames like this | |')
    ..writeln('|---|---|---|---|---|');
  var matches = 0;
  for (final e in results.entries) {
    final r = e.value;
    if (r['match'] == true) matches++;
    final predicted = (r['predicted'] as List).join('<br>');
    final measured = (r['measured'] as List)
        .map(
          (p) => (p as String).replaceFirstMapped(
            RegExp(r'x(\d+)$'),
            (m) => ' ×${m.group(1)}',
          ),
        )
        .join('<br>');
    b.writeln(
      '| `${e.key}` | $predicted | $measured | '
      '${r['framesLikeThis']}/${r['framesInLog']} | '
      '${r['match'] == true ? '✓' : '✗'} |',
    );
  }
  b
    ..writeln()
    ..writeln('$matches of ${results.length} scenes match.');
  return b.toString();
}

Future<void> _run(String exe, List<String> args) async {
  final p = await Process.start(exe, args);
  final out = await p.stdout.transform(utf8.decoder).join();
  final err = await p.stderr.transform(utf8.decoder).join();
  final code = await p.exitCode;
  if (code != 0) {
    stderr
      ..writeln(out)
      ..writeln(err);
    throw ProcessException(exe, args, 'exit $code', code);
  }
}
