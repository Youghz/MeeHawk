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
      notes: 'Vent côté mer modéré. Emma dominante au service, 4 aces.',
    ),
    _match(
      id: 'seed_2',
      e1Name: 'Team Soleil',
      e2Name: 'Horizon Bleu',
      p1: 'Léa', p2: 'Camille',
      p3: 'Inès', p4: 'Pauline',
      setScores: [(21, 18), (18, 21), (15, 13)],
      startedAt: now.subtract(const Duration(days: 7, hours: 4, minutes: 30)),
      notes: 'Match très accroché. Belle remontée de Léa et Camille en 3e set.',
    ),
    _match(
      id: 'seed_3',
      e1Name: 'Sandy Boys',
      e2Name: 'Beach Kings',
      p1: 'Thomas', p2: 'Lucas',
      p3: 'Antoine', p4: 'Raphaël',
      setScores: [(21, 14), (21, 19)],
      startedAt: now.subtract(const Duration(days: 14, hours: 1)),
      notes: 'Thomas très efficace en attaque longue ligne. Domination nette.',
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
// Builder
// ---------------------------------------------------------------------------

MatchArchive _match({
  required String id,
  required String e1Name,
  required String e2Name,
  required String p1, required String p2,
  required String p3, required String p4,
  required List<(int, int)> setScores,
  required DateTime startedAt,
  String notes = '',
}) {
  final allHistory = <PointRecord>[];
  final allSets = <SetRecord>[];

  for (var si = 0; si < setScores.length; si++) {
    final (te1, te2) = setScores[si];
    final setNum = si + 1;
    allHistory.addAll(_buildSet(
      setNumber: setNum,
      targetE1: te1,
      targetE2: te2,
      p1: p1, p2: p2, p3: p3, p4: p4,
    ));
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
// Set builder — distributes wins evenly (Bresenham-style)
// ---------------------------------------------------------------------------

List<PointRecord> _buildSet({
  required int setNumber,
  required int targetE1,
  required int targetE2,
  required String p1, required String p2,
  required String p3, required String p4,
}) {
  final winners = _distributeWins(targetE1, targetE2);
  final points = <PointRecord>[];
  var e1 = 0;
  var e2 = 0;

  for (var i = 0; i < winners.length; i++) {
    final w = winners[i];
    if (w == TeamSide.e1) {
      e1++;
    } else {
      e2++;
    }

    // Alternate service: e2 serves on even points, e1 on odd
    final e1Serves = i.isOdd;
    final servingTeam = e1Serves ? TeamSide.e1 : TeamSide.e2;
    final serverName = e1Serves ? p1 : p3;
    final attackerName = w == TeamSide.e1 ? p1 : p3;

    final annotations = _genAnnotations(
      pointIndex: i,
      servingTeam: servingTeam,
      winner: w,
      serverName: serverName,
      attackerName: attackerName,
    );

    points.add(PointRecord(
      winner: w,
      annotations: annotations,
      scoreE1: e1,
      scoreE2: e2,
      setNumber: setNumber,
      serverId: w == TeamSide.e1 ? 'p1' : 'p3',
      impacts: _genImpacts(
        pointIndex: i,
        servingTeam: servingTeam,
        winner: w,
      ),
    ));
  }

  return points;
}

/// Bresenham-style even distribution of e1/e2 wins across total positions.
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

// ---------------------------------------------------------------------------
// Impact & annotation generators
// ---------------------------------------------------------------------------

/// Realistic ball impacts: server position → service landing → attack landing.
List<BallImpact> _genImpacts({
  required int pointIndex,
  required TeamSide servingTeam,
  required TeamSide winner,
}) {
  final yBase = 0.28 + (pointIndex % 5) * 0.11;
  final xVar = (pointIndex % 3) * 0.05;
  final e1Serves = servingTeam == TeamSide.e1;

  // Server position: far outside on serving team's side
  // e1 = left side (x<0.5), e2 = right side (x>0.5)
  final serverX = e1Serves ? 0.03 : 0.97;

  // Service landing: inside, on receiving team's side
  final receiveX = e1Serves
      ? 0.68 - xVar // lands on e2's side (right)
      : 0.32 + xVar; // lands on e1's side (left)
  final receiveSide = servingTeam.other;

  // Attack landing: inside, on winning team's opponent side
  final winnerIsE1 = winner == TeamSide.e1;
  final landX = winnerIsE1 ? 0.76 - xVar : 0.24 + xVar;
  final landSide = winner.other;
  final landY = yBase + 0.12;

  return [
    BallImpact(
      x: serverX,
      y: 0.5,
      isOutside: true,
      teamSide: servingTeam,
      playerId: e1Serves ? 'p1' : 'p3',
      isServerPosition: true,
    ),
    BallImpact(
      x: receiveX,
      y: yBase,
      isOutside: false,
      teamSide: receiveSide,
      playerId: receiveSide == TeamSide.e1 ? 'p1' : 'p3',
    ),
    BallImpact(
      x: landX,
      y: landY,
      isOutside: pointIndex % 9 == 0, // occasional out ball
      teamSide: landSide,
      playerId: landSide == TeamSide.e1 ? 'p1' : 'p3',
    ),
  ];
}

const _attackTypes = ['diagonale', 'longue ligne', 'zonée', 'coupée'];

List<Annotation> _genAnnotations({
  required int pointIndex,
  required TeamSide servingTeam,
  required TeamSide winner,
  required String serverName,
  required String attackerName,
}) {
  // Every 7th point: fault ending (no attack annotation)
  if (pointIndex % 7 == 0 && pointIndex > 0) {
    return [
      Annotation(
        type: 'service',
        text: 'Service · $serverName',
        team: servingTeam,
      ),
      Annotation(
        type: 'fault',
        text: 'Faute · ${winner == TeamSide.e1 ? 'Sophie' : 'Léa'}',
        team: winner.other,
      ),
    ];
  }

  // Every 5th point: block annotation
  if (pointIndex % 5 == 0 && pointIndex > 0) {
    return [
      Annotation(
        type: 'service',
        text: 'Service · $serverName',
        team: servingTeam,
      ),
      Annotation(
        type: 'block',
        text: 'Bloc · $attackerName',
        team: winner,
      ),
    ];
  }

  final attackType = _attackTypes[pointIndex % _attackTypes.length];
  return [
    Annotation(
      type: 'service',
      text: 'Service · $serverName',
      team: servingTeam,
    ),
    Annotation(
      type: 'attack',
      text: 'Attaque $attackType · $attackerName',
      team: winner,
    ),
  ];
}
