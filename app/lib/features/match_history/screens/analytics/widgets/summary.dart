import 'dart:math';

import 'package:app/core/theme.dart';
import 'package:app/domain/rules/analytics_rules.dart';
import 'package:app/features/match_history/screens/analytics/analytics_input.dart';
import 'package:app/features/match_history/screens/analytics/widgets/analytics_primitives.dart';
import 'package:flutter/material.dart';

class AnalyticsSummary extends StatelessWidget {
  const AnalyticsSummary(this.input, {super.key});
  final AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final pts = input.pts;
    if (pts.isEmpty) return const SizedBox.shrink();

    final pairs = input.ptsWithServer;
    final myWins = pts.where((p) => p.winner == input.selectedTeam).length;

    final myServes =
        pairs.where((p) => p.server == input.selectedTeam).toList();
    final myRecv =
        pairs.where((p) => p.server != input.selectedTeam).toList();
    final myServeWins =
        myServes.where((p) => p.pt.winner == input.selectedTeam).length;
    final myRecvWins =
        myRecv.where((p) => p.pt.winner == input.selectedTeam).length;

    final streak = AnalyticsRules.maxStreak(pts, input.selectedTeam);
    var maxLead = 0;
    for (final p in pts) {
      final lead =
          p.scoreOf(input.selectedTeam) - p.scoreOf(input.selectedTeam.other);
      if (lead > maxLead) maxLead = lead;
    }

    final first5 = pts.take(min(5, pts.length)).toList();
    final f5Wins =
        first5.where((p) => p.winner == input.selectedTeam).length;

    final pressurePts = pts
        .where((p) =>
            p.scoreOf(input.selectedTeam) >= 15 ||
            p.scoreOf(input.selectedTeam.other) >= 15)
        .toList();
    final pressWins =
        pressurePts.where((p) => p.winner == input.selectedTeam).length;

    final decPts = pts
        .where((p) =>
            p.scoreOf(input.selectedTeam) >= 18 ||
            p.scoreOf(input.selectedTeam.other) >= 18)
        .toList();
    final decWins =
        decPts.where((p) => p.winner == input.selectedTeam).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 14, color: input.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              input.team.name,
              style: MH.sans(weight: FontWeight.w700, color: input.color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'vs ${input.otherTeamName}',
            style: MH.sans(size: 11, color: MH.pencil),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnalyticsRingStat(
                label: 'Points',
                count: '$myWins/${pts.length}',
                rate: pts.isNotEmpty ? myWins / pts.length : 0,
                color: input.color,
              ),
            ),
            Expanded(
              child: AnalyticsRingStat(
                label: 'Service',
                count: '$myServeWins/${myServes.length}',
                rate: myServes.isNotEmpty ? myServeWins / myServes.length : 0,
                color: input.color,
              ),
            ),
            Expanded(
              child: AnalyticsRingStat(
                label: 'Réception',
                count: '$myRecvWins/${myRecv.length}',
                rate: myRecv.isNotEmpty ? myRecvWins / myRecv.length : 0,
                color: input.color.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: MH.rule),
        const SizedBox(height: 12),
        AnalyticsKeyRow(label: 'Série max consécutive', value: '$streak pts'),
        const SizedBox(height: 8),
        AnalyticsKeyRow(label: 'Avance maximale', value: '+$maxLead pts'),
        if (first5.isNotEmpty || pressurePts.isNotEmpty || decPts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1, color: MH.rule),
          const SizedBox(height: 12),
          if (first5.isNotEmpty)
            AnalyticsStatLine(
                label: '5 premiers points',
                wins: f5Wins,
                total: first5.length),
          if (pressurePts.isNotEmpty)
            AnalyticsStatLine(
                label: 'Points ≥ 15',
                wins: pressWins,
                total: pressurePts.length),
          if (decPts.isNotEmpty)
            AnalyticsStatLine(
                label: 'Points ≥ 18',
                wins: decWins,
                total: decPts.length),
        ],
      ],
    );
  }
}
