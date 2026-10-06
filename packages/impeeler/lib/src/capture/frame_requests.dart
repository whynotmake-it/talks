/// Who asked for a frame: turns the stack of a `scheduleFrame` /
/// `scheduleFrameCallback` call into a short, readable origin.
library;

/// One stack frame, parsed from a Dart VM stack trace line such as
/// `#3      Ticker.start (package:flutter/src/scheduler/ticker.dart:190:5)`.
class StackFrameInfo {
  StackFrameInfo(this.member, this.uri, this.line);

  final String member;
  final String uri;
  final int? line;

  static final _re = RegExp(r'^#\d+\s+(.+?) \((.+?)(?::(\d+))?(?::\d+)?\)$');

  static List<StackFrameInfo> parse(StackTrace trace) => [
    for (final l in trace.toString().split('\n'))
      if (_re.firstMatch(l.trim()) case final m?)
        StackFrameInfo(
          m.group(1)!,
          m.group(2)!,
          m.group(3) == null ? null : int.parse(m.group(3)!),
        ),
  ];

  bool get isFramework => uri.startsWith('package:flutter/');
  bool get isTestHarness =>
      uri.startsWith('package:flutter_test/') ||
      uri.startsWith('package:fake_async/');
  bool get isSdk => uri.startsWith('dart:');

  /// Package or app code: not the SDK, not Flutter, not test tooling.
  bool get isAppCode =>
      !isSdk &&
      !isFramework &&
      !uri.startsWith('package:flutter_test/') &&
      !uri.startsWith('package:fake_async/') &&
      !uri.startsWith('package:test_api/') &&
      !uri.startsWith('package:stack_trace/') &&
      !uri.startsWith('package:matcher/') &&
      !uri.startsWith('package:impeeler/');

  /// Framework plumbing between "something changed" and "schedule a
  /// frame": skipping it leaves the frame that caused the change.
  bool get isPlumbing {
    if (!isFramework) {
      return !isAppCode;
    }
    const plumbing = [
      'src/scheduler/',
      'src/foundation/',
      'src/animation/',
      'src/widgets/binding.dart',
      'src/widgets/framework.dart',
      'src/rendering/binding.dart',
      'src/rendering/object.dart',
    ];
    return plumbing.any(uri.contains);
  }

  String get shortUri {
    if (uri.startsWith('package:flutter/src/')) {
      return uri.substring('package:flutter/src/'.length);
    }
    return uri;
  }

  @override
  String toString() => '$member ($shortUri${line == null ? '' : ':$line'})';
}

/// The origin of a frame request.
class FrameRequestOrigin {
  FrameRequestOrigin({
    required this.description,
    required this.isTicker,
    required this.owner,
    this.appFrame,
  });

  /// Builds an origin from the stack of a frame request.
  factory FrameRequestOrigin.fromStack(StackTrace trace) {
    // Everything below the test harness (pump, fake timers, the test body)
    // is how the test drives time, not why the frame was requested.
    final frames = StackFrameInfo.parse(
      trace,
    ).takeWhile((f) => !f.isTestHarness).toList();
    final isTicker = frames.any(
      (f) =>
          f.uri.endsWith('scheduler/ticker.dart') &&
          (f.member.startsWith('Ticker.') ||
              f.member.contains('Ticker.scheduleTick')),
    );
    final meaningful = frames.where((f) => !f.isPlumbing).take(3).toList();
    final app = frames.where((f) => f.isAppCode).firstOrNull;
    final owner = app ?? meaningful.firstOrNull;
    return FrameRequestOrigin(
      description: meaningful.isEmpty
          ? (isTicker ? 'a Ticker' : 'the framework')
          : meaningful.join(' ← '),
      isTicker: isTicker,
      appFrame: app?.toString(),
      owner: owner == null
          ? (isTicker ? 'Ticker' : 'framework')
          : '${owner.member.split('.').first} (${owner.shortUri})',
    );
  }

  /// The first non-plumbing stack frames, most recent first.
  final String description;

  /// True when the request came from a `Ticker` (an animation).
  final bool isTicker;

  /// The first frame in app or package code, if any.
  final String? appFrame;

  /// The class (and file) that requested the frame, e.g.
  /// `EditableTextState (widgets/editable_text.dart)`. Requests from the
  /// same class are one source: the caret restarts its ticker from two
  /// methods, but it is one caret.
  final String owner;

  String get key => owner;

  Map<String, Object?> toJson() => {
    'owner': owner,
    'description': description,
    'ticker': isTicker,
    if (appFrame != null) 'appFrame': appFrame,
  };
}
