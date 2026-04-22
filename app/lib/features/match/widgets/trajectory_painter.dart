import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:flutter/material.dart';

/// Draws dashed lines between consecutive impacts to visualize the ball
/// trajectory during a rally or the replay of a historical point.
class TrajectoryPainter extends CustomPainter {
  TrajectoryPainter({
    required this.impacts,
    required this.outerW,
    required this.outerH,
  });

  final List<BallImpact> impacts;
  final double outerW;
  final double outerH;

  @override
  void paint(Canvas canvas, Size size) {
    if (impacts.length < 2) return;
    final paint = Paint()
      ..color = MH.pencil.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < impacts.length; i++) {
      final a = Offset(impacts[i - 1].x * outerW, impacts[i - 1].y * outerH);
      final b = Offset(impacts[i].x * outerW, impacts[i].y * outerH);
      _drawDashedLine(canvas, paint, a, b);
    }
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset a, Offset b) {
    const dash = 5.0;
    const gap = 4.0;
    final delta = b - a;
    final dist = delta.distance;
    if (dist == 0) return;
    final unit = delta / dist;
    double traveled = 0;
    while (traveled < dist) {
      final segEnd = (traveled + dash).clamp(0.0, dist);
      canvas.drawLine(a + unit * traveled, a + unit * segEnd, paint);
      traveled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant TrajectoryPainter old) =>
      old.impacts != impacts ||
      old.outerW != outerW ||
      old.outerH != outerH;
}
