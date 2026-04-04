import 'package:flutter/material.dart';
import '../theme.dart';

class AnalysisProgressBar extends StatelessWidget {
  final Map<String, dynamic>? progress;

  const AnalysisProgressBar({super.key, this.progress});

  String _formatTime(double? seconds) {
    if (seconds == null || seconds < 0) return '--:--';
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (progress == null) {
      return const Center(
          child: Text('Starting analysis...',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    final percent = (progress!['percent'] as num?)?.toDouble() ?? 0;
    final remaining = (progress!['estimated_remaining_seconds'] as num?)?.toDouble();
    final elapsed = (progress!['elapsed_seconds'] as num?)?.toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ESTIMATED TIME REMAINING',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.5,
                color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(_formatTime(remaining),
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 10,
            backgroundColor: AppColors.surfaceLight,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${percent.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, color: AppColors.accent)),
            Text('Elapsed ${_formatTime(elapsed)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}
