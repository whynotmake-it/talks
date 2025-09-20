import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/radiance_field_data.dart';

class SensorView extends StatelessWidget {
  const SensorView({
    required this.image,
    required this.w,
    required this.h,
    required this.onTapPixel,
    required this.selectedU,
    required this.selectedV,
    super.key,
  });
  final List<Color> image;
  final int w;
  final int h;
  final void Function(int u, int v) onTapPixel;
  final int selectedU;
  final int selectedV;

  @override
  Widget build(BuildContext context) {
    final double cell = 16; // px per cell in UI
    return GestureDetector(
      onTapDown: (d) {
        final box = context.findRenderObject()! as RenderBox;
        final local = box.globalToLocal(d.globalPosition);
        final u = (local.dx / cell).floor().clamp(0, w - 1);
        final v = (local.dy / cell).floor().clamp(0, h - 1);
        onTapPixel(u, v);
      },
      child: CustomPaint(
        size: Size(w * cell, h * cell),
        painter: _SensorPainter(
          image: image,
          w: w,
          h: h,
          selectedU: selectedU,
          selectedV: selectedV,
        ),
      ),
    );
  }
}

class _SensorPainter extends CustomPainter {
  _SensorPainter({
    required this.image,
    required this.w,
    required this.h,
    required this.selectedU,
    required this.selectedV,
  });
  final List<Color> image;
  final int w;
  final int h;
  final int selectedU;
  final int selectedV;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / w;
    final p = Paint()..style = PaintingStyle.fill;

    for (var v = 0; v < h; v++) {
      for (var u = 0; u < w; u++) {
        p.color = image[v * w + u];
        canvas.drawRect(
          Rect.fromLTWH(u * cell, v * cell, cell + 0.5, cell + 0.5),
          p,
        );
      }
    }

    // Selected pixel outline
    final sel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withOpacity(0.8);
    canvas.drawRect(
      Rect.fromLTWH(selectedU * cell, selectedV * cell, cell, cell),
      sel,
    );
  }

  @override
  bool shouldRepaint(covariant _SensorPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.selectedU != selectedU ||
        oldDelegate.selectedV != selectedV;
    // repaint on changes
  }
}

class RayDetail extends StatelessWidget {
  const RayDetail({
    required this.samples,
    required this.rayStep,
    required this.showTransmittance,
    super.key,
  });
  final List<SampleRecord> samples;
  final double rayStep;
  final bool showTransmittance;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No hit / outside volume')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 120),
          painter: _RayDetailPainter(
            samples: samples,
            showTransmittance: showTransmittance,
          ),
        );
      },
    );
  }
}

class _RayDetailPainter extends CustomPainter {
  _RayDetailPainter({required this.samples, required this.showTransmittance});
  final List<SampleRecord> samples;
  final bool showTransmittance;

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 10.0;
    final width = size.width - padding * 2;
    final height = size.height - padding * 2;

    // Top row: dots for samples along t (x-axis), opacity by alpha, 
    // size by Tbefore
    final rowH = height ;
    final tMin = samples.first.t;
    final tMax = samples.last.t;
    double xForT(double t) =>
        padding + (t - tMin) / (tMax - tMin + 1e-6) * width;

    // Guides
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(padding, padding, width, rowH), guide);

    for (final s in samples.reversed) {
      final x = xForT(s.t);
      final y = padding + rowH / 2;
      final dot = Paint()
        ..style = PaintingStyle.fill
        ..color = s.color.withOpacity((s.alpha).clamp(0.05, 1.0));
      final r = 56.0;
      // Draw a rounded rectangle (RRect) at (x, y) with radius r and paint dot
      final rect = Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 2);
      final rrect = RRect.fromRectXY(rect, r * 0.7, r * 0.7); // 0.7 for a squircle-like roundness
      canvas.drawRRect(rrect, dot);
    }



    if (showTransmittance) {
      // Overdraw T(t) curve over the top row
      final path = Path();
      var first = true;
      for (final s in samples) {
        final xx = xForT(s.t);
        final yy = padding + rowH * (1 - s.tBefore);
        if (first) {
          path.moveTo(xx, yy);
          first = false;
        } else {
          path.lineTo(xx, yy);
        }
      }
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.deepOrange;
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(covariant _RayDetailPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.showTransmittance != showTransmittance;
  }
}

// ========================= UI bits =========================

class ControlCard extends StatelessWidget {
  const ControlCard({
    required this.title, 
    required this.child, 
    this.width,
    this.height,
    super.key,
  });
  final String title;
  final Widget child;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).cardTheme.color,

      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Only use Expanded if we have a height constraint
              if (height != null) 
                Expanded(child: child)
              else
                child,
            ],
          ),
        ),
      ),
    );
  }
}
