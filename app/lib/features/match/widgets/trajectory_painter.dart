import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:flutter/material.dart';

/// Draws the ball trajectory during a rally.
///
/// Lines crossing the net (net crossings) are drawn solid — the ball flies
/// cleanly through the air.
/// Lines within the same possession (same teamSide) are drawn dashed to
/// visually separate each team's 1–3 preparatory touches.
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

    final solidPaint = Paint()
      ..color = MH.pencil.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final dashedPaint = Paint()
      ..color = MH.pencil.withValues(alpha: 0.28)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i < impacts.length; i++) {
      final a = Offset(impacts[i - 1].x * outerW, impacts[i - 1].y * outerH);
      final b = Offset(impacts[i].x * outerW, impacts[i].y * outerH);

      // A net crossing happens when the service is launched (isServerPosition)
      // or when the ball moves to the other team's side.
      final isNetCrossing = impacts[i - 1].isServerPosition ||
          impacts[i - 1].teamSide != impacts[i].teamSide;

      if (isNetCrossing) {
        canvas.drawLine(a, b, solidPaint);
      } else {
        _drawDashedLine(canvas, dashedPaint, a, b);
      }
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
      old.impacts != impacts || old.outerW != outerW || old.outerH != outerH;
}
