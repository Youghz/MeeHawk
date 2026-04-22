import 'package:app/core/rules/team_side.dart';

/// Pure service-rotation rules. Nothing here touches Flutter or providers.
class ServiceRotation {
  const ServiceRotation._();

  /// Seed for `nextServerIndex` given the initial serving-player index.
  /// For the starting team: the OTHER player will serve next (on first
  /// side-out back). For the opposing team: 0 as a placeholder until they
  /// pick their first server.
  static Map<TeamSide, int> initialNextServerIndex({
    required TeamSide startingTeam,
    required int startingPlayerIndex,
    int startingTeamSize = 2,
  }) =>
      {
        startingTeam: (startingPlayerIndex + 1) % startingTeamSize,
        startingTeam.other: 0,
      };

  /// Seed for `firstServerIndex`. Only the starting team is known upfront;
  /// the opposing team's first server is picked via popup when they
  /// side-out for the first time.
  static Map<TeamSide, int?> initialFirstServerIndex({
    required TeamSide startingTeam,
    required int startingPlayerIndex,
  }) =>
      {
        startingTeam: startingPlayerIndex,
        startingTeam.other: null,
      };

  /// Given a point outcome, return the playerId who serves next and the
  /// updated `nextServerIndex`. Does not handle the "first side-out of a
  /// team" case — that must be intercepted upstream (popup).
  static ({String serverId, Map<TeamSide, int> nextIndex}) next({
    required String currentServerId,
    required TeamSide servingTeam,
    required TeamSide winner,
    required Map<TeamSide, List<String>> playersByTeam,
    required Map<TeamSide, int> nextServerIndex,
  }) {
    if (winner == servingTeam) {
      return (serverId: currentServerId, nextIndex: nextServerIndex);
    }
    final players = playersByTeam[winner]!;
    final idx = nextServerIndex[winner]!;
    final next = {
      ...nextServerIndex,
      winner: (idx + 1) % players.length,
    };
    return (serverId: players[idx % players.length], nextIndex: next);
  }
}
