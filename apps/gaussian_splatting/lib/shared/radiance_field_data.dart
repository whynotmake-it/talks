// ========================= Data classes =========================

import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

class Blob { // r,g,b 0..1
  Blob({
    required this.center,
    required this.sigma,
    required this.density,
    required this.color,
  });
  final three.Vector3 center;
  final double sigma; // spatial stddev
  final double density; // scale
  final List<double> color;
}

class FieldSample {
  FieldSample(this.sigma, this.r, this.g, this.b);
  final double sigma;
  final double r;
  final double g;
  final double b;
}

class RayBoxHit {
  RayBoxHit(this.hit, this.t0, this.t1);
  final bool hit;
  final double t0;
  final double t1;
}

class SampleRecord {
  SampleRecord({
    required this.t,
    required this.sigma,
    required this.alpha,
    required this.tBefore,
    required this.w,
    required this.color,
    required this.p,
  });
  final double t;
  final double sigma;
  final double alpha;
  final double tBefore;
  final double w;
  final Color color;
  final three.Vector3 p;
}

class MarchResult {
  MarchResult(this.r, this.g, this.b, this.samples);
  final double r;
  final double g;
  final double b;
  final List<SampleRecord> samples;
}