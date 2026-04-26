import 'package:app/core/rules/rally_analyzer.dart';
import 'package:app/core/rules/team_side.dart';

/// Pure rule: which player should be attributed the next touch on a given
/// side, given the impacts already recorded in the rally.
///
/// Beach volleyball alternation rule:
///   - Touch 1 of a visit: determined by the caller (player picker or server).
///   - Touch 2: teammate of touch 1 player.
///   - Touch 3: back to touch 1 player.
///   - Exception: if the previous same-side touch was a block, the blocker
///     may touch the ball again (block doesn't count as a team contact, so
///     the same player can legally be next).
class TouchAttribution {
  const TouchAttribution._();

  /// Returns the player ID to attribute the next touch on [side] to, or null
  /// if this is the first touch of the current visit (caller decides).
  ///
  /// [impacts] is the full list of impacts recorded so far in this rally.
  /// [playerIds] must contain exactly the two player IDs of the team on [side].
  static String? inferNextPlayer({
    required List<ImpactLike> impacts,
    required TeamSide side,
    required List<String> playerIds,
  }) {
    // Walk backwards to find the last real touch on [side]. Stop as soon as
    // we hit a touch on the opposite side (ball crossed = new visit).
    ImpactLike? lastOnSide;
    for (var i = impacts.length - 1; i >= 0; i--) {
      final imp = impacts[i];
      if (imp.isServerPosition) continue;
      if (imp.teamSide != side) break;
      lastOnSide = imp;
      break;
    }
    if (lastOnSide == null) return null;

    // Block exception: same player may touch immediately after their block.
    if (lastOnSide.isBlock) return lastOnSide.playerId;

    final lastId = lastOnSide.playerId;
    if (lastId == null) return null;

    // Alternate to the teammate.
    return playerIds.firstWhere(
      (id) => id != lastId,
      orElse: () => lastId,
    );
  }
}
