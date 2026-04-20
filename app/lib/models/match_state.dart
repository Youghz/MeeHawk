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

  const PointRecord({
    required this.winner,
    required this.annotations,
    required this.scoreE1,
    required this.scoreE2,
    required this.serverId,
  });

  int scoreOf(String team) => team == 'e1' ? scoreE1 : scoreE2;
}

enum PopupKind { attack, fault }

class MatchPopup {
  final PopupKind kind;
  final String winner;
  final String? playerId;
  const MatchPopup({required this.kind, required this.winner, this.playerId});
}

class MatchState {
  final Map<String, Team> teams;
  final Map<String, CourtPos> positions;
  final String servingPlayerId;
  final String initialServerId;
  final Map<String, int> nextServerIndex;
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
