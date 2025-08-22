import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:motor/motor.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotionExampleApp extends HookWidget {
  const MotionExampleApp({
    required this.motion,
    this.unboundedMotion = true,
    super.key,
  });

  final Motion motion;
  final bool unboundedMotion;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: DeviceFrame(
        device: Devices.ios.iPhone16,
        screen: CupertinoApp(
          debugShowCheckedModeBanner: false,
          home: _Scaffold(
            motion: motion,
            unboundedMotion: unboundedMotion,
          ),
        ),
      ),
    );
  }
}

class _Scaffold extends HookWidget {
  const _Scaffold({
    required this.motion,
    required this.unboundedMotion,
  });

  final Motion motion;
  final bool unboundedMotion;

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
                child: _SheetContent(),
                unboundedMotion: unboundedMotion,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.lightBackgroundGray,
      child: CustomScrollView(
        primary: true,
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Motion Example'),
            automaticallyImplyLeading: false,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'This is a motion example app with a custom sheet transition.',
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ListTile(
                title: Text('Item $index'),
                onTap: () {},
              ),
              childCount: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _MySheetRoute extends PopupRoute<void> {
  _MySheetRoute({
    required this.motion,
    required this.child,
    this.unboundedMotion = true,
  }) : super();

  final Motion motion;

  final Widget child;

  final bool unboundedMotion;

  ScrollController? _scrollController = ScrollController();

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
    return ClipRSuperellipse(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      child: MediaQuery.removePadding(
        removeTop: true,
        context: context,
        child: child,
      ),
    );
  }

  double? dragEndVelocity;

  bool _shouldDismiss(double velocity, double currentValue) {
    // Constants for dismissal logic
    const dismissThreshold = 0.5; // Dismiss if dragged more than 50% down
    const velocityThreshold = 300.0; // Pixels per second

    // High downward velocity should dismiss regardless of position
    if (velocity > velocityThreshold) {
      return true;
    }

    // High upward velocity should not dismiss regardless of position
    if (velocity < -velocityThreshold) {
      return false;
    }

    // For low velocities, use position-based logic
    return currentValue < dismissThreshold;
  }

  @override
  AnimationController createAnimationController() {
    if (!unboundedMotion) return super.createAnimationController();
    assert(
      !debugTransitionCompleted(),
      'Cannot reuse a $runtimeType after disposing it.',
    );
    final duration = transitionDuration;
    final reverseDuration = reverseTransitionDuration;
    return AnimationController.unbounded(
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    );
  }

  bool _isDragging = false;
  DragUpdateDetails? _lastScrollUpdateDetails;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        switch (notification) {
          case final ScrollStartNotification n:
            if (n.dragDetails != null) {
              _handleDragStart(context, n.dragDetails!);
            }
          case final ScrollUpdateNotification n:
            if (n.dragDetails case final DragUpdateDetails details) {
              _isDragging = true;
              _lastScrollUpdateDetails = n.dragDetails;

              // When we are overscrolling at the top
              if (n.metrics.extentBefore == 0) {
                _handleDragUpdate(context, n.dragDetails!);
              }
            } else {
              if (_isDragging) {
                _isDragging = false;
                _handleDragEnd(context, DragEndDetails());
              }
            }
          case final ScrollEndNotification n:
            if (n.dragDetails case final details?) {
              _handleDragEnd(context, details!);
            }
        }
        return true;
      },
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;

          var transformedChild = child;

          if (value > 1.0) {
            // When dragged beyond normal bounds, scale from bottom
            final scale = value;
            transformedChild = Transform.scale(
              scaleY: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            );
          } else {
            // Normal slide up transition
            transformedChild = FractionalTranslation(
              translation: Offset(0, 1 - value),
              child: child,
            );
          }

          return GestureDetector(
            onVerticalDragStart: (details) =>
                _handleDragStart(context, details),
            onVerticalDragEnd: (details) {
              _handleDragEnd(context, details);
            },
            onVerticalDragUpdate: (details) {
              _handleDragUpdate(context, details);
            },

            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: transformedChild,
            ),
          );
        },
      ),
    );
  }

  void _handleDragStart(
    BuildContext context,
    DragStartDetails startDetails,
  ) {
    Navigator.of(context).didStartUserGesture();
  }

  void _handleDragUpdate(
    BuildContext context,
    DragUpdateDetails updateDetails,
  ) {
    final delta = updateDetails.primaryDelta! / context.size!.height;
    final newValue = (controller?.value ?? 0) - delta;
    controller?.value = newValue;
  }

  void _handleDragEnd(
    BuildContext context,
    DragEndDetails details,
  ) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final currentValue = controller!.value;

    // Determine if we should dismiss based on velocity and position
    final shouldDismiss = _shouldDismiss(velocity, currentValue);

    dragEndVelocity = -velocity / context.size!.height;

    if (shouldDismiss) {
      Navigator.of(context).pop();
    } else {
      final backSim = motion.createSimulation(
        start: currentValue,
        velocity: dragEndVelocity!,
      );
      controller!.animateWith(backSim);
    }
    Navigator.of(context).didStopUserGesture();
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
