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
    return Material(
      color: Colors.red,
      child: SizedBox(
        height: 100,
      ),
    );
  }
}

class ScrollAwareGestureDetector extends StatefulWidget {
  const ScrollAwareGestureDetector({
    super.key,
    required this.child,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
  });

  final Widget child;

  /// A pointer has contacted the screen with a primary button and might begin
  /// to move vertically.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragDownCallback? onVerticalDragDown;

  /// A pointer has contacted the screen with a primary button and has begun to
  /// move vertically.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragStartCallback? onVerticalDragStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving vertically has moved in the vertical direction.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragUpdateCallback? onVerticalDragUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving vertically is no longer in contact with the screen and
  /// was moving at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragEndCallback? onVerticalDragEnd;

  /// The pointer that previously triggered [onVerticalDragDown] did not
  /// complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragCancelCallback? onVerticalDragCancel;

  /// A pointer has contacted the screen with a primary button and might begin
  /// to move horizontally.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragDownCallback? onHorizontalDragDown;

  /// A pointer has contacted the screen with a primary button and has begun to
  /// move horizontally.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragStartCallback? onHorizontalDragStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving horizontally has moved in the horizontal direction.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragUpdateCallback? onHorizontalDragUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving horizontally is no longer in contact with the screen and
  /// was moving at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragEndCallback? onHorizontalDragEnd;

  /// The pointer that previously triggered [onHorizontalDragDown] did not
  /// complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragCancelCallback? onHorizontalDragCancel;

  @override
  State<ScrollAwareGestureDetector> createState() =>
      _ScrollAwareGestureDetectorState();
}

class _ScrollAwareGestureDetectorState
    extends State<ScrollAwareGestureDetector> {
  final _isDragging = ValueNotifier(false);

  DragStartDetails? _dragStartDetails;

  @override
  void dispose() {
    _isDragging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: GestureDetector(
        onVerticalDragStart: widget.onVerticalDragStart,
        onVerticalDragUpdate: widget.onVerticalDragUpdate,
        onVerticalDragEnd: widget.onVerticalDragEnd,
        onVerticalDragCancel: widget.onVerticalDragCancel,
        onHorizontalDragStart: widget.onHorizontalDragStart,
        onHorizontalDragUpdate: widget.onHorizontalDragUpdate,
        onHorizontalDragEnd: widget.onHorizontalDragEnd,
        onHorizontalDragCancel: widget.onHorizontalDragCancel,
        child: ValueListenableBuilder(
          valueListenable: _isDragging,
          builder: (context, value, child) {
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                physics: value ? const _OverscrollScrollPhysics() : null,
              ),
              child: child!,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    switch (notification) {
      case ScrollStartNotification(:final dragDetails):
        _dragStartDetails = dragDetails;
      case ScrollUpdateNotification(
        :final metrics,
        :final dragDetails,
      ):
        if (dragDetails != null) {
          // When we are overscrolling at the top
          if (metrics.extentBefore <= 0 &&
              dragDetails.primaryDelta != null &&
              dragDetails.primaryDelta! > 0) {
            if (!_isDragging.value) {
              _isDragging.value = true;
              _handleDragStart(metrics.axis);
            } else {
              _handleDragUpdate(metrics.axis, dragDetails);
            }
          }
        }
      case OverscrollNotification(
        :final metrics,
        :final dragDetails,
        :final velocity,
      ):
        if (dragDetails != null) {
          // When we are overscrolling at the top
          if (metrics.extentBefore <= 0) {
            if (!_isDragging.value) {
              _isDragging.value = true;
              _handleDragStart(metrics.axis);
            } else {
              _handleDragUpdate(metrics.axis, dragDetails);
            }
          }
        } else {
          if (_isDragging.value) {
            _isDragging.value = false;
            _handleDragEnd(
              metrics.axis,
              DragEndDetails(
                primaryVelocity: -velocity,
                velocity: Velocity(
                  pixelsPerSecond: switch (metrics.axis) {
                    Axis.vertical => Offset(0, -velocity),
                    Axis.horizontal => Offset(-velocity, 0),
                  },
                ),
              ),
            );
          }
        }

      case final ScrollEndNotification n:
        if (_isDragging.value) {
          _isDragging.value = false;
          _handleDragEnd(n.metrics.axis, n.dragDetails ?? DragEndDetails());
        }
    }
    return true;
  }

  void _handleDragStart(Axis axis) {
    if (_dragStartDetails case final details?) {
      if (axis == Axis.vertical) {
        widget.onVerticalDragStart?.call(details);
      } else {
        widget.onHorizontalDragStart?.call(details);
      }
    }
  }

  void _handleDragUpdate(Axis axis, DragUpdateDetails details) {
    if (axis == Axis.vertical) {
      widget.onVerticalDragUpdate?.call(details);
    } else {
      widget.onHorizontalDragUpdate?.call(details);
    }
  }

  void _handleDragEnd(Axis axis, DragEndDetails details) {
    if (axis == Axis.vertical) {
      widget.onVerticalDragEnd?.call(details);
    } else {
      widget.onHorizontalDragEnd?.call(details);
    }
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

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
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

          return ScrollAwareGestureDetector(
            onVerticalDragStart: (details) => _handleDragStart(context),
            onVerticalDragEnd: (details) {
              _handleDragEnd(context, details);
            },
            onVerticalDragUpdate: (details) {
              _handleDragUpdate(context, details);
            },

            child: transformedChild,
          );
        },
      ),
    );
  }

  void _handleDragStart(
    BuildContext context,
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

/// Scroll physics that don't allow moving from the current position and just
/// always send an overscroll notification.
class _OverscrollScrollPhysics extends ClampingScrollPhysics {
  const _OverscrollScrollPhysics({super.parent});

  @override
  _OverscrollScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _OverscrollScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(
    ScrollMetrics position,
    double value,
  ) {
    return value - position.pixels;
  }
}
