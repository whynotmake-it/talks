import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:physical_ui/graphs/value_recording_notifier.dart';
import 'package:physical_ui/hooks/hooks.dart';
import 'package:physical_ui/shared/event_notifier.dart';
import 'package:rivership/rivership.dart';
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
    final buttonEnabled = useState(true);
    final earlyDisconnect = useDisposable(EventNotifier.new);
    return CupertinoPageScaffold(
      child: Center(
        child: AnimatedSizeSwitcher(
          child: CupertinoButton.filled(
            key: ValueKey(buttonEnabled.value),
            onPressed: buttonEnabled.value
                ? () {
                    earlyDisconnect.notifyListeners();
                    Navigator.of(context).push(
                      SheetTransitionRoute(
                        motion: motion,
                        builder: (context) => _SheetContent(),
                        earlyDisconnectFromRecorder: earlyDisconnect,
                        recorder: recorder,
                      ),
                    );
                  }
                : null,
            child: const Text('Press Me'),
          ),
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
        child: CupertinoButton.filled(
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
    required this.earlyDisconnectFromRecorder,
    this.recorder,
    this.onDisposed,
  });

  final ValueRecordingNotifier<double>? recorder;

  /// When this notifies its listeners, this route will stop reporting to
  /// [recorder].
  final Listenable earlyDisconnectFromRecorder;

  @override
  final Motion motion;

  final WidgetBuilder builder;

  final VoidCallback? onDisposed;

  @override
  Color? get barrierColor => Colors.black26;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  late bool _report = recorder != null;

  @override
  void install() {
    super.install();
    controller?.addListener(_recordAnimationValue);
    earlyDisconnectFromRecorder.addListener(_disconnectFromRecorder);
  }

  @override
  Widget buildContent(BuildContext context) => SafeArea(
    bottom: false,
    child: builder(context),
  );

  void _recordAnimationValue() {
    if (controller?.value case final v?) {
      if (_report) {
        recorder?.record(v);
      }
    }
  }

  void _disconnectFromRecorder() {
    if (!_report) return;
    _report = false;
    recorder?.removeListener(_recordAnimationValue);
  }

  @override
  void dispose() {
    _disconnectFromRecorder();
    earlyDisconnectFromRecorder.removeListener(_disconnectFromRecorder);
    onDisposed?.call();
    super.dispose();
  }
}
