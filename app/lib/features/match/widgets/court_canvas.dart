import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:flutter/material.dart';

/// The painted court surface — sand texture, inner dashed border, net and
/// team names. No gestures, no overlays, no state mutation.
class CourtCanvas extends StatelessWidget {
  const CourtCanvas({
    required this.state,
    required this.leftTeam,
    required this.rightTeam,
    required this.leftColor,
    required this.rightColor,
    required this.courtWidth,
    super.key,
  });

  final MatchState state;
  final TeamSide leftTeam;
  final TeamSide rightTeam;
  final Color leftColor;
  final Color rightColor;
  final double courtWidth;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: MH.sand,
            border: Border.all(color: MH.ink, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _SandTexturePainter()),
              ),
            ),
            const Positioned(
              left: 6,
              right: 6,
              top: 6,
              bottom: 6,
              child: CustomPaint(painter: _DashedInnerPainter()),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: courtWidth / 2 - 1.5,
              width: 3,
              child: Container(color: MH.ink),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: courtWidth / 2 - 7,
              width: 14,
              child: const CustomPaint(painter: _NetPainter()),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IgnorePointer(
                child: Text(
                  state.teams[leftTeam]!.name.toUpperCase(),
                  style: MH.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: leftColor,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: IgnorePointer(
                child: Text(
                  state.teams[rightTeam]!.name.toUpperCase(),
                  style: MH.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: rightColor,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _SandTexturePainter extends CustomPainter {
  const _SandTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MH.pencil.withValues(alpha: 0.25);
    for (double y = 0; y < size.height; y += 8) {
      for (double x = 0; x < size.width; x += 8) {
        canvas
          ..drawCircle(Offset(x + 2, y + 2), 0.6, paint)
          ..drawCircle(Offset(x + 6, y + 5), 0.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SandTexturePainter old) => false;
}

class _DashedInnerPainter extends CustomPainter {
  const _DashedInnerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MH.inkSoft.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashW = 4.0;
    const gap = 4.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        final seg = m.extractPath(d, d + dashW);
        canvas.drawPath(seg, paint);
        d += dashW + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedInnerPainter old) => false;
}

class _NetPainter extends CustomPainter {
  const _NetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MH.ink.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetPainter old) => false;
}
