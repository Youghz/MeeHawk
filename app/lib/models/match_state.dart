import 'dart:ui';

class Player {
  final String id;
  final String name;
  const Player({required this.id, required this.name});

  Player copyWith({String? name}) => Player(id: id, name: name ?? this.name);
}

class Team {
  final String name;
  final List<Player> players;
  const Team({required this.name, required this.players});

  Team copyWith({String? name, List<Player>? players}) =>
      Team(name: name ?? this.name, players: players ?? this.players);
}

class CourtPos {
  final double x;
  final double y;
  const CourtPos(this.x, this.y);
}

/// One ball touch during a rally.
///
/// - `x`, `y` are normalized in the outer court frame (terrain + margin),
///   in the range 0..1. Independent of screen size.
/// - `isOutside` is true when the impact fell in the out-of-bounds margin.
/// - `teamSide` is the team key (`e1`/`e2`) whose half of the court the ball
///   was in AT THE TIME the impact was recorded. Captured at recording time
///   so later side swaps don't mis-attribute.
/// - `playerId` is the nearest player on that side at the time of the tap
///   (auto-attributed). Null only if no players existed.
class BallImpact {
  final double x;
  final double y;
  final bool isOutside;
  final String teamSide;
  final String? playerId;

  const BallImpact({
    required this.x,
    required this.y,
    required this.isOutside,
    required this.teamSide,
    this.playerId,
  });
}

class Annotation {
  final String type;
  final String text;
  final String? team;
  const Annotation({required this.type, required this.text, this.team});
}

class PointRecord {
  final String winner;
  final List<Annotation> annotations;
  final int scoreE1;
  final int scoreE2;
  final String serverId;
  final List<BallImpact> impacts;

  const PointRecord({
    required this.winner,
    required this.annotations,
    required this.scoreE1,
    required this.scoreE2,
    required this.serverId,
    this.impacts = const [],
  });

  int scoreOf(String team) => team == 'e1' ? scoreE1 : scoreE2;

  /// Net crossings count: starts at 0, +1 each time two consecutive impacts
  /// are on opposite sides.
  int get rallyLength {
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

  /// For each team, the average number of consecutive touches per visit
  /// in that team's half of the court. A "visit" is a maximal run of
  /// consecutive impacts with the same `teamSide`.
  Map<String, double> averageTouchesPerVisit() {
    final visits = <String, List<int>>{'e1': [], 'e2': []};
    String? current;
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
    return {'e1': avg(visits['e1']!), 'e2': avg(visits['e2']!)};
  }
}

enum PopupKind { fault, pickServer, outsideFault, block }

class MatchPopup {
  final PopupKind kind;
  final String winner;
  final String? playerId;
  final Offset? tapPos;
  final List<Annotation> pendingAnnotations;
  const MatchPopup({
    required this.kind,
    required this.winner,
    this.playerId,
    this.tapPos,
    this.pendingAnnotations = const [],
  });
}

class MatchState {
  final Map<String, Team> teams;
  final Map<String, CourtPos> positions;
  final String servingPlayerId;
  final String initialServerId;
  final Map<String, int> nextServerIndex;
  final Map<String, int?> firstServerIndex;
  final List<Annotation> rallyAnnotations;
  final List<BallImpact> rallyImpacts;
  final List<PointRecord> history;
  final bool sidesSwapped;
  final String notes;
  final int? selectedPointIndex;
  final bool changeSidePromptDismissed;
  final bool changeSidePromptOpen;
  final MatchPopup? popup;

  const MatchState({
    required this.teams,
    required this.positions,
    required this.servingPlayerId,
    required this.initialServerId,
    required this.nextServerIndex,
    required this.firstServerIndex,
    required this.rallyAnnotations,
    required this.rallyImpacts,
    required this.history,
    required this.sidesSwapped,
    required this.notes,
    required this.selectedPointIndex,
    required this.changeSidePromptDismissed,
    required this.changeSidePromptOpen,
    required this.popup,
  });

  MatchState copyWith({
    Map<String, Team>? teams,
    Map<String, CourtPos>? positions,
    String? servingPlayerId,
    String? initialServerId,
    Map<String, int>? nextServerIndex,
    Map<String, int?>? firstServerIndex,
    List<Annotation>? rallyAnnotations,
    List<BallImpact>? rallyImpacts,
    List<PointRecord>? history,
    bool? sidesSwapped,
    String? notes,
    Object? selectedPointIndex = _sentinel,
    bool? changeSidePromptDismissed,
    bool? changeSidePromptOpen,
    Object? popup = _sentinel,
  }) =>
      MatchState(
        teams: teams ?? this.teams,
        positions: positions ?? this.positions,
        servingPlayerId: servingPlayerId ?? this.servingPlayerId,
        initialServerId: initialServerId ?? this.initialServerId,
        nextServerIndex: nextServerIndex ?? this.nextServerIndex,
        firstServerIndex: firstServerIndex ?? this.firstServerIndex,
        rallyAnnotations: rallyAnnotations ?? this.rallyAnnotations,
        rallyImpacts: rallyImpacts ?? this.rallyImpacts,
        history: history ?? this.history,
        sidesSwapped: sidesSwapped ?? this.sidesSwapped,
        notes: notes ?? this.notes,
        selectedPointIndex: identical(selectedPointIndex, _sentinel)
            ? this.selectedPointIndex
            : selectedPointIndex as int?,
        changeSidePromptDismissed:
            changeSidePromptDismissed ?? this.changeSidePromptDismissed,
        changeSidePromptOpen:
            changeSidePromptOpen ?? this.changeSidePromptOpen,
        popup: identical(popup, _sentinel) ? this.popup : popup as MatchPopup?,
      );

  int get scoreE1 => history.where((p) => p.winner == 'e1').length;
  int get scoreE2 => history.where((p) => p.winner == 'e2').length;
  int scoreOf(String team) => team == 'e1' ? scoreE1 : scoreE2;

  String? teamOfPlayer(String playerId) {
    if (teams['e1']!.players.any((p) => p.id == playerId)) return 'e1';
    if (teams['e2']!.players.any((p) => p.id == playerId)) return 'e2';
    return null;
  }

  Player? playerById(String playerId) {
    for (final tk in ['e1', 'e2']) {
      final found = teams[tk]!.players.where((p) => p.id == playerId);
      if (found.isNotEmpty) return found.first;
    }
    return null;
  }
}

const _sentinel = Object();

MatchState initialMatchState({
  String teamE1Name = 'Équipe 1',
  String teamE2Name = 'Équipe 2',
  String p1 = 'Ana',
  String p2 = 'Sara',
  String p3 = 'Léa',
  String p4 = 'Marie',
  String initialServerId = 'p3',
}) =>
    MatchState(
      teams: {
        'e1': Team(
          name: teamE1Name,
          players: [Player(id: 'p1', name: p1), Player(id: 'p2', name: p2)],
        ),
        'e2': Team(
          name: teamE2Name,
          players: [Player(id: 'p3', name: p3), Player(id: 'p4', name: p4)],
        ),
      },
      positions: const {
        'p1': CourtPos(0.25, 0.35),
        'p2': CourtPos(0.25, 0.70),
        'p3': CourtPos(0.75, 0.35),
        'p4': CourtPos(0.75, 0.70),
      },
      servingPlayerId: initialServerId,
      initialServerId: initialServerId,
      nextServerIndex: _initialNextServerIndex(initialServerId),
      firstServerIndex: _initialFirstServerIndex(initialServerId),
      rallyAnnotations: const [],
      rallyImpacts: const [],
      history: const [],
      sidesSwapped: false,
      notes: '',
      selectedPointIndex: null,
      changeSidePromptDismissed: false,
      changeSidePromptOpen: false,
      popup: null,
    );

Map<String, int> _initialNextServerIndex(String serverId) {
  final servingE1 = serverId == 'p1' || serverId == 'p2';
  return {
    'e1': servingE1 ? (serverId == 'p1' ? 1 : 0) : 0,
    'e2': servingE1 ? 0 : (serverId == 'p3' ? 1 : 0),
  };
}

Map<String, int?> _initialFirstServerIndex(String serverId) {
  final servingE1 = serverId == 'p1' || serverId == 'p2';
  return {
    'e1': servingE1 ? (serverId == 'p1' ? 0 : 1) : null,
    'e2': servingE1 ? null : (serverId == 'p3' ? 0 : 1),
  };
}
