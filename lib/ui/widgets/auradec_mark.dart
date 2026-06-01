import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Faithful replica of the React AuradecMark SVG:
/// 3 concentric dashed rings + 5 EQ bar lines.
class AuradecMark extends StatelessWidget {
  final double size;
  const AuradecMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size,
      child: CustomPaint(painter: _MarkPainter()));
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    final scale = sz.width / 100.0;

    // Outer ring: r=38, gold, dashed 14/8, opacity 0.45
    _dashedCircle(canvas, cx, cy, 38 * scale,
        const Color(0xFFF5B32A), 1.3 * scale, 14 * scale, 8 * scale, 0.45);

    // Middle ring: r=28, gold, dashed 26/7, opacity 0.75
    _dashedCircle(canvas, cx, cy, 28 * scale,
        const Color(0xFFF5B32A), 1.7 * scale, 26 * scale, 7 * scale, 0.75);

    // Inner ring: r=18, orange, dashed 50/5, opacity 1.0
    _dashedCircle(canvas, cx, cy, 18 * scale,
        const Color(0xFFFF5C1A), 2.2 * scale, 50 * scale, 5 * scale, 1.0);

    // EQ bars (5 vertical lines, orange, strokeWidth 2, linecap round)
    final barPaint = Paint()
      ..color = const Color(0xFFFF5C1A)
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;

    // x positions: 42, 46, 50, 54, 58
    // y ranges (top, bottom): (53,49), (55,45), (57,43), (55,45), (53,49)
    final bars = [
      [42.0, 53.0, 49.0],
      [46.0, 55.0, 45.0],
      [50.0, 57.0, 43.0],
      [54.0, 55.0, 45.0],
      [58.0, 53.0, 49.0],
    ];
    for (final b in bars) {
      canvas.drawLine(
        Offset(b[0] * scale, b[1] * scale),
        Offset(b[0] * scale, b[2] * scale),
        barPaint,
      );
    }
  }

  void _dashedCircle(Canvas canvas, double cx, double cy, double r,
      Color color, double strokeWidth, double dashLen, double gapLen, double opacity) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final circumference = 2 * math.pi * r;
    final total = dashLen + gapLen;
    final count = circumference / total;
    final actualTotal = circumference / count;
    final actualDash = actualTotal * (dashLen / total);

    final path = Path();
    var angle = -math.pi / 2;
    final step = actualTotal / r;
    final dashAngle = actualDash / r;

    while (angle < 3 * math.pi / 2) {
      final endAngle = angle + dashAngle;
      path.addArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        angle, math.min(dashAngle, 3 * math.pi / 2 - angle));
      angle += step;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
