import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotionExampleApp extends HookWidget {
  const MotionExampleApp({
    required this.motion,
    this.recorder,
    super.key,
  });

  final Motion motion;
  final ValueRecordingNotifier<double>? recorder;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: DeviceFrame(
        device: Devices.ios.iPhone16,
        screen: CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: _Scaffold(
            motion: motion,
            recorder: recorder,
          ),
        ),
      ),
    );
  }
}

class _Scaffold extends HookWidget {
  const _Scaffold({
    required this.motion,
    required this.recorder,
  });

  final Motion motion;
  final ValueRecordingNotifier<double>? recorder;

  @override
  Widget build(BuildContext context) {
    final test = true;

    return CupertinoPageScaffold(
      child: Center(
        child: CupertinoButton.filled(
          onPressed: test
              ? () {
                  Navigator.of(context).push(
                    SheetTransitionRoute(
                      motion: motion,
                      builder: (context) => _SheetContent(),
                      recorder: recorder,
                    ),
                  );
                }
              : null,
          child: const Text('Press Me'),
        ),
      ),
    );
  }
}

class _SheetContent extends HookWidget {
  const _SheetContent();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: CupertinoButton.tinted(
          child: const Text('Go Back'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class SheetTransitionRoute extends PopupRoute<void>
    with StupidSimpleSheetTransitionMixin {
  SheetTransitionRoute({
    required this.motion,
    required this.builder,
    this.recorder,
  });

  final ValueRecordingNotifier<double>? recorder;

  @override
  final Motion motion;

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => Colors.black26;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  void install() {
    super.install();
    controller?.addListener(_recordAnimationValue);
  }

  @override
  Widget buildContent(BuildContext context) => SafeArea(
    bottom: false,
    child: builder(context),
  );

  void _recordAnimationValue() {
    if (controller?.value case final v?) {
      recorder?.record(v);
    }
  }

  @override
  void dispose() {
    recorder?.removeListener(_recordAnimationValue);
    super.dispose();
  }
}
