import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
// ignore: implementation_imports
import 'package:motor/src/simulations/curve_simulation.dart';

class ReverseCurveMotion extends CurvedMotion {
  const ReverseCurveMotion({
    required super.duration,
    super.curve = Curves.linear,
    this.reverseCurve,
  });

  final Curve? reverseCurve;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    final reverse = reverseCurve ?? curve;

    return CurveSimulation(
      curve: start < end ? curve : reverse,
      duration: duration,
      start: start,
      end: end,
      tolerance: tolerance,
    );
  }
}
