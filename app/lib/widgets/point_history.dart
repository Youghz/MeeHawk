import 'package:flutter/material.dart';
import '../models/match_data.dart';
import '../theme.dart';

class PointHistory extends StatelessWidget {
  final List<PointRecord> points;
  final String playerA;
  final String playerB;

  const PointHistory({
    super.key,
    required this.points,
    required this.playerA,
    required this.playerB,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text('No points recorded yet.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }

    return ListView.builder(
      reverse: true,
      itemCount: points.length,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemBuilder: (context, index) {
        final p = points[points.length - 1 - index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.result == 'us'
                      ? AppColors.green.withValues(alpha: 0.15)
                      : AppColors.red.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Text(
                    '${p.pointNumber}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: p.result == 'us' ? AppColors.green : AppColors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.summary(playerA, playerB),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Text(
                '${p.scoreUs}-${p.scoreThem}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
