import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_data.dart';

final matchProvider = NotifierProvider<MatchNotifier, MatchState>(MatchNotifier.new);

class MatchState {
  final MatchData? match;
  final PendingPoint pending;
  final bool isSetup;
  final bool needsServerPick;

  MatchState({
    this.match,
    PendingPoint? pending,
    this.isSetup = true,
    this.needsServerPick = false,
  }) : pending = pending ?? PendingPoint();

  MatchState copyWith({
    MatchData? match,
    PendingPoint? pending,
    bool? isSetup,
    bool? needsServerPick,
  }) =>
      MatchState(
        match: match ?? this.match,
        pending: pending ?? this.pending,
        isSetup: isSetup ?? this.isSetup,
        needsServerPick: needsServerPick ?? this.needsServerPick,
      );
}

class MatchNotifier extends Notifier<MatchState> {
  @override
  MatchState build() => MatchState();

  void startMatch({
    required String playerA,
    required String playerB,
    required String opponentA,
    required String opponentB,
    required int pointsPerSet,
    String teamUsName = 'Equipe A',
    String teamThemName = 'Equipe B',
  }) {
    state = MatchState(
      match: MatchData(
        teamUsName: teamUsName,
        teamThemName: teamThemName,
        playerA: playerA,
        playerB: playerB,
        opponentA: opponentA,
        opponentB: opponentB,
        pointsPerSet: pointsPerSet,
      ),
      isSetup: false,
      needsServerPick: true,
    );
  }

  void pickServer(String playerName) {
    final match = state.match;
    if (match == null) return;

    match.servingPlayer = playerName;

    // Record as last server for this team
    if (match.servingTeam == 'us') {
      match.lastUsServer = playerName;
    } else {
      match.lastThemServer = playerName;
    }

    state = state.copyWith(match: match, needsServerPick: false);
  }

  void setTeamUsName(String name) {
    state.match?.teamUsName = name;
    state = state.copyWith(match: state.match);
  }

  void setTeamThemName(String name) {
    state.match?.teamThemName = name;
    state = state.copyWith(match: state.match);
  }

  void setPlayerA(String name) {
    state.match?.playerA = name;
    state = state.copyWith(match: state.match);
  }

  void setPlayerB(String name) {
    state.match?.playerB = name;
    state = state.copyWith(match: state.match);
  }

  void setOpponentA(String name) {
    state.match?.opponentA = name;
    state = state.copyWith(match: state.match);
  }

  void setOpponentB(String name) {
    state.match?.opponentB = name;
    state = state.copyWith(match: state.match);
  }

  void setServeZone(String zone) {
    state.pending.serveZone = zone;
    state = state.copyWith(pending: state.pending);
  }

  void setReceiver(String receiver) {
    state.pending.receiver = receiver;
    state = state.copyWith(pending: state.pending);
  }

  void setAttackType(String? type) {
    state.pending.attackType = state.pending.attackType == type ? null : type;
    state = state.copyWith(pending: state.pending);
  }

  void setBlockDirection(String? dir) {
    state.pending.blockDirection = state.pending.blockDirection == dir ? null : dir;
    state = state.copyWith(pending: state.pending);
  }

  void scorePoint(String result) {
    final match = state.match;
    if (match == null || match.servingPlayer == null) return;

    // Set already won — don't score more
    if (match.scoreUs >= match.pointsPerSet ||
        match.scoreThem >= match.pointsPerSet) {
      return;
    }

    if (result == 'us') {
      match.scoreUs++;
    } else {
      match.scoreThem++;
    }

    match.points.add(PointRecord(
      pointNumber: match.points.length + 1,
      setNumber: match.currentSet,
      serveZone: state.pending.serveZone,
      receiver: state.pending.receiver,
      attackType: state.pending.attackType,
      blockDirection: state.pending.blockDirection,
      result: result,
      servingTeam: match.servingTeam,
      servingPlayer: match.servingPlayer!,
      scoreUs: match.scoreUs,
      scoreThem: match.scoreThem,
    ));

    // The team that wins the point serves next
    final newServingTeam = result;
    final teamChanged = newServingTeam != match.servingTeam;
    match.servingTeam = newServingTeam;

    if (teamChanged) {
      // Service goes to the other team — pick the next server
      final lastServer = newServingTeam == 'us'
          ? match.lastUsServer
          : match.lastThemServer;

      if (lastServer == null) {
        // First time this team serves — ask user to pick
        match.servingPlayer = null;
        state.pending.reset();
        state = state.copyWith(
            match: match, pending: state.pending, needsServerPick: true);
        return;
      }

      // Alternate: the OTHER player serves (not the one who served last)
      if (newServingTeam == 'us') {
        match.servingPlayer =
            lastServer == match.playerA ? match.playerB : match.playerA;
        match.lastUsServer = match.servingPlayer;
      } else {
        match.servingPlayer =
            lastServer == match.opponentA ? match.opponentB : match.opponentA;
        match.lastThemServer = match.servingPlayer;
      }
    }
    // If same team keeps serving, same player continues

    state.pending.reset();
    state = state.copyWith(match: match, pending: state.pending);
  }

  void undo() {
    final match = state.match;
    if (match == null || match.points.isEmpty) return;

    final last = match.points.removeLast();
    if (last.result == 'us') {
      match.scoreUs--;
    } else {
      match.scoreThem--;
    }
    match.servingTeam = last.servingTeam;
    match.servingPlayer = last.servingPlayer;

    // Restore lastServer for the team that was serving
    if (last.servingTeam == 'us') {
      match.lastUsServer = last.servingPlayer;
    } else {
      match.lastThemServer = last.servingPlayer;
    }

    state.pending.reset();
    state = state.copyWith(
        match: match, pending: state.pending, needsServerPick: false);
  }

  void nextSet() {
    final match = state.match;
    if (match == null) return;
    match.currentSet++;
    match.scoreUs = 0;
    match.scoreThem = 0;
    state = state.copyWith(match: match);
  }

  void toggleServing() {
    final match = state.match;
    if (match == null) return;
    match.servingTeam = match.servingTeam == 'us' ? 'them' : 'us';
    match.servingPlayer = null;
    state = state.copyWith(match: match, needsServerPick: true);
  }

  void endMatch() {
    state = MatchState();
  }
}
