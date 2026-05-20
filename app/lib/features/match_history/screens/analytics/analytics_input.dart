import 'package:app/features/match/domain/match_state.dart';
import 'package:flutter/material.dart';

/// Pre-computed analytics data built once per render pass.
class AnalyticsInput {
  const AnalyticsInput({
    required this.pts,
    required this.ptsWithServer,
    required this.ptsForPlayer,
    required this.selectedTeam,
    required this.otherTeamName,
    required this.team,
    required this.color,
    required this.filterPlayerId,
    required this.filterSetNumber,
    required this.avgTouchesUs,
    required this.avgTouchesThem,
  });

  final List<PointRecord> pts;
  final List<({PointRecord pt, TeamSide server, String serverId})> ptsWithServer;
  final List<PointRecord> ptsForPlayer;
  final TeamSide selectedTeam;
  final String otherTeamName;
  final Team team;
  final Color color;
  final String? filterPlayerId;
  final int? filterSetNumber;
  final double avgTouchesUs;
  final double avgTouchesThem;

}
