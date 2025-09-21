import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:rivership/rivership.dart';

class BounceFrictionMotion extends Motion {
  BounceFrictionMotion({
    this.startVelocity,
    this.endVelocity = 0.0,
    this.bounce = 0.5,
    this.min,
    this.max,
  });

  final double? startVelocity;

  final double endVelocity;

  final double bounce;

  final double? min;

  final double? max;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return BounceFrictionSimulation.through(
      start,
      end,
      startVelocity ?? velocity,
      endVelocity,
      min: min ?? math.min(start, end),
      max: max ?? math.max(start, end),
      bounce: bounce,
      tolerance: tolerance,
    );
  }

  @override
  bool get needsSettle => true;

  @override
  bool get unboundedWillSettle => false;

  @override
  bool operator ==(Object other) {
    return other is BounceFrictionMotion &&
        other.startVelocity == startVelocity &&
        other.endVelocity == endVelocity &&
        other.bounce == bounce &&
        other.min == min &&
        other.max == max;
  }

  @override
  int get hashCode => Object.hash(
    startVelocity,
    endVelocity,
    bounce,
    min,
    max,
  );
}

class _BounceState {
  _BounceState(this.time, this.position, this.velocity);

  final double time;
  final double position;
  final double velocity;
}

/// A [FrictionSimulation] that runs the normal friction simulation but bounces
/// off boundaries when the position would exceed [min] or [max].
///
/// Uses the same drag calculation as [FrictionSimulation.through] but when the
/// simulation would move outside the bounds, it:
/// - Reverses velocity direction  
/// - Multiplies velocity by [bounce] factor (energy loss)
/// - Continues simulating from the boundary position
///
/// Set [bounce] to 0 to stop at boundaries instead of bouncing.
class BounceFrictionSimulation extends FrictionSimulation {
  BounceFrictionSimulation({
    required double drag,
    required double position,
    required double velocity,
    required this.min,
    required this.max,
    required this.bounce,
    super.tolerance,
  }) : _initialPosition = position,
       _initialVelocity = velocity,
       _drag = drag,
       super(drag, position, velocity);

  /// Creates a new bounce friction simulation using the same drag calculation
  /// as [FrictionSimulation.through] but with bouncing off boundaries.
  factory BounceFrictionSimulation.through(
    double startPosition,
    double endPosition,
    double startVelocity,
    double endVelocity, {
    required double min,
    required double max,
    required double bounce,
    Tolerance? tolerance,
  }) {
    // Use the same drag calculation as FrictionSimulation.through
    final baseSim = FrictionSimulation.through(
      startPosition,
      endPosition,
      startVelocity,
      endVelocity,
    );
    
    // Extract drag coefficient by testing the simulation
    const testTime = 0.1;
    final testVel = baseSim.dx(testTime);
    var drag = 0.9; // fallback
    if (testVel != 0 && startVelocity != 0) {
      drag = math.pow(testVel / startVelocity, 1.0 / testTime) as double;
    }
    
    return BounceFrictionSimulation(
      drag: drag,
      position: startPosition,
      velocity: startVelocity,
      min: min,
      max: max,
      bounce: bounce,
      tolerance: tolerance ?? Tolerance.defaultTolerance,
    );
  }

  final double bounce;
  final double min;
  final double max;
  final double _initialPosition;
  final double _initialVelocity;
  final double _drag;

  final List<_BounceState> _bounceHistory = [];

  _BounceState? _getActiveState(double time) {
    // Find the most recent bounce state that applies to this time
    _BounceState? activeState;

    for (final state in _bounceHistory) {
      if (state.time <= time) {
        activeState = state;
      } else {
        break;
      }
    }

    return activeState;
  }

  void _calculateBounceIfNeeded(double time) {
    // Check if we already have a bounce calculated for this time or later
    if (_bounceHistory.isNotEmpty && _bounceHistory.last.time >= time) {
      return;
    }

    // Get the current active state
    final activeState =
        _getActiveState(time) ??
        _BounceState(0, _initialPosition, _initialVelocity);

    // Create a friction simulation from the active state
    final timeSinceState = time - activeState.time;
    final sim = FrictionSimulation(
      _drag,
      activeState.position,
      activeState.velocity,
      tolerance: tolerance,
    );

    final currentPos = sim.x(timeSinceState);

    // Check if position would exceed bounds
    if (currentPos < min || currentPos > max) {
      // Find the time when we hit the boundary
      final boundaryPos = currentPos < min ? min : max;
      final bounceTime = _findBoundaryHitTime(sim, boundaryPos, timeSinceState);
      final bounceVel = -sim.dx(bounceTime) * bounce;

      // Only add bounce if velocity is significant
      if (bounceVel.abs() > tolerance.velocity) {
        _bounceHistory.add(_BounceState(activeState.time + bounceTime, boundaryPos, bounceVel));
      }
    }
  }

  double _findBoundaryHitTime(FrictionSimulation sim, double boundaryPos, double maxTime) {
    // Binary search to find when position equals boundary
    double low = 0;
    double high = maxTime;
    
    for (int i = 0; i < 10; i++) { // 10 iterations should be enough precision
      final mid = (low + high) / 2;
      final pos = sim.x(mid);
      
      if ((boundaryPos > sim.x(0) && pos < boundaryPos) || 
          (boundaryPos < sim.x(0) && pos > boundaryPos)) {
        low = mid;
      } else {
        high = mid;
      }
    }
    
    return (low + high) / 2;
  }

  @override
  double x(double time) {
    _calculateBounceIfNeeded(time);

    final activeState =
        _getActiveState(time) ??
        _BounceState(0, _initialPosition, _initialVelocity);

    final timeSinceState = time - activeState.time;
    final sim = FrictionSimulation(
      _drag,
      activeState.position,
      activeState.velocity,
      tolerance: tolerance,
    );

    final result = sim.x(timeSinceState);
    
    // Check if we need an immediate bounce for this result
    if (result < min) {
      _addBounceIfNeeded(time, min, sim.dx(timeSinceState));
      return min;
    } else if (result > max) {
      _addBounceIfNeeded(time, max, sim.dx(timeSinceState));
      return max;
    }
    
    return result;
  }

  void _addBounceIfNeeded(double time, double bouncePos, double velocity) {
    // Don't add duplicate bounces
    if (_bounceHistory.isNotEmpty && (_bounceHistory.last.time - time).abs() < 0.001) {
      return;
    }
    
    final bounceVel = -velocity * bounce;
    if (bounceVel.abs() > tolerance.velocity) {
      _bounceHistory.add(_BounceState(time, bouncePos, bounceVel));
    }
  }

  @override
  double dx(double time) {
    _calculateBounceIfNeeded(time);

    final activeState =
        _getActiveState(time) ??
        _BounceState(0, _initialPosition, _initialVelocity);

    final timeSinceState = time - activeState.time;
    final sim = FrictionSimulation(
      _drag,
      activeState.position,
      activeState.velocity,
      tolerance: tolerance,
    );

    return sim.dx(timeSinceState);
  }

  @override
  bool isDone(double time) {
    final velocity = dx(time);
    return velocity.abs() < tolerance.velocity;
  }

  @override
  String toString() =>
      'BounceFrictionSimulation(drag: ${_drag.toStringAsFixed(3)}, x₀: ${_initialPosition.toStringAsFixed(1)}, dx₀: ${_initialVelocity.toStringAsFixed(1)}, bounce: ${bounce.toStringAsFixed(2)}, range: ${min.toStringAsFixed(1)}..${max.toStringAsFixed(1)})';
}
