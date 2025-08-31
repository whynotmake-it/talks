import 'package:flutter/material.dart';

class LinePainter extends CustomPainter {
  LinePainter({
    required this.points,
    this.thickness = 2.0,
    this.fadeOutCurve,
    this.color,
  });

  final List<Offset> points;
  final double thickness;
  final Color? color;

  final Curve? fadeOutCurve;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final scaledPoints = <Offset>[];
    for (final point in points) {
      final scaledX = point.dx * size.width;
      final scaledY = point.dy * size.height;
      scaledPoints.add(Offset(scaledX, scaledY));
    }

    if (scaledPoints.length < 2) return;

    final baseColor = color ?? Colors.black;

    for (var i = 0; i < scaledPoints.length - 1; i++) {
      final progress = i / (scaledPoints.length - 1);
      final opacity = fadeOutCurve?.transform(progress) ?? 1.0;

      final paint = Paint()
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..color = baseColor.withValues(alpha: opacity);

      final segmentPath = Path()
        ..moveTo(scaledPoints[i].dx, scaledPoints[i].dy)
        ..lineTo(scaledPoints[i + 1].dx, scaledPoints[i + 1].dy);

      canvas.drawPath(segmentPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return points != oldDelegate.points ||
        fadeOutCurve != oldDelegate.fadeOutCurve ||
        thickness != oldDelegate.thickness ||
        color != oldDelegate.color;
  }
}

class LinePathWidget extends StatelessWidget {
  const LinePathWidget({
    required this.points,
    super.key,
    this.thickness = 2.0,
    this.color,
    this.fadeOutCurve,
  });

  final List<Offset> points;
  final double thickness;
  final Color? color;
  final Curve? fadeOutCurve;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LinePainter(
        points: points,
        fadeOutCurve: fadeOutCurve,
        thickness: thickness,
        color: color,
      ),
    );
  }
}
