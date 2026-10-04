// Checks every engine/framework source quote in this package against a
// Flutter SDK checkout, and lists the quotes an SDK upgrade touches.
//
//   dart run tool/engine_refs.dart [--flutter-root <sdk>] [--diff-to <git ref>]
//
// A quote is a fenced block inside a Dart comment:
//
//   /// ```engine impeller/display_list/canvas.cc
//   ///   if (can_distribute_opacity && !backdrop_filter &&
//   /// ```
//
// `engine` paths are relative to `<sdk>/engine/src/flutter/`, `framework`
// paths to `<sdk>/packages/`. Matching ignores whitespace differences.
//
// Without --diff-to: verifies every quote exists in the checkout (the pinned
// version, see lib/src/engine/revision.dart). Exit code 1 if any is missing.
//
// With --diff-to <ref> (a tag or commit in the SDK git repo, e.g. 3.48.0):
// for every quoted file that changed between the pinned version and <ref>,
// prints the quotes in it and whether each still exists at <ref>. Quotes
// that vanished point at logic that must be re-ported.
import 'dart:io';

final _open = RegExp(r'^```(engine|framework) (\S+)\s*$');
final _comment = RegExp(r'^\s*///? ?');

class Quote {
  Quote(this.kind, this.path, this.source, this.line, this.text);
  final String kind;
  final String path;
  final String source;
  final int line;
  final String text;

  String get sdkPath =>
      kind == 'engine' ? 'engine/src/flutter/$path' : 'packages/$path';
  String get location => '$source:$line';
}

String normalize(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

List<Quote> collectQuotes(Directory root) {
  final quotes = <Quote>[];
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('/.dart_tool/'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final m = _comment.firstMatch(lines[i]);
      if (m == null) continue;
      final open = _open.firstMatch(lines[i].substring(m.end));
      if (open == null) continue;
      final body = <String>[];
      var j = i + 1;
      for (; j < lines.length; j++) {
        final c = _comment.firstMatch(lines[j]);
        final rest = c == null ? lines[j] : lines[j].substring(c.end);
        if (rest.trim() == '```') break;
        body.add(rest);
      }
      quotes.add(
        Quote(
          open.group(1)!,
          open.group(2)!,
          file.path.replaceFirst('${root.path}/', ''),
          i + 1,
          body.join('\n'),
        ),
      );
      i = j;
    }
  }
  return quotes;
}

String? pinnedVersion(Directory root) {
  final f = File('${root.path}/lib/src/engine/revision.dart');
  final m = RegExp(
    "pinnedFlutterVersion = '([^']+)'",
  ).firstMatch(f.readAsStringSync());
  return m?.group(1);
}

String? gitShow(String sdk, String ref, String path) {
  final r = Process.runSync('git', ['-C', sdk, 'show', '$ref:$path']);
  return r.exitCode == 0 ? r.stdout as String : null;
}

void main(List<String> args) {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final pkg = Directory(
    File(Platform.script.toFilePath()).parent.parent.path,
  );
  final pinned = pinnedVersion(pkg)!;
  final fvmPinned = '${Platform.environment['HOME']}/fvm/versions/$pinned';
  final sdk =
      arg('--flutter-root') ??
      (Directory(fvmPinned).existsSync()
          ? fvmPinned
          : Platform.environment['FLUTTER_ROOT']);
  if (sdk == null) {
    stderr.writeln('Pass --flutter-root <Flutter $pinned checkout>.');
    exitCode = 2;
    return;
  }
  final describe = Process.runSync('git', [
    '-C',
    sdk,
    'describe',
    '--tags',
    '--exact-match',
  ]);
  final sdkVersion = (describe.stdout as String).trim();
  if (sdkVersion != pinned) {
    stderr.writeln(
      'Warning: $sdk is at "$sdkVersion", the quotes are pinned to $pinned.',
    );
  }
  final diffTo = arg('--diff-to');
  final quotes = collectQuotes(Directory('${pkg.path}/lib'))
    ..addAll(collectQuotes(Directory('${pkg.path}/tool')))
    ..removeWhere((q) => q.source.endsWith('engine_refs.dart'));

  if (diffTo == null) {
    var missing = 0;
    final cache = <String, String?>{};
    for (final q in quotes) {
      final content = cache.putIfAbsent(q.sdkPath, () {
        final f = File('$sdk/${q.sdkPath}');
        return f.existsSync() ? normalize(f.readAsStringSync()) : null;
      });
      if (content == null) {
        missing++;
        stdout.writeln('MISSING FILE  ${q.location}  ${q.sdkPath}');
      } else if (!content.contains(normalize(q.text))) {
        missing++;
        stdout.writeln('MISSING QUOTE ${q.location}  ${q.sdkPath}');
        stdout.writeln('    ${q.text.split('\n').first.trim()} ...');
      }
    }
    final files = quotes.map((q) => q.sdkPath).toSet();
    stdout.writeln(
      '${quotes.length - missing}/${quotes.length} quotes found '
      '(${files.length} engine/framework files) in $sdk '
      '(pinned: $pinned).',
    );
    exitCode = missing == 0 ? 0 : 1;
    return;
  }

  // An unknown or unfetched ref would make every `git diff` fail, which
  // reads like "every quote changed". Check both refs first.
  for (final ref in [pinned, diffTo]) {
    final r = Process.runSync('git', [
      '-C',
      sdk,
      'rev-parse',
      '--verify',
      '--quiet',
      '$ref^{commit}',
    ]);
    if (r.exitCode != 0) {
      stderr.writeln(
        'Unknown ref "$ref" in $sdk. Fetch it first: '
        'git -C $sdk fetch origin tag $ref',
      );
      exitCode = 2;
      return;
    }
  }

  final byFile = <String, List<Quote>>{};
  for (final q in quotes) {
    byFile.putIfAbsent(q.sdkPath, () => []).add(q);
  }
  final changed = <String>[];
  for (final path in byFile.keys.toList()..sort()) {
    final r = Process.runSync('git', [
      '-C',
      sdk,
      'diff',
      '--quiet',
      pinned,
      diffTo,
      '--',
      path,
    ]);
    if (r.exitCode != 0) changed.add(path);
  }
  stdout.writeln(
    '${changed.length} of ${byFile.length} quoted files changed '
    'between $pinned and $diffTo.\n',
  );
  var vanished = 0;
  for (final path in changed) {
    final next = gitShow(sdk, diffTo, path);
    final norm = next == null ? null : normalize(next);
    stdout.writeln('## $path${next == null ? '  (deleted or moved)' : ''}');
    stdout.writeln('   git -C $sdk diff $pinned $diffTo -- $path');
    for (final q in byFile[path]!) {
      final ok = norm != null && norm.contains(normalize(q.text));
      if (!ok) vanished++;
      stdout.writeln(
        '   ${ok ? 'still there' : 'CHANGED    '}  ${q.location}  '
        '${q.text.split('\n').first.trim()}',
      );
    }
    stdout.writeln();
  }
  stdout.writeln(
    '$vanished quotes no longer match at $diffTo. Re-port those, then '
    'bump lib/src/engine/revision.dart.',
  );
}
