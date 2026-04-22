import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class BallIcon extends StatelessWidget {
  const BallIcon({super.key, this.size = 20, this.color = MH.ball});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _BallPainter(color),
      );
}

class _BallPainter extends CustomPainter {
  const _BallPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final scale = s.width / 24.0;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale;
    canvas.drawCircle(Offset(12 * scale, 12 * scale), 10 * scale, ring);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round;

    final p1 = Path()
      ..moveTo(4 * scale, 8 * scale)
      ..cubicTo(
          7 * scale, 10 * scale, 14 * scale, 11 * scale, 20 * scale, 6 * scale);
    final p2 = Path()
      ..moveTo(7 * scale, 21 * scale)
      ..cubicTo(
          6 * scale, 17 * scale, 8 * scale, 10 * scale, 13 * scale, 5 * scale);
    final p3 = Path()
      ..moveTo(22 * scale, 14 * scale)
      ..cubicTo(17 * scale, 15 * scale, 10 * scale, 14 * scale, 6 * scale,
          20 * scale);
    canvas
      ..drawPath(p1, arc)
      ..drawPath(p2, arc)
      ..drawPath(p3, arc);
  }

  @override
  bool shouldRepaint(covariant _BallPainter old) => old.color != color;
}
