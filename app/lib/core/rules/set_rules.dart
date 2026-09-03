import 'package:app/core/rules/match_format.dart';

/// Set/match completion logic. Pure functions; no state.
class SetRules {
  const SetRules._();

  /// Maximum touches a team may use per possession (§9.1 FIVB Rules 2021-2024).
  static const int maxTeamTouches = 3;

  /// True when the current set is won by one team (target reached with
  /// required lead).
  static bool isSetWon(
    int pointsA,
    int pointsB,
    int setNumber,
    MatchFormat format,
  ) {
    final target = format.targetFor(setNumber);
    final leader = pointsA >= pointsB ? pointsA : pointsB;
    final gap = (pointsA - pointsB).abs();
    return leader >= target && gap >= format.winBy;
  }

  /// True when a team has won enough sets to take the match.
  static bool isMatchWon(int setsWonA, int setsWonB, MatchFormat format) =>
      setsWonA >= format.setsToWin || setsWonB >= format.setsToWin;

  /// True when, after a point, sides should be swapped according to the
  /// change-side cadence for this set. `totalPointsAfter` is the sum of
  /// both teams' current-set points AFTER the point was awarded.
  static bool shouldPromptSideChange({
    required int totalPointsAfter,
    required int setNumber,
    required MatchFormat format,
  }) {
    if (totalPointsAfter <= 0) return false;
    final every = format.changeSideEveryFor(setNumber);
    return totalPointsAfter % every == 0;
  }
}
