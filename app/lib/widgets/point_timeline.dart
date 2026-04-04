import 'package:flutter/material.dart';
import '../models/match_data.dart';
import '../theme.dart';

class PointTimeline extends StatelessWidget {
  final List<PointRecord> points;
  final int maxPoints;
  final String teamUsName;
  final String teamThemName;

  const PointTimeline({
    super.key,
    required this.points,
    this.maxPoints = 25,
    this.teamUsName = 'NOUS',
    this.teamThemName = 'EUX',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const SizedBox(width: 22),
              Expanded(
                child: Text(teamUsName, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: AppColors.green, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Text(teamThemName, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: AppColors.red, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Divider(height: 1, color: AppColors.border),
          // Rows
          Expanded(
            child: ListView.builder(
              itemCount: maxPoints,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final record = index < points.length ? points[index] : null;
                return _PointRow(pointNumber: index + 1, record: record);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final int pointNumber;
  final PointRecord? record;

  const _PointRow({required this.pointNumber, this.record});

  @override
  Widget build(BuildContext context) {
    final isPlayed = record != null;
    final wonByUs = record?.result == 'us';

    return Container(
      height: 22,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$pointNumber', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10,
                    color: isPlayed ? AppColors.textSecondary : AppColors.textMuted.withValues(alpha: 0.3))),
          ),
          Expanded(
            child: isPlayed && wonByUs
                ? _marker(AppColors.green, '${record!.scoreUs}')
                : const SizedBox(),
          ),
          Container(width: 1, color: AppColors.border.withValues(alpha: 0.3)),
          Expanded(
            child: isPlayed && !wonByUs
                ? _marker(AppColors.red, '${record!.scoreThem}')
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _marker(Color color, String score) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(score,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
