import 'package:app/domain/rules/team_side.dart';

/// Minimal contract an impact object must satisfy for the analyzer and
/// touch-attribution rules.
abstract class ImpactLike {
  TeamSide get teamSide;
  bool get isServerPosition;
  bool get isBlock;
  String? get playerId;
}

/// Pure analysis of a sequence of ball impacts within a rally.
class RallyAnalyzer {
  const RallyAnalyzer._();

  /// Number of times the ball crossed the net during the rally.
  static int netCrossings(List<ImpactLike> impacts) {
    if (impacts.length < 2) return 0;
    var crossings = 0;
    var prev = impacts.first.teamSide;
    for (var i = 1; i < impacts.length; i++) {
      final side = impacts[i].teamSide;
      if (side != prev) crossings++;
      prev = side;
    }
    return crossings;
  }

  /// Average touches per "visit" of the ball on each team's half.
  /// A visit is a maximal run of consecutive impacts with the same teamSide.
  static Map<TeamSide, double> averageTouchesPerVisit(
    List<ImpactLike> impacts,
  ) {
    final visits = <TeamSide, List<int>>{
      TeamSide.e1: <int>[],
      TeamSide.e2: <int>[],
    };
    TeamSide? current;
    var count = 0;
    for (final i in impacts) {
      if (i.teamSide == current) {
        count++;
      } else {
        if (current != null) visits[current]!.add(count);
        current = i.teamSide;
        count = 1;
      }
    }
    if (current != null) visits[current]!.add(count);
    double avg(List<int> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    return {
      TeamSide.e1: avg(visits[TeamSide.e1]!),
      TeamSide.e2: avg(visits[TeamSide.e2]!),
    };
  }
}
