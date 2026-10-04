/// Runs part of a widget test as if on a given device.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

import 'gpu_device.dart';

/// Sizes the test view like [device], sets its platform, rebuilds the tree,
/// runs [body], and restores both.
///
/// The platform matters for frame demand: adaptive widgets read
/// `defaultTargetPlatform` while building. A Material `TextField`
/// animates its caret every vsync on iOS and blinks it with a timer on
/// Android:
///
/// ```framework flutter/lib/src/material/text_field.dart
///       case TargetPlatform.iOS:
///         final CupertinoThemeData cupertinoTheme = CupertinoTheme.of(context);
///         forcePressEnabled = true;
///         textSelectionControls ??= cupertinoTextSelectionHandleControls;
///         paintCursorAboveText = true;
///         cursorOpacityAnimates ??= true;
/// ```
Future<T> onDevice<T>(
  WidgetTester tester,
  GpuDevice device,
  Future<T> Function() body,
) async {
  final previousOverride = debugDefaultTargetPlatformOverride;
  final builtFor = defaultTargetPlatform;
  final restoreView = setTestViewToFakeDevice(
    device.screen,
    Orientation.portrait,
  );
  debugDefaultTargetPlatformOverride = device.platform;
  if (device.platform != builtFor) {
    _rebuildAll();
  }
  await tester.pump();
  try {
    return await body();
  } finally {
    // snaptest's restore clears the override; put back the test's own.
    restoreView();
    debugDefaultTargetPlatformOverride = previousOverride;
    if (defaultTargetPlatform != device.platform) {
      _rebuildAll();
    }
    await tester.pump();
  }
}

/// Marks every element dirty so platform-dependent build decisions are
/// made again; State (focus, controllers) is kept.
void _rebuildAll() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}
