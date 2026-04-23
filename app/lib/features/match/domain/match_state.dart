import 'package:app/core/rules/match_format.dart';
import 'package:app/core/rules/team_side.dart';
import 'package:app/features/match/domain/entities.dart';
import 'package:app/features/match/domain/match_popup.dart';

export 'package:app/core/rules/match_format.dart';
export 'package:app/core/rules/team_side.dart';
export 'package:app/features/match/domain/entities.dart';
export 'package:app/features/match/domain/match_popup.dart';

/// Immutable snapshot of everything we know about the current match.
/// Mutations go through `copyWith`; use [initialMatchState] for fresh
/// instances.
class MatchState {
  const MatchState({
    required this.format,
    required this.teams,
    required this.positions,
    required this.servingPlayerId,
    required this.initialServerId,
    required this.nextServerIndex,
    required this.firstServerIndex,
    required this.rallyAnnotations,
    required this.rallyImpacts,
    required this.history,
    required this.sets,
    required this.setNumber,
    required this.scoreE1,
    required this.scoreE2,
    required this.sidesSwapped,
    required this.notes,
    required this.selectedPointIndex,
    required this.changeSidePromptDismissed,
    required this.changeSidePromptOpen,
    required this.popup,
    required this.matchOver,
    required this.trackedTeams,
  });

  final MatchFormat format;
  final Map<TeamSide, Team> teams;
  final Map<String, CourtPos> positions;
  final String servingPlayerId;
  final String initialServerId;
  final Map<TeamSide, int> nextServerIndex;
  final Map<TeamSide, int?> firstServerIndex;
  final List<Annotation> rallyAnnotations;
  final List<BallImpact> rallyImpacts;
  final List<PointRecord> history;
  final List<SetRecord> sets;
  final int setNumber;
  final int scoreE1;
  final int scoreE2;
  final bool sidesSwapped;
  final String notes;
  final int? selectedPointIndex;
  final bool changeSidePromptDismissed;
  final bool changeSidePromptOpen;
  final MatchPopup? popup;
  final bool matchOver;

  /// Teams for which the full manual annotation flow (player picker) is active.
  /// Teams absent from this set use auto-attribution only.
  final Set<TeamSide> trackedTeams;

  MatchState copyWith({
    MatchFormat? format,
    Map<TeamSide, Team>? teams,
    Map<String, CourtPos>? positions,
    String? servingPlayerId,
    String? initialServerId,
    Map<TeamSide, int>? nextServerIndex,
    Map<TeamSide, int?>? firstServerIndex,
    List<Annotation>? rallyAnnotations,
    List<BallImpact>? rallyImpacts,
    List<PointRecord>? history,
    List<SetRecord>? sets,
    int? setNumber,
    int? scoreE1,
    int? scoreE2,
    bool? sidesSwapped,
    String? notes,
    Object? selectedPointIndex = _sentinel,
    bool? changeSidePromptDismissed,
    bool? changeSidePromptOpen,
    Object? popup = _sentinel,
    bool? matchOver,
    Set<TeamSide>? trackedTeams,
  }) =>
      MatchState(
        format: format ?? this.format,
        teams: teams ?? this.teams,
        positions: positions ?? this.positions,
        servingPlayerId: servingPlayerId ?? this.servingPlayerId,
        initialServerId: initialServerId ?? this.initialServerId,
        nextServerIndex: nextServerIndex ?? this.nextServerIndex,
        firstServerIndex: firstServerIndex ?? this.firstServerIndex,
        rallyAnnotations: rallyAnnotations ?? this.rallyAnnotations,
        rallyImpacts: rallyImpacts ?? this.rallyImpacts,
        history: history ?? this.history,
        sets: sets ?? this.sets,
        setNumber: setNumber ?? this.setNumber,
        scoreE1: scoreE1 ?? this.scoreE1,
        scoreE2: scoreE2 ?? this.scoreE2,
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
        matchOver: matchOver ?? this.matchOver,
        trackedTeams: trackedTeams ?? this.trackedTeams,
      );

  // ---- Convenience accessors ----

  int scoreOf(TeamSide team) => team == TeamSide.e1 ? scoreE1 : scoreE2;

  int setsWonOf(TeamSide team) =>
      sets.where((s) => s.winner == team).length;

  TeamSide get leftTeam => sidesSwapped ? TeamSide.e2 : TeamSide.e1;
  TeamSide get rightTeam => sidesSwapped ? TeamSide.e1 : TeamSide.e2;

  TeamSide? teamOfPlayer(String playerId) {
    if (teams[TeamSide.e1]!.players.any((p) => p.id == playerId)) {
      return TeamSide.e1;
    }
    if (teams[TeamSide.e2]!.players.any((p) => p.id == playerId)) {
      return TeamSide.e2;
    }
    return null;
  }

  Player? playerById(String playerId) {
    for (final ts in TeamSide.values) {
      final found = teams[ts]!.players.where((p) => p.id == playerId);
      if (found.isNotEmpty) return found.first;
    }
    return null;
  }
}

const _sentinel = Object();

/// Build a fresh match state with default players/positions. The
/// [initialServerId] determines which team receives and which one serves
/// first; [MatchFormat] controls set targets and change-side cadence.
MatchState initialMatchState({
  String teamE1Name = 'Équipe 1',
  String teamE2Name = 'Équipe 2',
  String p1 = 'Ana',
  String p2 = 'Sara',
  String p3 = 'Léa',
  String p4 = 'Marie',
  String initialServerId = 'p3',
  MatchFormat format = MatchFormat.beachFivb,
}) {
  final startingTeam = (initialServerId == 'p1' || initialServerId == 'p2')
      ? TeamSide.e1
      : TeamSide.e2;
  final startingIdx =
      (initialServerId == 'p1' || initialServerId == 'p3') ? 0 : 1;

  return MatchState(
    format: format,
    teams: {
      TeamSide.e1: Team(
        name: teamE1Name,
        players: [Player(id: 'p1', name: p1), Player(id: 'p2', name: p2)],
      ),
      TeamSide.e2: Team(
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
    nextServerIndex: {
      startingTeam: (startingIdx + 1) % 2,
      startingTeam.other: 0,
    },
    firstServerIndex: {
      startingTeam: startingIdx,
      startingTeam.other: null,
    },
    rallyAnnotations: const [],
    rallyImpacts: const [],
    history: const [],
    sets: const [],
    setNumber: 1,
    scoreE1: 0,
    scoreE2: 0,
    sidesSwapped: false,
    notes: '',
    selectedPointIndex: null,
    changeSidePromptDismissed: false,
    changeSidePromptOpen: false,
    popup: null,
    matchOver: false,
    trackedTeams: const {TeamSide.e1, TeamSide.e2},
  );
}
