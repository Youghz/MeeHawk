import 'package:app/core/rules/attack_inference.dart';
import 'package:app/core/rules/service_rotation.dart';
import 'package:app/core/rules/set_rules.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final matchProvider =
    NotifierProvider<MatchNotifier, MatchState>(MatchNotifier.new);

class MatchNotifier extends Notifier<MatchState> {
  /// One-shot bootstrap state set by main() when rehydrating from storage.
  /// Consumed on first build().
  static MatchState? bootstrapState;

  @override
  MatchState build() {
    final b = bootstrapState;
    bootstrapState = null;
    return b ?? initialMatchState();
  }

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
      p1: p1, p2: p2, p3: p3, p4: p4,
      initialServerId: initialServerId,
    );
  }

  // ---------------------------------------------------------------------
  // Scoring
  // ---------------------------------------------------------------------

  void addPoint({
    required TeamSide winner,
    List<Annotation> annotations = const [],
  }) {
    if (state.matchOver) return;
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
    final firstIdx = Map<TeamSide, int?>.of(state.firstServerIndex);
    final nextIdx = Map<TeamSide, int>.of(state.nextServerIndex);
    firstIdx[winner] = idx;
    nextIdx[winner] = idx;
    state = state.copyWith(
      firstServerIndex: firstIdx,
      nextServerIndex: nextIdx,
      popup: null,
    );
    _commitPoint(winner: winner, annotations: popup.pendingAnnotations);
  }

  void _commitPoint({
    required TeamSide winner,
    required List<Annotation> annotations,
  }) {
    final servingTeam = state.teamOfPlayer(state.servingPlayerId)!;
    final rot = ServiceRotation.next(
      currentServerId: state.servingPlayerId,
      servingTeam: servingTeam,
      winner: winner,
      playersByTeam: {
        for (final ts in TeamSide.values)
          ts: state.teams[ts]!.players.map((p) => p.id).toList(),
      },
      nextServerIndex: state.nextServerIndex,
    );

    final newScoreE1 = state.scoreE1 + (winner == TeamSide.e1 ? 1 : 0);
    final newScoreE2 = state.scoreE2 + (winner == TeamSide.e2 ? 1 : 0);

    final merged = [...state.rallyAnnotations, ...annotations];
    final point = PointRecord(
      winner: winner,
      annotations: merged,
      scoreE1: newScoreE1,
      scoreE2: newScoreE2,
      setNumber: state.setNumber,
      serverId: rot.serverId,
      impacts: state.rallyImpacts,
    );

    final setWon = SetRules.isSetWon(
      newScoreE1,
      newScoreE2,
      state.setNumber,
      state.format,
    );

    if (setWon) {
      _finishSet(
        point: point,
        scoreE1: newScoreE1,
        scoreE2: newScoreE2,
        setWinner: winner,
      );
      return;
    }

    final total = newScoreE1 + newScoreE2;
    final shouldPrompt = !state.changeSidePromptDismissed &&
        SetRules.shouldPromptSideChange(
          totalPointsAfter: total,
          setNumber: state.setNumber,
          format: state.format,
        );

    state = state.copyWith(
      history: [...state.history, point],
      servingPlayerId: rot.serverId,
      nextServerIndex: rot.nextIndex,
      rallyAnnotations: const [],
      rallyImpacts: const [],
      popup: null,
      changeSidePromptOpen: shouldPrompt,
      scoreE1: newScoreE1,
      scoreE2: newScoreE2,
    );
  }

  void _finishSet({
    required PointRecord point,
    required int scoreE1,
    required int scoreE2,
    required TeamSide setWinner,
  }) {
    final setRecord = SetRecord(
      setNumber: state.setNumber,
      scoreE1: scoreE1,
      scoreE2: scoreE2,
      winner: setWinner,
    );
    final newSets = [...state.sets, setRecord];
    final matchOver = SetRules.isMatchWon(
      newSets.where((s) => s.winner == TeamSide.e1).length,
      newSets.where((s) => s.winner == TeamSide.e2).length,
      state.format,
    );

    state = state.copyWith(
      history: [...state.history, point],
      sets: newSets,
      scoreE1: scoreE1,
      scoreE2: scoreE2,
      rallyAnnotations: const [],
      rallyImpacts: const [],
      popup: MatchPopup(
        kind: matchOver ? PopupKind.matchEnd : PopupKind.setEnd,
        winner: setWinner,
      ),
      matchOver: matchOver,
      changeSidePromptOpen: false,
    );
  }

  /// Start a new set after a setEnd popup.
  void startNextSet() {
    if (state.popup?.kind != PopupKind.setEnd) return;
    // Alternate initial server team between sets. Starting team of set N
    // is the OTHER of the starting team of set N-1.
    final prevStart = state.teamOfPlayer(state.initialServerId)!;
    final newStart = state.setNumber.isOdd ? prevStart.other : prevStart;
    final newServerId = state.teams[newStart]!.players.first.id;

    state = state.copyWith(
      setNumber: state.setNumber + 1,
      scoreE1: 0,
      scoreE2: 0,
      rallyAnnotations: const [],
      rallyImpacts: const [],
      servingPlayerId: newServerId,
      initialServerId: newServerId,
      nextServerIndex: {
        newStart: 1,
        newStart.other: 0,
      },
      firstServerIndex: {
        newStart: 0,
        newStart.other: null,
      },
      sidesSwapped: !state.sidesSwapped,
      changeSidePromptDismissed: false,
      changeSidePromptOpen: false,
      popup: null,
    );
  }

  // ---------------------------------------------------------------------
  // Rally
  // ---------------------------------------------------------------------

  void addRallyAnnotation(Annotation a) {
    state = state.copyWith(
      rallyAnnotations: [...state.rallyAnnotations, a],
      popup: null,
    );
  }

  /// Record a touch with a known player. Delegates crossing annotation to
  /// addBallImpact, then appends a block annotation when isBlock is true.
  void addTouchWithPlayer(BallImpact impact) {
    addBallImpact(impact);
    if (!impact.isBlock) return;
    final player = state.playerById(impact.playerId ?? '');
    state = state.copyWith(
      rallyAnnotations: [
        ...state.rallyAnnotations,
        Annotation(
          type: 'block',
          text: 'Bloc · ${player?.name ?? '—'}',
          team: impact.teamSide,
        ),
      ],
    );
  }

  /// Called when the player-picker bubble is confirmed. Fills in the player
  /// on the pending impact and records the touch.
  void confirmPlayerPick(String playerId) {
    final popup = state.popup;
    if (popup == null || popup.kind != PopupKind.pickPlayer) return;
    final pending = popup.pendingImpact!;
    state = state.copyWith(popup: null);
    addTouchWithPlayer(
      BallImpact(
        x: pending.x,
        y: pending.y,
        isOutside: pending.isOutside,
        teamSide: pending.teamSide,
        playerId: playerId,
        isServerPosition: pending.isServerPosition,
        isBlock: pending.isBlock,
      ),
    );
  }

  /// Record a ball impact during the current rally. If this impact lands on
  /// the opposite side of the net from the previous one, auto-annotate the
  /// attack (or the serve, for the first crossing) with an inferred type.
  /// Server-position markers are exempt; all other impacts enforce the
  /// volleyball 3-touch rule per team.
  void addBallImpact(BallImpact impact) {
    if (!impact.isServerPosition &&
        _consecutiveSameSideTouches(state.rallyImpacts, impact.teamSide) >=
            3) {
      // 4th touch: record the impact position then auto-fault.
      final player = impact.playerId != null
          ? state.playerById(impact.playerId!)
          : null;
      state = state.copyWith(
        rallyImpacts: [...state.rallyImpacts, impact],
      );
      addPoint(
        winner: impact.teamSide.other,
        annotations: [
          Annotation(
            type: 'fault',
            text: 'Faute 4e touche · ${player?.name ?? '—'}',
            team: impact.teamSide,
          ),
        ],
      );
      return;
    }
    final prev = state.rallyImpacts.isNotEmpty
        ? state.rallyImpacts.last
        : null;
    var annotations = state.rallyAnnotations;
    if (prev != null && prev.teamSide != impact.teamSide && !prev.isBlock) {
      final type = AttackInference.classify(
        fromX: prev.x,
        fromY: prev.y,
        toX: impact.x,
        toY: impact.y,
      );
      final attacker = prev.playerId != null
          ? state.playerById(prev.playerId!)?.name ?? '—'
          : '—';
      final isService = state.rallyImpacts.length == 1;
      final label = isService ? 'Service' : 'Attaque';
      annotations = [
        ...state.rallyAnnotations,
        Annotation(
          type: isService ? 'service' : 'attack',
          text: '$label $type · $attacker',
          team: prev.teamSide,
        ),
      ];
    }
    state = state.copyWith(
      rallyImpacts: [...state.rallyImpacts, impact],
      rallyAnnotations: annotations,
    );
  }

  // ---------------------------------------------------------------------
  // Undo
  // ---------------------------------------------------------------------

  /// Remove the last recorded ball impact from the current rally. Removes
  /// the block annotation (if any) and the crossing annotation (if any) that
  /// were generated when this impact was recorded.
  void undoLastImpact() {
    if (state.rallyImpacts.isEmpty) return;
    final impacts = state.rallyImpacts;
    final last = impacts.last;
    final prev = impacts.length >= 2 ? impacts[impacts.length - 2] : null;
    final newImpacts = impacts.sublist(0, impacts.length - 1);

    var annotations = state.rallyAnnotations;
    // Block annotation is added after the crossing annotation, remove first.
    if (last.isBlock && annotations.isNotEmpty) {
      annotations = annotations.sublist(0, annotations.length - 1);
    }
    // Crossing annotation (attack / service) added by addBallImpact.
    // Not present when prev was a block — block annotation covers the crossing.
    if (prev != null &&
        !last.isServerPosition &&
        !prev.isBlock &&
        prev.teamSide != last.teamSide &&
        annotations.isNotEmpty) {
      annotations = annotations.sublist(0, annotations.length - 1);
    }

    state = state.copyWith(
      rallyImpacts: newImpacts,
      rallyAnnotations: annotations,
    );
  }

  void undoPoint() {
    if (state.history.isEmpty) return;
    if (state.matchOver) {
      // Re-open the match: clear matchOver + setEnd popup so UI becomes
      // interactive again.
      state = state.copyWith(matchOver: false, popup: null);
    }
    final newHistory = state.history.sublist(0, state.history.length - 1);
    final replay = _replay(newHistory);

    state = state.copyWith(
      history: newHistory,
      selectedPointIndex: null,
      servingPlayerId: replay.serverId,
      nextServerIndex: replay.nextIndex,
      scoreE1: replay.scoreE1,
      scoreE2: replay.scoreE2,
      sets: replay.sets,
      setNumber: replay.setNumber,
      matchOver: false,
      popup: null,
    );
  }

  ({
    String serverId,
    Map<TeamSide, int> nextIndex,
    int scoreE1,
    int scoreE2,
    int setNumber,
    List<SetRecord> sets,
  }) _replay(List<PointRecord> history) {
    var serverId = state.initialServerId;
    final startingTeam = state.teamOfPlayer(serverId)!;
    final startingFirst = state.firstServerIndex[startingTeam]!;
    final otherFirst = state.firstServerIndex[startingTeam.other];
    var nextIndex = <TeamSide, int>{
      startingTeam: (startingFirst + 1) %
          state.teams[startingTeam]!.players.length,
      startingTeam.other: otherFirst ?? 0,
    };
    var scoreE1 = 0;
    var scoreE2 = 0;
    var setNumber = 1;
    final sets = <SetRecord>[];

    for (final p in history) {
      // Catch up set transitions if this point belongs to a later set.
      while (p.setNumber > setNumber) {
        sets.add(SetRecord(
          setNumber: setNumber,
          scoreE1: scoreE1,
          scoreE2: scoreE2,
          winner: scoreE1 > scoreE2 ? TeamSide.e1 : TeamSide.e2,
        ));
        scoreE1 = 0;
        scoreE2 = 0;
        setNumber++;
      }

      final servingTeam = state.teamOfPlayer(serverId)!;
      final rot = ServiceRotation.next(
        currentServerId: serverId,
        servingTeam: servingTeam,
        winner: p.winner,
        playersByTeam: {
          for (final ts in TeamSide.values)
            ts: state.teams[ts]!.players.map((pl) => pl.id).toList(),
        },
        nextServerIndex: nextIndex,
      );
      serverId = rot.serverId;
      nextIndex = rot.nextIndex;

      if (p.winner == TeamSide.e1) scoreE1++;
      if (p.winner == TeamSide.e2) scoreE2++;
    }

    return (
      serverId: serverId,
      nextIndex: nextIndex,
      scoreE1: scoreE1,
      scoreE2: scoreE2,
      setNumber: setNumber,
      sets: sets,
    );
  }

  // ---------------------------------------------------------------------
  // Selection / notes / layout
  // ---------------------------------------------------------------------

  void selectPoint(int index) =>
      state = state.copyWith(selectedPointIndex: index);

  void clearSelection() => state = state.copyWith(selectedPointIndex: null);

  /// Show the final score of [setNumber] without selecting a specific point.
  /// No-op in live match; overridden in ReplayNotifier.
  void viewSet(int setNumber) {}

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
    final teams = <TeamSide, Team>{};
    state.teams.forEach((tk, team) {
      teams[tk] = team.copyWith(
        players: team.players
            .map((p) => p.id == playerId ? p.copyWith(name: name) : p)
            .toList(),
      );
    });
    state = state.copyWith(teams: teams);
  }

  void renameTeam(TeamSide teamKey, String name) {
    final teams = Map<TeamSide, Team>.of(state.teams);
    teams[teamKey] = teams[teamKey]!.copyWith(name: name);
    state = state.copyWith(teams: teams);
  }

  /// Discard all in-progress rally impacts, annotations and dismissible popups
  /// without awarding a point. Called when the user taps outside the court band.
  void clearRally() {
    final popup = state.popup;
    final hasDismissiblePopup = popup != null &&
        (popup.kind == PopupKind.fault || popup.kind == PopupKind.pickPlayer);
    if (!hasDismissiblePopup &&
        state.rallyImpacts.isEmpty &&
        state.rallyAnnotations.isEmpty) {
      return;
    }
    state = state.copyWith(
      rallyImpacts: const [],
      rallyAnnotations: const [],
      popup: null,
    );
  }

  void toggleTeamTracking(TeamSide teamSide) {
    final current = state.trackedTeams;
    final updated = current.contains(teamSide)
        ? current.difference({teamSide})
        : {...current, teamSide};
    state = state.copyWith(trackedTeams: updated);
  }

  void showPopup(MatchPopup popup) => state = state.copyWith(popup: popup);

  void dismissPopup() => state = state.copyWith(popup: null);
}

/// Counts consecutive same-team touches at the tail of [impacts].
/// Server-position markers are skipped — they are not ball contacts.
/// Blocks count as one of the team's 3 allowed touches. The blocker may
/// touch again after their own block (beach FIVB rule), but that second
/// contact still consumes a touch — so block + 2 touches = 3 total.
int _consecutiveSameSideTouches(List<BallImpact> impacts, TeamSide side) {
  var count = 0;
  for (var i = impacts.length - 1; i >= 0; i--) {
    if (impacts[i].isServerPosition) continue;
    if (impacts[i].teamSide != side) break;
    count++;
  }
  return count;
}
