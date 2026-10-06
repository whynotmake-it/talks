import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import 'scenes.dart';

/// Renders one validation scene and keeps redrawing it, so a GPU trace sees
/// many identical frames to count passes in.
///
/// The scene is chosen by, in order: the `IMPELLER_SCENE` environment
/// variable (macOS/iOS, e.g. `xctrace record --env IMPELLER_SCENE=...`),
/// the initial route (Android: `adb shell am start ... --es route plain`),
/// or `--dart-define=SCENE=...`.
void main() {
  final name = _sceneName();
  final scene = scenes[name] ?? scenes['plain']!;
  runApp(
    _KeepDrawing(
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: Builder(builder: scene.build),
      ),
    ),
  );
}

String _sceneName() {
  final env = Platform.environment['IMPELLER_SCENE'];
  if (env != null && env.isNotEmpty) return env;
  final route = ui.PlatformDispatcher.instance.defaultRouteName;
  if (route != '/') return route.replaceFirst('/', '');
  return const String.fromEnvironment('SCENE', defaultValue: 'plain');
}

/// Requests a frame after every frame without changing anything, the way a
/// running ticker does. Every frame is a full repaint of the same scene.
class _KeepDrawing extends StatefulWidget {
  const _KeepDrawing({required this.child});
  final Widget child;

  @override
  State<_KeepDrawing> createState() => _KeepDrawingState();
}

class _KeepDrawingState extends State<_KeepDrawing> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      SchedulerBinding.instance.scheduleFrame();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
