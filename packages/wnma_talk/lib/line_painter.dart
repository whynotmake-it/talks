import 'dart:ui';
import 'package:flutter/material.dart';

class LinePainter extends CustomPainter {
  final List<Offset> points;
  final Gradient? gradient;
  final double thickness;
  final Color? color;

  LinePainter({
    required this.points,
    this.gradient,
    this.thickness = 2.0,
    this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final scaledPoints = <Offset>[];

    for (final point in points) {
      final scaledX = point.dx * size.width;
      final scaledY = point.dy * size.height;
      scaledPoints.add(Offset(scaledX, scaledY));
    }

    if (scaledPoints.isNotEmpty) {
      path.moveTo(scaledPoints.first.dx, scaledPoints.first.dy);

      for (var i = 1; i < scaledPoints.length; i++) {
        path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
      }
    }

    if (gradient != null) {
      final bounds = path.getBounds();
      paint.shader = gradient!.createShader(bounds);
    } else if (color != null) {
      paint.color = color!;
    } else {
      paint.color = Colors.black;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return points != oldDelegate.points ||
        gradient != oldDelegate.gradient ||
        thickness != oldDelegate.thickness ||
        color != oldDelegate.color;
  }
}

class LinePathWidget extends StatelessWidget {
  final List<Offset> points;
  final Gradient? gradient;
  final double thickness;
  final Color? color;
  final Size? size;

  const LinePathWidget({
    Key? key,
    required this.points,
    this.gradient,
    this.thickness = 2.0,
    this.color,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size ?? Size.infinite,
      painter: LinePainter(
        points: points,
        gradient: gradient,
        thickness: thickness,
        color: color,
      ),
    );
  }
}
