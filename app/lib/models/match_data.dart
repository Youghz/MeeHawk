class PointRecord {
  final int pointNumber;
  final int setNumber;
  final String? serveZone;
  final String? receiver;
  final String? attackType;
  final String? blockDirection;
  final String result; // "us" or "them"
  final String servingTeam; // "us" or "them"
  final String servingPlayer; // name of the server
  final int scoreUs;
  final int scoreThem;

  PointRecord({
    required this.pointNumber,
    required this.setNumber,
    this.serveZone,
    this.receiver,
    this.attackType,
    this.blockDirection,
    required this.result,
    required this.servingTeam,
    required this.servingPlayer,
    required this.scoreUs,
    required this.scoreThem,
  });

  String summary(String playerA, String playerB) {
    final parts = <String>[];
    parts.add('$servingPlayer sert');
    if (serveZone != null) parts.add('zone $serveZone');
    if (receiver != null) {
      parts.add('${receiver == "player_a" ? playerA : playerB} rec');
    }
    if (attackType != null) parts.add(attackType!);
    if (blockDirection != null) parts.add('bloc ${blockDirection!}');
    return parts.join(' · ');
  }
}

class MatchData {
  String teamUsName;
  String teamThemName;
  String playerA;
  String playerB;
  String opponentA;
  String opponentB;
  int pointsPerSet;
  int scoreUs;
  int scoreThem;
  int currentSet;
  String servingTeam; // "us" or "them"
  String? servingPlayer; // name — null means we need to ask
  String? lastUsServer; // last player who served for us
  String? lastThemServer; // last player who served for them
  final List<PointRecord> points;

  MatchData({
    this.teamUsName = 'Equipe A',
    this.teamThemName = 'Equipe B',
    required this.playerA,
    required this.playerB,
    this.opponentA = 'Joueur 1',
    this.opponentB = 'Joueur 2',
    this.pointsPerSet = 21,
    this.scoreUs = 0,
    this.scoreThem = 0,
    this.currentSet = 1,
    this.servingTeam = 'us',
    this.servingPlayer,
    this.lastUsServer,
    this.lastThemServer,
    List<PointRecord>? points,
  }) : points = points ?? [];
}

class PendingPoint {
  String? serveZone;
  String? receiver;
  String? attackType;
  String? blockDirection;

  void reset() {
    serveZone = null;
    receiver = null;
    attackType = null;
    blockDirection = null;
  }
}
