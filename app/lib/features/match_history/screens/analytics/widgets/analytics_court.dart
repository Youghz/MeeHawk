import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

enum AnalyticsDotKind { ace, won, fault, lost }

class AnalyticsDot {
  const AnalyticsDot({required this.x, required this.y, required this.kind});
  final double x;
  final double y;
  final AnalyticsDotKind kind;
}

class AnalyticsCourt extends StatelessWidget {
  const AnalyticsCourt({required this.dots, this.halfCourt = false, super.key});
  final List<AnalyticsDot> dots;
  final bool halfCourt;

  static const _m = 30.0;
  static const _mHalf = 20.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final m = halfCourt ? _mHalf : _m;
          final courtW = w - m * 2;
          final courtH = halfCourt ? courtW * 0.65 : courtW / 2;
          final h = courtH + m * 2;
          return SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                    painter: CourtBgPainter(m, halfCourt: halfCourt)),
              ),
              for (final d in dots)
                Positioned(
                  left: m + d.x * courtW - 6,
                  top: m + d.y * courtH - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (d.kind) {
                        AnalyticsDotKind.ace => const Color(0xFF86EFAC),
                        AnalyticsDotKind.won => MH.good,
                        AnalyticsDotKind.fault => const Color(0xFFFCA5A5),
                        AnalyticsDotKind.lost => MH.bad,
                      },
                    ),
                  ),
                ),
            ]),
          );
        },
      );
}

class CourtBgPainter extends CustomPainter {
  const CourtBgPainter(this.margin, {this.halfCourt = false});
  final double margin;
  final bool halfCourt;

  @override
  void paint(Canvas canvas, Size size) {
    final inner = Rect.fromLTWH(
        margin, margin, size.width - margin * 2, size.height - margin * 2);

    canvas
      ..drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = MH.ruleSoft)
      ..drawRect(inner, Paint()..color = MH.sand);

    if (!halfCourt) {
      canvas.drawLine(
        Offset(size.width / 2, margin),
        Offset(size.width / 2, size.height - margin),
        Paint()
          ..color = MH.pencil
          ..strokeWidth = 1.5,
      );
    } else {
      canvas.drawLine(
        Offset(margin, margin),
        Offset(margin, size.height - margin),
        Paint()
          ..color = MH.inkSoft
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawRect(
        inner,
        Paint()
          ..color = MH.rule
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(CourtBgPainter old) =>
      old.margin != margin || old.halfCourt != halfCourt;
}

class ServiceDotLegend extends StatelessWidget {
  const ServiceDotLegend({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _LegendItem(color: Color(0xFF86EFAC), label: 'Ace'),
          _LegendItem(color: MH.good, label: 'Gagné'),
          _LegendItem(color: Color(0xFFFCA5A5), label: 'Faute'),
          _LegendItem(color: MH.bad, label: 'Perdu'),
        ],
      );
}

class ReceptionDotLegend extends StatelessWidget {
  const ReceptionDotLegend({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _LegendItem(color: MH.good, label: 'Réception gagnée'),
          _LegendItem(color: MH.bad, label: 'Réception perdue'),
          _LegendItem(color: Color(0xFFFCA5A5), label: 'Ace adverse'),
        ],
      );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(label, style: MH.sans(size: 11, color: MH.inkSoft)),
        ],
      );
}
