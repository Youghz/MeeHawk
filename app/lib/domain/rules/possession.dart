import 'package:app/domain/rules/rally_analyzer.dart';
import 'package:app/domain/rules/team_side.dart';

/// Pure rules describing how a rally is divided into "visits" — the runs of
/// consecutive touches a team gets between two net crossings.
///
/// Server-position markers are not ball contacts and are skipped throughout.
class Possession {
  const Possession._();

  /// True when the next touch on [side] starts a fresh visit, i.e. the ball
  /// just crossed from the other side or nothing has been touched yet.
  ///
  /// The UI uses this to decide whether to ask which player is touching:
  /// mid-visit the player can be inferred by alternation, but the first
  /// contact of a visit is genuinely ambiguous.
  ///
  /// Exception: after a block, the blocker may legally play the ball again,
  /// so the next touch is ambiguous too and starts a new picker prompt.
  static bool startsNewVisit(List<ImpactLike> impacts, TeamSide side) {
    for (var i = impacts.length - 1; i >= 0; i--) {
      final impact = impacts[i];
      if (impact.isServerPosition) continue;
      if (impact.teamSide != side) return true;
      return impact.isBlock;
    }
    return true;
  }

  /// How many net crossings happened up to and including impact [index].
  ///
  /// Used to colour impact markers so each visit is visually distinct.
  /// Throws [RangeError] when [index] is out of bounds.
  static int visitIndexAt(List<ImpactLike> impacts, int index) {
    RangeError.checkValidIndex(index, impacts, 'index');
    var visits = 0;
    TeamSide? lastSide;
    for (var i = 0; i <= index; i++) {
      final impact = impacts[i];
      if (impact.isServerPosition) continue;
      if (lastSide != null && impact.teamSide != lastSide) visits++;
      lastSide = impact.teamSide;
    }
    return visits;
  }

  /// The number shown on the marker for impact [index].
  ///
  /// Real contacts are numbered from 1. A leading server-position marker is
  /// numbered 0, so the serve itself still reads as contact 1.
  /// Throws [RangeError] when [index] is out of bounds.
  static int displayIndexAt(List<ImpactLike> impacts, int index) {
    RangeError.checkValidIndex(index, impacts, 'index');
    final hasServerMarker = impacts.first.isServerPosition;
    if (hasServerMarker) return index;
    return index + 1;
  }
}
