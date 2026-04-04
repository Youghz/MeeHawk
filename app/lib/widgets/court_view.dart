import 'dart:math';
import 'package:flutter/material.dart';

class PlayerPosition {
  final int id;
  final double x; // meters
  final double y; // meters
  final Color color;

  PlayerPosition({required this.id, required this.x, required this.y, required this.color});
}

class CourtView extends StatelessWidget {
  final List<PlayerPosition> players;
  final double width;

  static const courtW = 8.0;
  static const courtL = 16.0;
  static const pad = 1.0;

  const CourtView({super.key, this.players = const [], this.width = 220});

  @override
  Widget build(BuildContext context) {
    final totalW = courtW + pad * 2;
    final totalL = courtL + pad * 2;
    final height = width * (totalL / totalW);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _CourtPainter(players: players, courtWidth: width),
      ),
    );
  }
}

class _CourtPainter extends CustomPainter {
  final List<PlayerPosition> players;
  final double courtWidth;

  _CourtPainter({required this.players, required this.courtWidth});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = CourtView.pad;
    const cw = CourtView.courtW;
    const cl = CourtView.courtL;
    final scale = size.width / (cw + pad * 2);

    double toX(double m) => (m + pad) * scale;
    double toY(double m) => (m + pad) * scale;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xFF1A1A2E),
    );

    // Sand
    final courtRect = Rect.fromLTWH(toX(0), toY(0), cw * scale, cl * scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(courtRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFFC2956A).withValues(alpha: 0.25),
    );

    // Court outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(courtRect, const Radius.circular(2)),
      Paint()
        ..color = const Color(0xFFC2956A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Net
    final netY = toY(cl / 2);
    final dashPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    for (double x = toX(0); x < toX(cw); x += 9) {
      canvas.drawLine(
        Offset(x, netY),
        Offset(min(x + 6, toX(cw)), netY),
        dashPaint,
      );
    }

    // Players
    final playerRadius = 0.4 * scale;
    for (final p in players) {
      final px = toX(p.x.clamp(0, cw));
      final py = toY(p.y.clamp(0, cl));

      canvas.drawCircle(
        Offset(px, py),
        playerRadius,
        Paint()..color = p.color.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        Offset(px, py),
        playerRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${p.id}',
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, py - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CourtPainter old) => true;
}
