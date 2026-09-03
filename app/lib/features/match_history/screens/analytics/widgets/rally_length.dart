import 'package:app/core/theme.dart';
import 'package:app/domain/rules/analytics_rules.dart';
import 'package:app/features/match_history/screens/analytics/analytics_input.dart';
import 'package:app/features/match_history/screens/analytics/widgets/analytics_primitives.dart';
import 'package:flutter/material.dart';

class RallyLengthSection extends StatelessWidget {
  const RallyLengthSection(this.input, {super.key});
  final AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    if (input.pts.isEmpty) return const SizedBox.shrink();

    const labels = {
      0: 'Direct',
      1: '1 éch.',
      2: '2 éch.',
      3: '3 éch.',
      4: '4+ éch.',
    };

    final myServe = <int, ({int wins, int total})>{};
    final oppServe = <int, ({int wins, int total})>{};

    for (final (:pt, :server, serverId: _) in input.ptsWithServer) {
      final ex = AnalyticsRules.exchanges(pt);
      final won = pt.winner == input.selectedTeam;
      final bucket = server == input.selectedTeam ? myServe : oppServe;
      final prev = bucket[ex] ?? (wins: 0, total: 0);
      bucket[ex] = (wins: prev.wins + (won ? 1 : 0), total: prev.total + 1);
    }

    final allKeys = {...myServe.keys, ...oppServe.keys}.toList()..sort();
    if (allKeys.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ServeColumn(
                  title: 'AU SERVICE',
                  data: myServe,
                  allKeys: allKeys,
                  labels: labels,
                  color: input.color,
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: MH.rule,
              ),
              Expanded(
                child: _ServeColumn(
                  title: 'EN RÉCEPTION',
                  data: oppServe,
                  allKeys: allKeys,
                  labels: labels,
                  color: input.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: MH.rule),
        const SizedBox(height: 12),
        Text('CONTRÔLE DU JEU',
            style: MH.mono(size: 9, weight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        AnalyticsKeyRow(
            label: 'Touches moy. (nous)',
            value: input.avgTouchesUs.toStringAsFixed(1)),
        const SizedBox(height: 8),
        AnalyticsKeyRow(
            label: 'Touches moy. (eux)',
            value: input.avgTouchesThem.toStringAsFixed(1)),
      ],
    );
  }
}

class _ServeColumn extends StatelessWidget {
  const _ServeColumn({
    required this.title,
    required this.data,
    required this.allKeys,
    required this.labels,
    required this.color,
  });

  final String title;
  final Map<int, ({int wins, int total})> data;
  final List<int> allKeys;
  final Map<int, String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: MH.mono(
                  size: 9, weight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          for (final key in allKeys) ...[
            AnalyticsCompactBar(
              label: labels[key] ?? '$key+ éch.',
              wins: data[key]?.wins ?? 0,
              total: data[key]?.total ?? 0,
              color: color,
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
}
