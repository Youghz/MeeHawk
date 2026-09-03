import 'dart:math';

import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class AnalyticsSection extends StatelessWidget {
  const AnalyticsSection({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: MH.mono(
                  size: 9, weight: FontWeight.w700, letterSpacing: 1.2)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: MH.sans(size: 11, color: MH.pencil)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      );
}

class AnalyticsKeyRow extends StatelessWidget {
  const AnalyticsKeyRow({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(label, style: MH.sans(size: 12, color: MH.inkSoft)),
          ),
          Text(value, style: MH.mono(size: 13, weight: FontWeight.w600)),
        ],
      );
}

class AnalyticsStatLine extends StatelessWidget {
  const AnalyticsStatLine({
    required this.label,
    required this.wins,
    required this.total,
    super.key,
  });
  final String label;
  final int wins;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rate = total > 0 ? wins / total : 0.0;
    final dotColor =
        rate >= 0.6 ? MH.good : rate >= 0.4 ? MH.mid : MH.bad;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
            child: Text(label, style: MH.sans(size: 12, color: MH.inkSoft))),
        Text('$wins/$total', style: MH.mono(size: 12)),
        const SizedBox(width: 8),
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: dotColor)),
      ]),
    );
  }
}

class AnalyticsCompactBar extends StatelessWidget {
  const AnalyticsCompactBar({
    required this.label,
    required this.wins,
    required this.total,
    required this.color,
    super.key,
  });

  final String label;
  final int wins;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rate = total > 0 ? wins / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MH.sans(size: 10, color: MH.inkSoft)),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (_, c) {
                return Stack(children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: MH.sand,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  if (total > 0 && rate > 0)
                    Container(
                      width: c.maxWidth * rate,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ]);
              }),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 30,
              child: Text(
                total == 0 ? '—' : '${(rate * 100).round()}%',
                style: MH.mono(
                    size: 9,
                    color: total == 0 ? MH.pencil : MH.inkSoft),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AnalyticsLabeledBar extends StatelessWidget {
  const AnalyticsLabeledBar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
    this.winRatio,
    super.key,
  });
  final String label;
  final String value;
  final double ratio;
  final Color color;
  final double? winRatio;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: MH.sans(size: 12, color: MH.inkSoft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (ctx, c) {
              final barW = c.maxWidth * ratio.clamp(0.0, 1.0);
              final fillW = winRatio != null ? barW * winRatio! : barW;
              return Stack(children: [
                Container(
                    height: 10,
                    decoration: BoxDecoration(
                        color: MH.sand,
                        borderRadius: BorderRadius.circular(3))),
                if (barW > 0)
                  Container(
                      width: barW,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3))),
                if (fillW > 0)
                  Container(
                      width: fillW,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3))),
              ]);
            }),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Text(value,
                style: MH.mono(size: 9), textAlign: TextAlign.right),
          ),
        ],
      );
}

class AnalyticsRingStat extends StatelessWidget {
  const AnalyticsRingStat({
    required this.label,
    required this.count,
    required this.rate,
    required this.color,
    super.key,
  });
  final String label;
  final String count;
  final double rate;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: _ArcPainter(rate: rate, color: color),
              child: Center(
                child: Text(
                  '${(rate * 100).round()}%',
                  style: MH.sans(size: 13, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: MH.sans(size: 10, color: MH.pencil),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(count,
              style: MH.mono(size: 9, color: MH.inkSoft),
              textAlign: TextAlign.center),
        ],
      );
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.rate, required this.color});
  final double rate;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide - 16) / 2;
    final bg = Paint()
      ..color = MH.sand
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), -pi / 2, pi * 2, false, bg);
    if (rate > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2,
          pi * 2 * rate.clamp(0.0, 1.0), false, fg);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.rate != rate || o.color != color;
}

class AnalyticsSetFilter extends StatelessWidget {
  const AnalyticsSetFilter({
    required this.sets,
    required this.selected,
    required this.onSelect,
    super.key,
  });
  final List<int> sets;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        color: MH.paper,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          _Chip(
              label: 'Tout',
              active: selected == null,
              onTap: () => onSelect(null)),
          for (final s in sets)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _Chip(
                label: 'Set $s',
                active: selected == s,
                onTap: () => onSelect(selected == s ? null : s),
              ),
            ),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? MH.ink : MH.sand,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: MH.sans(
              size: 11,
              weight: FontWeight.w600,
              color: active ? MH.paper : MH.inkSoft,
            ),
          ),
        ),
      );
}
