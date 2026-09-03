import 'package:app/domain/rules/rally_analyzer.dart';
import 'package:app/domain/rules/team_side.dart';

/// Who won a rally and who is charged with the fault, if any.
class RallyOutcome {
  const RallyOutcome({
    required this.winner,
    required this.faulterId,
    required this.isServiceFault,
  });

  /// Team awarded the point.
  final TeamSide winner;

  /// Player charged with the fault, or null when nobody had touched the ball
  /// and no server is known.
  final String? faulterId;

  /// True when the rally ended before any player touched the ball after the
  /// serve — the server is at fault.
  final bool isServiceFault;
}

/// Pure rules deciding the outcome of a rally from where the ball ended up.
///
/// Attribution always follows the **last real contact**, never the side the
/// ball happened to land on: a ball sent out by e1 that lands beyond e2's
/// court is still e1's fault.
class PointResolution {
  const PointResolution._();

  /// The ball landed out of bounds.
  ///
  /// [impacts] are the rally's contacts recorded *before* the out-of-bounds
  /// impact is appended. Server-position markers are ignored.
  ///
  /// With no prior contact this is a service fault and the serving team loses,
  /// whichever side of the net the ball came down on.
  static RallyOutcome outOfBounds({
    required List<ImpactLike> impacts,
    required TeamSide servingTeam,
    required String servingPlayerId,
  }) {
    final lastContact = _lastRealContact(impacts);
    if (lastContact == null) {
      return RallyOutcome(
        winner: servingTeam.other,
        faulterId: servingPlayerId,
        isServiceFault: true,
      );
    }
    return RallyOutcome(
      winner: lastContact.teamSide.other,
      faulterId: lastContact.playerId,
      isServiceFault: false,
    );
  }

  /// The ball landed in bounds on [landingSide] — that team failed to dig it,
  /// so the point goes to their opponent.
  static RallyOutcome landedIn({required TeamSide landingSide}) => RallyOutcome(
        winner: landingSide.other,
        faulterId: null,
        isServiceFault: false,
      );

  static ImpactLike? _lastRealContact(List<ImpactLike> impacts) {
    for (var i = impacts.length - 1; i >= 0; i--) {
      if (!impacts[i].isServerPosition) return impacts[i];
    }
    return null;
  }
}
