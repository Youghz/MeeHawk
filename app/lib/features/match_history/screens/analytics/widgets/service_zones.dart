import 'package:app/domain/match_state.dart';
import 'package:app/domain/rules/analytics_rules.dart';
import 'package:app/features/match_history/screens/analytics/analytics_input.dart';
import 'package:app/features/match_history/screens/analytics/widgets/analytics_court.dart';
import 'package:flutter/material.dart';

class ServiceZonesSection extends StatelessWidget {
  const ServiceZonesSection(this.input, {super.key});
  final AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final dots = <AnalyticsDot>[];

    for (final (:pt, :server, :serverId) in input.ptsWithServer) {
      if (server != input.selectedTeam) continue;
      if (input.filterPlayerId != null && serverId != input.filterPlayerId) {
        continue;
      }

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

      final crossings = pt.netCrossings;
      final AnalyticsDotKind kind;
      if (crossings == 0) {
        kind = AnalyticsDotKind.fault;
      } else if (crossings == 1) {
        kind = AnalyticsDotKind.ace;
      } else {
        kind = pt.winner == input.selectedTeam
            ? AnalyticsDotKind.won
            : AnalyticsDotKind.lost;
      }
      final dotX = crossings == 0 ? 0.0 : AnalyticsRules.halfX(landing.x);
      dots.add(AnalyticsDot(x: dotX, y: landing.y, kind: kind));
    }

    if (dots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ServiceDotLegend(),
        const SizedBox(height: 12),
        AnalyticsCourt(dots: dots, halfCourt: true),
      ],
    );
  }
}
