import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:motor/motor.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotionExampleApp extends HookWidget {
  const MotionExampleApp({super.key, required this.motion});

  final Motion motion;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: DeviceFrame(
        device: Devices.ios.iPhone16,
        screen: CupertinoApp(
          home: _Scaffold(motion: motion),
        ),
      ),
    );
  }
}

class _Scaffold extends HookWidget {
  const _Scaffold({
    super.key,
    required this.motion,
  });

  final Motion motion;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: CupertinoButton.filled(
          child: const Text('Press Me'),
          onPressed: () {
            Navigator.of(context).push(
              _MySheetRoute(
                motion: motion,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MySheetRoute extends PopupRoute<void> {
  _MySheetRoute({
    required this.motion,
  }) : super();

  final Motion motion;

  @override
  bool get barrierDismissible => true;

  @override
  Simulation? createSimulation({required bool forward}) {
    return motion.createSimulation(
      end: forward ? 1.0 : 0.0,
      start: animation?.value ?? 0,
      velocity: dragEndVelocity ?? 0,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Container(
        color: Colors.red,
        child: Center(
          child: CupertinoButton.filled(
            child: Text(
              'Hello, World!',
            ),
            onPressed: Navigator.of(context).pop,
          ),
        ),
      ),
    );
  }

  double? dragEndVelocity;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FractionalTranslation(
      translation: Offset(0, 1 - animation.value),
      child: GestureDetector(
        onVerticalDragStart: (details) =>
            Navigator.of(context).didStartUserGesture(),
        onVerticalDragEnd: (details) {
          final minV =
              -details.velocity.pixelsPerSecond.dy.abs() > kMinFlingVelocity;
          final minD = controller!.value < 0.9;

          if (minV || minD) {
            dragEndVelocity =
                -details.velocity.pixelsPerSecond.dy / context.size!.height;
            Navigator.of(context).pop();
          }
          Navigator.of(context).didStopUserGesture();
        },
        onVerticalDragCancel: () => Navigator.of(context).didStopUserGesture(),
        onVerticalDragUpdate: (details) {
          controller?.value -= details.primaryDelta! / context.size!.height;
        },

        child: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: child,
        ),
      ),
    );
  }

  @override
  bool get opaque => false;

  @override
  bool get maintainState => false;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Durations.medium4;
}
