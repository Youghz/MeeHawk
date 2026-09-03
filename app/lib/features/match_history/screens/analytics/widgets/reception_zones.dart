import 'package:app/domain/match_state.dart';
import 'package:app/domain/rules/analytics_rules.dart';
import 'package:app/features/match_history/screens/analytics/analytics_input.dart';
import 'package:app/features/match_history/screens/analytics/widgets/analytics_court.dart';
import 'package:flutter/material.dart';

class ReceptionZonesSection extends StatelessWidget {
  const ReceptionZonesSection(this.input, {super.key});
  final AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final dots = <AnalyticsDot>[];

    for (final (:pt, :server, serverId: _) in input.ptsWithServer) {
      if (server == input.selectedTeam) continue;

      BallImpact? landing;
      var seenServer = false;
      for (final imp in pt.impacts) {
        if (imp.isServerPosition) {
          seenServer = true;
          continue;
        }
        if (seenServer) {
          landing = imp;
          break;
        }
      }
      if (landing == null) continue;

      if (input.filterPlayerId != null &&
          landing.playerId != input.filterPlayerId) {
        continue;
      }

      final crossings = pt.netCrossings;
      if (crossings == 0) continue;

      final AnalyticsDotKind kind;
      if (crossings == 1) {
        kind = AnalyticsDotKind.fault;
      } else {
        kind = pt.winner == input.selectedTeam
            ? AnalyticsDotKind.won
            : AnalyticsDotKind.lost;
      }

      dots.add(AnalyticsDot(
          x: AnalyticsRules.halfX(landing.x), y: landing.y, kind: kind));
    }

    if (dots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReceptionDotLegend(),
        const SizedBox(height: 12),
        AnalyticsCourt(dots: dots, halfCourt: true),
      ],
    );
  }
}
