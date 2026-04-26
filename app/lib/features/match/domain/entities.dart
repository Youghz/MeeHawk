import 'package:app/core/rules/rally_analyzer.dart';
import 'package:app/core/rules/team_side.dart';

/// A single player (pure value object).
class Player {
  const Player({required this.id, required this.name});

  final String id;
  final String name;

  Player copyWith({String? name}) => Player(id: id, name: name ?? this.name);
}

/// A team, made of players, with a display name.
class Team {
  const Team({required this.name, required this.players});

  final String name;
  final List<Player> players;

  Team copyWith({String? name, List<Player>? players}) =>
      Team(name: name ?? this.name, players: players ?? this.players);
}

/// A normalized position on the inner court (0..1 in both axes).
class CourtPos {
  const CourtPos(this.x, this.y);

  final double x;
  final double y;
}

/// One ball touch during a rally.
///
/// - `x`, `y` are normalized in the outer court frame (terrain + margin),
///   in the range 0..1. Independent of screen size.
/// - `isOutside` is true when the impact fell in the out-of-bounds margin.
/// - `teamSide` is the half of the court the ball was in AT THE TIME the
///   impact was recorded. Captured at recording time so later side swaps
///   don't mis-attribute.
/// - `playerId` is the nearest player on that side at the time of the tap
///   (auto-attributed). Null only if no players existed.
/// - `isServerPosition` marks action 0: the server's standing position
///   behind the end line at the start of the rally.
/// - `isBlock` marks this impact as a block action (double-tap).
class BallImpact implements ImpactLike {
  const BallImpact({
    required this.x,
    required this.y,
    required this.isOutside,
    required this.teamSide,
    this.playerId,
    this.isServerPosition = false,
    this.isBlock = false,
  });

  final double x;
  final double y;
  final bool isOutside;
  @override
  final TeamSide teamSide;
  @override
  final String? playerId;
  @override
  final bool isServerPosition;
  @override
  final bool isBlock;
}

/// A labelled action attached to a rally or a point (service, attaque,
/// bloc, faute…). Produced by auto-inference or by popup picks.
class Annotation {
  const Annotation({required this.type, required this.text, this.team});

  final String type;
  final String text;
  final TeamSide? team;
}

/// A single completed point in match history.
class PointRecord {
  const PointRecord({
    required this.winner,
    required this.annotations,
    required this.scoreE1,
    required this.scoreE2,
    required this.setNumber,
    required this.serverId,
    this.impacts = const [],
  });

  final TeamSide winner;
  final List<Annotation> annotations;
  final int scoreE1;
  final int scoreE2;
  final int setNumber;
  final String serverId;
  final List<BallImpact> impacts;

  int scoreOf(TeamSide team) => team == TeamSide.e1 ? scoreE1 : scoreE2;

  /// Number of times the ball crossed the net during this rally.
  int get netCrossings => RallyAnalyzer.netCrossings(impacts);
}

/// A completed set (summary). Used for set-by-set display and match
/// completion detection.
class SetRecord {
  const SetRecord({
    required this.setNumber,
    required this.scoreE1,
    required this.scoreE2,
    required this.winner,
  });

  final int setNumber;
  final int scoreE1;
  final int scoreE2;
  final TeamSide winner;
}
