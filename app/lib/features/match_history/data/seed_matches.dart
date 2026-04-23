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
      setScores: [(21, 16), (21, 18)],
      startedAt: now.subtract(const Duration(days: 3, hours: 2, minutes: 15)),
      notes: 'Vent côté mer modéré. Emma dominante au service.',
    ),
    _match(
      id: 'seed_2',
      e1Name: 'Team Soleil',
      e2Name: 'Horizon Bleu',
      p1: 'Léa', p2: 'Camille',
      p3: 'Inès', p4: 'Pauline',
      setScores: [(21, 18), (18, 21), (15, 13)],
      startedAt: now.subtract(const Duration(days: 7, hours: 4, minutes: 30)),
      notes: 'Match très accroché. Belle remontée en 3e set.',
    ),
    _match(
      id: 'seed_3',
      e1Name: 'Sandy Boys',
      e2Name: 'Beach Kings',
      p1: 'Thomas', p2: 'Lucas',
      p3: 'Antoine', p4: 'Raphaël',
      setScores: [(21, 14), (21, 19)],
      startedAt: now.subtract(const Duration(days: 14, hours: 1)),
      notes: 'Thomas très efficace en attaque longue ligne.',
    ),
    _match(
      id: 'seed_4',
      e1Name: "Côte d'Azur",
      e2Name: 'Les Dauphins',
      p1: 'Sarah', p2: 'Alice',
      p3: 'Marie', p4: 'Clara',
      setScores: [(15, 21), (18, 21)],
      startedAt: now.subtract(const Duration(days: 21, hours: 3, minutes: 45)),
      notes: 'Défaite face à une équipe expérimentée. Bonne réception de Sarah.',
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
      servingPlayerId: setsE1Won > 0 ? 'p1' : 'p3',
      initialServerId: 'p3',
      nextServerIndex: const {TeamSide.e1: 1, TeamSide.e2: 1},
      firstServerIndex: const {TeamSide.e1: 0, TeamSide.e2: 0},
      rallyAnnotations: const [],
      rallyImpacts: const [],
      history: allHistory,
      sets: allSets,
      setNumber: setScores.length,
      scoreE1: last.$1,
      scoreE2: last.$2,
      sidesSwapped: false,
      notes: notes,
      selectedPointIndex: null,
      changeSidePromptDismissed: false,
      changeSidePromptOpen: false,
      popup: null,
      matchOver: true,
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

  // Service rotation: odd sets → E2 serves first, even sets → E1.
  // Each time a team loses service, their server index rotates so the other
  // player serves next time they earn the right to serve.
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

    // Point-level seed mixes point index, set, serving team, and a prime.
    final seed = (i + 1) * 1337 + setNumber * 61 + (srvTeam == TeamSide.e1 ? 0 : 179);

    // Attacker / blocker from winner's team
    final winPid = (winner == TeamSide.e1 ? e1Players : e2Players)[_h(seed * 7) % 2];
    final winName = playerNames[winPid]!;

    // Faulting player from loser's team
    final losePid =
        (winner.other == TeamSide.e1 ? e1Players : e2Players)[_h(seed * 11) % 2];
    final loseName = playerNames[losePid]!;

    // Pick target rally length (exchanges 0–5) then plan the visit sequence.
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

    final annotations = _genAnnotations(
      seed: seed,
      servingTeam: srvTeam,
      winner: winner,
      visits: visits,
      srvName: srvName,
      winName: winName,
      loseName: loseName,
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

    // If the receiving team won, service changes and the outgoing server's
    // index rotates so their teammate serves next time they earn service.
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

// Simple LCG hash for deterministic pseudo-randomness.
int _h(int x) => (x * 1664525 + 1013904223) & 0x7FFFFFFF;

// Weighted exchanges distribution (0 = ace or service fault).
int _pickExchanges(int h) {
  final r = h % 100;
  if (r < 12) return 0;
  if (r < 27) return 1;
  if (r < 52) return 2;
  if (r < 72) return 3;
  if (r < 87) return 4;
  return 5;
}

// Builds an ordered list of (side, contactCount) visits representing each
// possession after the service. Visits alternate sides starting from recv.
// The last visit is always on winner's side (the team that wins the rally),
// after which the ball crosses to the loser's side for the final landing.
//
// Beach-volleyball rule: a block is only valid when the blocking team had
// zero prior contacts in that possession (i.e. exactly 1 contact = the block
// itself). Annotations enforce this by checking visits.last.$2 == 1 and
// visits.length >= 2.
List<(TeamSide, int)> _planVisits(
  int seed,
  TeamSide srv,
  TeamSide winner,
  int rawExchanges,
) {
  final recv = srv.other;
  // visits[i].side = recv if i.isEven, srv if i.isOdd.
  // Need visits[n-1].side == winner.
  // winner==recv → (n-1).isEven → n.isOdd
  // winner==srv  → (n-1).isOdd  → n.isEven
  var n = rawExchanges.clamp(1, 6);
  final wantOdd = winner == recv;
  if (n.isOdd != wantOdd) n = (n + 1).clamp(1, 6);

  final visits = <(TeamSide, int)>[];
  var side = recv;
  for (var vi = 0; vi < n; vi++) {
    final isLast = vi == n - 1;
    final vs = _h(seed ^ (vi * 37 + 7));
    // Winner's final possession: 1–2 contacts (set + attack or direct attack).
    // All other possessions: 1–3 contacts (dig + set + attack or dig + attack).
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

  // Server starting position (outside, behind the end line).
  impacts.add(BallImpact(
    x: servingTeam == TeamSide.e1 ? 0.03 : 0.97,
    y: 0.50,
    isOutside: true,
    teamSide: servingTeam,
    playerId: serverId,
    isServerPosition: true,
  ));

  if (visits.isEmpty) {
    // 0 exchanges: service landing only — ace (winner=srv) or fault (winner=recv).
    final r = _h(seed * 3);
    final isAce = winner == servingTeam;
    final baseX = servingTeam == TeamSide.e1 ? 0.65 : 0.35;
    final xOff = (r % 7) * 0.04 * (servingTeam == TeamSide.e1 ? 1 : -1);
    final x = (baseX + xOff).clamp(0.55, 0.94);
    final y = (0.25 + (r >> 4 & 7) * 0.08).clamp(0.15, 0.85);
    impacts.add(BallImpact(
      x: x,
      y: y,
      isOutside: !isAce,
      teamSide: recv,
      playerId: (recv == TeamSide.e1 ? e1Players : e2Players)[r % 2],
    ));
    return impacts;
  }

  // One impact per contact across all visits, then the final landing.
  for (var vi = 0; vi < visits.length; vi++) {
    final (side, contacts) = visits[vi];
    final players = side == TeamSide.e1 ? e1Players : e2Players;
    for (var c = 0; c < contacts; c++) {
      final r = _h(seed ^ (vi * 97 + c * 13));
      final baseX = side == TeamSide.e1 ? 0.25 : 0.75;
      final xOff = ((r % 11) - 5) * 0.025;
      final y = (0.20 + (r >> 4 & 7) * 0.09).clamp(0.15, 0.85);
      impacts.add(BallImpact(
        x: (baseX + xOff).clamp(0.06, 0.94),
        y: y,
        isOutside: false,
        teamSide: side,
        playerId: players[(seed + vi + c) % 2],
      ));
    }
  }

  // Final landing on the loser's side (winner's attack was not returned).
  final loser = winner.other;
  final lPlayers = loser == TeamSide.e1 ? e1Players : e2Players;
  final fr = _h(seed ^ 0xBEEF);
  final fx = loser == TeamSide.e1 ? 0.25 : 0.75;
  impacts.add(BallImpact(
    x: (fx + ((fr % 11) - 5) * 0.03).clamp(0.06, 0.94),
    y: (0.20 + (fr >> 4 & 7) * 0.09).clamp(0.15, 0.85),
    isOutside: false,
    teamSide: loser,
    playerId: lPlayers[fr % 2],
  ));

  return impacts;
}

// ---------------------------------------------------------------------------
// Annotation generation
// ---------------------------------------------------------------------------

const _atkTypes = ['diagonale', 'longue ligne', 'zonée', 'coupée'];

List<Annotation> _genAnnotations({
  required int seed,
  required TeamSide servingTeam,
  required TeamSide winner,
  required List<(TeamSide, int)> visits,
  required String srvName,
  required String winName,
  required String loseName,
}) {
  final srvAnnot = Annotation(
    type: 'service',
    text: 'Service · $srvName',
    team: servingTeam,
  );

  // 0 exchanges: ace or service fault.
  if (visits.isEmpty) {
    if (winner == servingTeam) {
      return [Annotation(type: 'service', text: 'Ace · $srvName', team: servingTeam)];
    }
    return [
      srvAnnot,
      Annotation(type: 'fault', text: 'Faute service · $srvName', team: servingTeam),
    ];
  }

  // Multi-exchange rally: service + final action.
  final lastContacts = visits.last.$2;

  // Block rule: winner's last possession has exactly 1 contact (the block),
  // AND there was at least one prior possession where the losing team attacked
  // (visits.length >= 2 guarantees that).
  final canBlock = visits.length >= 2 && lastContacts == 1;

  final r = _h(seed * 41) % 100;
  final Annotation finalAnnot;
  if (r < 12) {
    // Losing team faulted (ball went out or into the net).
    finalAnnot = Annotation(
      type: 'fault',
      text: 'Faute · $loseName',
      team: winner.other,
    );
  } else if (canBlock && r < 30) {
    // Winning team blocked the opponent's attack.
    finalAnnot = Annotation(
      type: 'block',
      text: 'Bloc · $winName',
      team: winner,
    );
  } else {
    final t = _atkTypes[_h(seed * 19) % _atkTypes.length];
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
