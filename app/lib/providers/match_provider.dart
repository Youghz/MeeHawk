import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';

final matchProvider =
    NotifierProvider<MatchNotifier, MatchState>(MatchNotifier.new);

class MatchNotifier extends Notifier<MatchState> {
  @override
  MatchState build() => initialMatchState();

  void startMatch({
    required String teamE1Name,
    required String teamE2Name,
    required String p1,
    required String p2,
    required String p3,
    required String p4,
    required String initialServerId,
  }) {
    state = initialMatchState(
      teamE1Name: teamE1Name,
      teamE2Name: teamE2Name,
      p1: p1,
      p2: p2,
      p3: p3,
      p4: p4,
      initialServerId: initialServerId,
    );
  }

  void addPoint({
    required String winner,
    List<Annotation> annotations = const [],
  }) {
    final servingTeam = state.teamOfPlayer(state.servingPlayerId)!;
    final gainsServe = winner != servingTeam;
    if (gainsServe && state.firstServerIndex[winner] == null) {
      state = state.copyWith(
        popup: MatchPopup(
          kind: PopupKind.pickServer,
          winner: winner,
          pendingAnnotations: annotations,
        ),
      );
      return;
    }
    _commitPoint(winner: winner, annotations: annotations);
  }

  void pickFirstServer(String playerId) {
    final popup = state.popup;
    if (popup == null || popup.kind != PopupKind.pickServer) return;
    final winner = popup.winner;
    final team = state.teams[winner]!;
    final idx = team.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;
    final firstIdx = Map<String, int?>.of(state.firstServerIndex);
    final nextIdx = Map<String, int>.of(state.nextServerIndex);
    firstIdx[winner] = idx;
    nextIdx[winner] = idx;
    state = state.copyWith(
      firstServerIndex: firstIdx,
      nextServerIndex: nextIdx,
      popup: null,
    );
    _commitPoint(
      winner: winner,
      annotations: popup.pendingAnnotations,
    );
  }

  void _commitPoint({
    required String winner,
    required List<Annotation> annotations,
  }) {
    final servingTeam = state.teamOfPlayer(state.servingPlayerId)!;
    String newServerId;
    final nextIdx = Map<String, int>.of(state.nextServerIndex);

    if (winner == servingTeam) {
      newServerId = state.servingPlayerId;
    } else {
      final team = state.teams[winner]!;
      final idx = state.nextServerIndex[winner]!;
      newServerId = team.players[idx % team.players.length].id;
      nextIdx[winner] = (idx + 1) % team.players.length;
    }

    final newScoreE1 = state.scoreE1 + (winner == 'e1' ? 1 : 0);
    final newScoreE2 = state.scoreE2 + (winner == 'e2' ? 1 : 0);
    final merged = [...state.rallyAnnotations, ...annotations];
    final point = PointRecord(
      winner: winner,
      annotations: merged,
      scoreE1: newScoreE1,
      scoreE2: newScoreE2,
      serverId: newServerId,
      impacts: state.rallyImpacts,
    );
    final total = newScoreE1 + newScoreE2;
    final shouldPrompt =
        !state.changeSidePromptDismissed && total > 0 && total % 7 == 0;

    state = state.copyWith(
      history: [...state.history, point],
      servingPlayerId: newServerId,
      nextServerIndex: nextIdx,
      rallyAnnotations: const [],
      rallyImpacts: const [],
      popup: null,
      changeSidePromptOpen: shouldPrompt,
    );
  }

  void addRallyAnnotation(Annotation a) {
    state = state.copyWith(
      rallyAnnotations: [...state.rallyAnnotations, a],
      popup: null,
    );
  }

  void addBallImpact(BallImpact impact) {
    state = state.copyWith(
      rallyImpacts: [...state.rallyImpacts, impact],
    );
  }

  void undoPoint() {
    if (state.history.isEmpty) return;
    final newHistory = state.history.sublist(0, state.history.length - 1);
    final replay = _replay(newHistory);
    state = state.copyWith(
      history: newHistory,
      selectedPointIndex: null,
      servingPlayerId: replay.$1,
      nextServerIndex: replay.$2,
    );
  }

  (String, Map<String, int>) _replay(List<PointRecord> history) {
    String servingPlayerId = state.initialServerId;
    final startingTeam = state.teamOfPlayer(servingPlayerId)!;
    final otherTeam = startingTeam == 'e1' ? 'e2' : 'e1';
    final startingFirst = state.firstServerIndex[startingTeam]!;
    final otherFirst = state.firstServerIndex[otherTeam];
    final nextServerIndex = <String, int>{
      startingTeam:
          (startingFirst + 1) % state.teams[startingTeam]!.players.length,
      otherTeam: otherFirst ?? 0,
    };

    for (final p in history) {
      final servingTeam = state.teamOfPlayer(servingPlayerId)!;
      if (p.winner == servingTeam) continue;
      final team = state.teams[p.winner]!;
      final idx = nextServerIndex[p.winner]!;
      servingPlayerId = team.players[idx % team.players.length].id;
      nextServerIndex[p.winner] = (idx + 1) % team.players.length;
    }
    return (servingPlayerId, nextServerIndex);
  }

  void selectPoint(int index) =>
      state = state.copyWith(selectedPointIndex: index);

  void clearSelection() => state = state.copyWith(selectedPointIndex: null);

  void swapTeammates(String playerId) {
    final teamKey = state.teamOfPlayer(playerId);
    if (teamKey == null) return;
    final team = state.teams[teamKey]!;
    if (team.players.length < 2) return;
    final other = team.players.firstWhere((p) => p.id != playerId).id;
    final newPos = Map<String, CourtPos>.of(state.positions);
    final a = newPos[playerId]!;
    final b = newPos[other]!;
    newPos[playerId] = b;
    newPos[other] = a;
    state = state.copyWith(positions: newPos);
  }

  void setNotes(String notes) => state = state.copyWith(notes: notes);

  void swapSides() {
    final mirrored = <String, CourtPos>{};
    state.positions.forEach((id, p) {
      mirrored[id] = CourtPos(1 - p.x, p.y);
    });
    state = state.copyWith(
      positions: mirrored,
      sidesSwapped: !state.sidesSwapped,
      changeSidePromptOpen: false,
    );
  }

  void dismissChangeSideForever() => state = state.copyWith(
        changeSidePromptOpen: false,
        changeSidePromptDismissed: true,
      );

  void closeChangeSidePrompt() =>
      state = state.copyWith(changeSidePromptOpen: false);

  void renamePlayer(String playerId, String name) {
    final teams = <String, Team>{};
    state.teams.forEach((tk, team) {
      teams[tk] = team.copyWith(
        players: team.players
            .map((p) => p.id == playerId ? p.copyWith(name: name) : p)
            .toList(),
      );
    });
    state = state.copyWith(teams: teams);
  }

  void renameTeam(String teamKey, String name) {
    final teams = Map<String, Team>.of(state.teams);
    teams[teamKey] = teams[teamKey]!.copyWith(name: name);
    state = state.copyWith(teams: teams);
  }

  void showPopup(MatchPopup popup) => state = state.copyWith(popup: popup);

  void dismissPopup() => state = state.copyWith(popup: null);
}
