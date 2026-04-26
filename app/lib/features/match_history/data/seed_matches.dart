import 'package:app/core/rules/attack_inference.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match_history/domain/match_archive.dart';

List<MatchArchive> buildSeedMatches() {
  final now = DateTime.now();
  return [
    _match(
      id: 'seed_1',
      e1Name: "Sables d'Or",
      e2Name: 'Les Vagues',
      p1: 'Emma', p2: 'Julie',
      p3: 'Sophie', p4: 'Manon',
      setScores: [(21, 16), (18, 21), (15, 12)],
      startedAt: now.subtract(const Duration(days: 3, hours: 2, minutes: 15)),
      notes: 'Vent côté mer modéré. Emma dominante au service. Beau 3e set.',
    ),
  ];
}

// ---------------------------------------------------------------------------
// Match builder
// ---------------------------------------------------------------------------

MatchArchive _match({
  required String id,
  required String e1Name,
  required String e2Name,
  required String p1,
  required String p2,
  required String p3,
  required String p4,
  required List<(int, int)> setScores,
  required DateTime startedAt,
  String notes = '',
}) {
  final allHistory = <PointRecord>[];
  final allSets = <SetRecord>[];

  for (var si = 0; si < setScores.length; si++) {
    final (te1, te2) = setScores[si];
    final setNum = si + 1;
    allHistory.addAll(
      _buildSet(
        setNumber: setNum,
        targetE1: te1,
        targetE2: te2,
        p1: p1, p2: p2, p3: p3, p4: p4,
      ),
    );
    allSets.add(SetRecord(
      setNumber: setNum,
      scoreE1: te1,
      scoreE2: te2,
      winner: te1 > te2 ? TeamSide.e1 : TeamSide.e2,
    ));
  }

  final last = setScores.last;
  final setsE1Won = allSets.where((s) => s.winner == TeamSide.e1).length;
  final setsE2Won = allSets.where((s) => s.winner == TeamSide.e2).length;
  final totalSets = setScores.length;

  return MatchArchive(
    id: id,
    startedAt: startedAt,
    state: MatchState(
      format: MatchFormat.beachFivb,
      teams: {
        TeamSide.e1: Team(
          name: e1Name,
          players: [Player(id: 'p1', name: p1), Player(id: 'p2', name: p2)],
        ),
        TeamSide.e2: Team(
          name: e2Name,
          players: [Player(id: 'p3', name: p3), Player(id: 'p4', name: p4)],
        ),
      },
      positions: const {
        'p1': CourtPos(0.25, 0.35),
        'p2': CourtPos(0.25, 0.70),
        'p3': CourtPos(0.75, 0.35),
        'p4': CourtPos(0.75, 0.70),
      },
      servingPlayerId: setsE1Won >= setsE2Won ? 'p1' : 'p3',
      initialServerId: 'p3',
      nextServerIndex: const {TeamSide.e1: 1, TeamSide.e2: 1},
      firstServerIndex: const {TeamSide.e1: 0, TeamSide.e2: 0},
      rallyAnnotations: const [],
      rallyImpacts: const [],
      history: allHistory,
      sets: allSets,
      setNumber: totalSets,
      scoreE1: last.$1,
      scoreE2: last.$2,
      sidesSwapped: false,
      notes: notes,
      selectedPointIndex: null,
      changeSidePromptDismissed: false,
      changeSidePromptOpen: false,
      popup: null,
      matchOver: true,
      started: true,
      trackedTeams: const {TeamSide.e1, TeamSide.e2},
      startedAt: startedAt,
    ),
  );
}

// ---------------------------------------------------------------------------
// Set builder
// ---------------------------------------------------------------------------

List<PointRecord> _buildSet({
  required int setNumber,
  required int targetE1,
  required int targetE2,
  required String p1,
  required String p2,
  required String p3,
  required String p4,
}) {
  const e1Players = ['p1', 'p2'];
  const e2Players = ['p3', 'p4'];
  final playerNames = <String, String>{
    'p1': p1, 'p2': p2, 'p3': p3, 'p4': p4,
  };

  final winners = _distributeWins(targetE1, targetE2);
  final points = <PointRecord>[];
  var e1 = 0;
  var e2 = 0;

  var srvTeam = setNumber.isOdd ? TeamSide.e2 : TeamSide.e1;
  final nextSrvIdx = <TeamSide, int>{TeamSide.e1: 0, TeamSide.e2: 0};

  for (var i = 0; i < winners.length; i++) {
    final winner = winners[i];
    if (winner == TeamSide.e1) {
      e1++;
    } else {
      e2++;
    }

    final srvPlayers = srvTeam == TeamSide.e1 ? e1Players : e2Players;
    final srvPid = srvPlayers[nextSrvIdx[srvTeam]!];
    final srvName = playerNames[srvPid]!;

    final seed =
        (i + 1) * 1337 + setNumber * 61 + (srvTeam == TeamSide.e1 ? 0 : 179);

    final winPid =
        (winner == TeamSide.e1 ? e1Players : e2Players)[_h(seed * 7) % 2];
    final winName = playerNames[winPid]!;

    final losePid =
        (winner.other == TeamSide.e1 ? e1Players : e2Players)[_h(seed * 11) % 2];
    final loseName = playerNames[losePid]!;

    final rawEx = _pickExchanges(_h(seed));
    final visits =
        rawEx == 0 ? <(TeamSide, int)>[] : _planVisits(seed, srvTeam, winner, rawEx);

    final impacts = _genImpacts(
      seed: seed,
      servingTeam: srvTeam,
      winner: winner,
      visits: visits,
      e1Players: e1Players,
      e2Players: e2Players,
      serverId: srvPid,
    );

    // Pass last two impacts so annotations can infer attack direction.
    final atkImpact = impacts.length >= 2 ? impacts[impacts.length - 2] : null;
    final landImpact = impacts.isNotEmpty ? impacts.last : null;

    final annotations = _genAnnotations(
      seed: seed,
      servingTeam: srvTeam,
      winner: winner,
      visits: visits,
      srvName: srvName,
      winName: winName,
      loseName: loseName,
      atkImpact: atkImpact,
      landImpact: landImpact,
    );

    points.add(PointRecord(
      winner: winner,
      annotations: annotations,
      scoreE1: e1,
      scoreE2: e2,
      setNumber: setNumber,
      serverId: srvPid,
      impacts: impacts,
    ));

    if (winner != srvTeam) {
      nextSrvIdx[srvTeam] = 1 - nextSrvIdx[srvTeam]!;
      srvTeam = winner;
    }
  }

  return points;
}

// ---------------------------------------------------------------------------
// Rally planning — visits
// ---------------------------------------------------------------------------

int _h(int x) => (x * 1664525 + 1013904223) & 0x7FFFFFFF;

int _pickExchanges(int h) {
  final r = h % 100;
  if (r < 12) return 0;
  if (r < 27) return 1;
  if (r < 52) return 2;
  if (r < 72) return 3;
  if (r < 87) return 4;
  return 5;
}

List<(TeamSide, int)> _planVisits(
  int seed,
  TeamSide srv,
  TeamSide winner,
  int rawExchanges,
) {
  final recv = srv.other;
  var n = rawExchanges.clamp(1, 6);
  final wantOdd = winner == recv;
  if (n.isOdd != wantOdd) n = (n + 1).clamp(1, 6);

  final visits = <(TeamSide, int)>[];
  var side = recv;
  for (var vi = 0; vi < n; vi++) {
    final isLast = vi == n - 1;
    final vs = _h(seed ^ (vi * 37 + 7));
    final maxC = isLast ? 2 : 3;
    final contacts = 1 + vs % maxC;
    visits.add((side, contacts));
    side = side.other;
  }
  return visits;
}

// ---------------------------------------------------------------------------
// Impact generation
// ---------------------------------------------------------------------------

List<BallImpact> _genImpacts({
  required int seed,
  required TeamSide servingTeam,
  required TeamSide winner,
  required List<(TeamSide, int)> visits,
  required List<String> e1Players,
  required List<String> e2Players,
  required String serverId,
}) {
  final impacts = <BallImpact>[];
  final recv = servingTeam.other;
  final isE1Srv = servingTeam == TeamSide.e1;

  // Server starting position (outside, behind the end line).
  impacts.add(BallImpact(
    x: isE1Srv ? 0.03 : 0.97,
    y: 0.50,
    isOutside: true,
    teamSide: servingTeam,
    playerId: serverId,
    isServerPosition: true,
  ));

  if (visits.isEmpty) {
    // 0 exchanges: ace (winner=srv) or service fault (winner=recv).
    final r = _h(seed * 3);
    final isAce = winner == servingTeam;
    final double x;
    if (isAce) {
      // Ball lands in receiver's half.
      x = isE1Srv
          ? (0.62 + (r % 7) * 0.04).clamp(0.55, 0.90) // E2's half
          : (0.38 - (r % 7) * 0.04).clamp(0.10, 0.45); // E1's half
    } else {
      // Service fault: ball stays on server's own half (didn't clear net).
      x = isE1Srv
          ? (0.25 + (r % 7) * 0.04).clamp(0.10, 0.44) // E1's own half
          : (0.75 - (r % 7) * 0.04).clamp(0.56, 0.90); // E2's own half
    }
    final y = (0.25 + (r >> 4 & 7) * 0.08).clamp(0.15, 0.85);
    impacts.add(BallImpact(
      x: x,
      y: y,
      isOutside: !isAce,
      teamSide: isAce ? recv : servingTeam,
      playerId: isAce
          ? (recv == TeamSide.e1 ? e1Players : e2Players)[r % 2]
          : serverId,
    ));
    return impacts;
  }

  // One impact per contact across all visits, then the final landing.
  // Use independent x/y seeds and wider ranges to avoid overlaps.
  for (var vi = 0; vi < visits.length; vi++) {
    final (side, contacts) = visits[vi];
    final players = side == TeamSide.e1 ? e1Players : e2Players;
    for (var c = 0; c < contacts; c++) {
      final rx = _h(seed ^ (vi * 1531 + c * 251));
      final ry = _h(seed ^ (vi * 1531 + c * 251 + 7919));
      final baseX = side == TeamSide.e1 ? 0.25 : 0.75;
      // x spread ±0.18 around the team's half-court centre
      final xOff = ((rx % 23) - 11) * 0.016;
      // y spread across the full court width with fine granularity
      final y = (0.08 + (ry & 63) * 0.014).clamp(0.08, 0.92);
      impacts.add(BallImpact(
        x: (baseX + xOff).clamp(0.06, 0.94),
        y: y,
        isOutside: false,
        teamSide: side,
        playerId: players[(seed + vi + c) % 2],
      ));
    }
  }

  // Final landing on the loser's side.
  final loser = winner.other;
  final lPlayers = loser == TeamSide.e1 ? e1Players : e2Players;
  final fr = _h(seed ^ 0xBEEF);
  final fy = _h(seed ^ 0xDEAD);
  final fx = loser == TeamSide.e1 ? 0.25 : 0.75;
  impacts.add(BallImpact(
    x: (fx + ((fr % 23) - 11) * 0.016).clamp(0.06, 0.94),
    y: (0.08 + (fy & 63) * 0.014).clamp(0.08, 0.92),
    isOutside: false,
    teamSide: loser,
    playerId: lPlayers[fr % 2],
  ));

  return impacts;
}

// ---------------------------------------------------------------------------
// Annotation generation
// ---------------------------------------------------------------------------

List<Annotation> _genAnnotations({
  required int seed,
  required TeamSide servingTeam,
  required TeamSide winner,
  required List<(TeamSide, int)> visits,
  required String srvName,
  required String winName,
  required String loseName,
  required BallImpact? atkImpact,
  required BallImpact? landImpact,
}) {
  final srvAnnot = Annotation(
    type: 'service',
    text: 'Service · $srvName',
    team: servingTeam,
  );

  if (visits.isEmpty) {
    if (winner == servingTeam) {
      return [
        Annotation(type: 'service', text: 'Ace · $srvName', team: servingTeam),
      ];
    }
    return [
      srvAnnot,
      Annotation(
          type: 'fault', text: 'Faute service · $srvName', team: servingTeam),
    ];
  }

  final lastContacts = visits.last.$2;
  final canBlock = visits.length >= 2 && lastContacts == 1;

  final r = _h(seed * 41) % 100;
  final Annotation finalAnnot;
  if (r < 12) {
    finalAnnot = Annotation(
      type: 'fault',
      text: 'Faute · $loseName',
      team: winner.other,
    );
  } else if (canBlock && r < 30) {
    finalAnnot = Annotation(
      type: 'block',
      text: 'Bloc · $winName',
      team: winner,
    );
  } else {
    // Infer attack direction from actual impact positions.
    final t = (atkImpact != null && landImpact != null)
        ? AttackInference.classify(
            fromX: atkImpact.x,
            fromY: atkImpact.y,
            toX: landImpact.x,
            toY: landImpact.y,
          )
        : 'Diagonale';
    finalAnnot = Annotation(
      type: 'attack',
      text: 'Attaque $t · $winName',
      team: winner,
    );
  }

  return [srvAnnot, finalAnnot];
}

// ---------------------------------------------------------------------------
// Bresenham-style win distribution
// ---------------------------------------------------------------------------

List<TeamSide> _distributeWins(int e1Count, int e2Count) {
  final total = e1Count + e2Count;
  final result = <TeamSide>[];
  var usedE1 = 0;
  for (var i = 1; i <= total; i++) {
    final expectedE1 = (i * e1Count / total).ceil();
    result.add(usedE1 < expectedE1 ? TeamSide.e1 : TeamSide.e2);
    if (result.last == TeamSide.e1) usedE1++;
  }
  return result;
}
