import 'dart:math' as math;

import 'package:app/core/theme.dart';
import 'package:app/domain/match_state.dart';
import 'package:flutter/material.dart';

/// Draws the ball trajectory during a rally.
///
/// Lines crossing the net (net crossings) are drawn solid with an arrowhead.
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

  // Radius of the ImpactMarker circle (22px diameter / 2).
  static const _kMarkerR = 11.0;

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
      final aCenter =
          Offset(impacts[i - 1].x * outerW, impacts[i - 1].y * outerH);
      final bCenter = Offset(impacts[i].x * outerW, impacts[i].y * outerH);

      final delta = bCenter - aCenter;
      final dist = delta.distance;
      if (dist < 2) continue;

      final dir = delta / dist;
      // Clamp offset so it never exceeds 40 % of segment length on each side.
      final off = _kMarkerR.clamp(0.0, dist * 0.40);
      final a = aCenter + dir * off;
      final b = bCenter - dir * off;

      final isNetCrossing = impacts[i - 1].isServerPosition ||
          impacts[i - 1].teamSide != impacts[i].teamSide;

      if (isNetCrossing) {
        canvas.drawLine(a, b, solidPaint);
        _drawFletching(canvas, solidPaint, a, b);
      } else {
        _drawDashedLine(canvas, dashedPaint, a, b);
      }
    }
  }

  /// Small chevron ticks along the shaft pointing backward — one at 35 % and
  /// one at 65 % of the segment length.
  void _drawFletching(Canvas canvas, Paint paint, Offset a, Offset b) {
    const tickLen = 5.0;
    const tickAngle = 0.52; // ~30° — spread of each wing from backward direction
    final delta = b - a;
    final dist = delta.distance;
    if (dist < 28) return;
    final dirX = delta.dx / dist;
    final dirY = delta.dy / dist;
    // Backward direction (opposite of travel).
    final bdX = -dirX;
    final bdY = -dirY;

    for (final t in [0.35, 0.65]) {
      final center = Offset(a.dx + delta.dx * t, a.dy + delta.dy * t);
      for (final sign in [-1.0, 1.0]) {
        final ang = tickAngle * sign;
        final cosA = math.cos(ang);
        final sinA = math.sin(ang);
        final wX = bdX * cosA - bdY * sinA;
        final wY = bdX * sinA + bdY * cosA;
        canvas.drawLine(
          center,
          Offset(center.dx + wX * tickLen, center.dy + wY * tickLen),
          paint,
        );
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
