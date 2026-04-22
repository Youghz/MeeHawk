import 'package:app/features/match/domain/match_state.dart';

/// JSON codec for [MatchState]. Only persists long-lived data: no popups,
/// no selectedPointIndex, no in-progress rally. The rally in progress when
/// the app closes is lost — a realistic trade-off.
class MatchCodec {
  static const schemaVersion = 1;

  static Map<String, dynamic> toJson(MatchState s) => {
        'v': schemaVersion,
        'format': _formatToJson(s.format),
        'teams': {
          for (final e in s.teams.entries)
            e.key.key: {
              'name': e.value.name,
              'players': e.value.players
                  .map((p) => {'id': p.id, 'name': p.name})
                  .toList(),
            },
        },
        'positions': {
          for (final e in s.positions.entries)
            e.key: [e.value.x, e.value.y],
        },
        'servingPlayerId': s.servingPlayerId,
        'initialServerId': s.initialServerId,
        'nextServerIndex': {
          for (final e in s.nextServerIndex.entries) e.key.key: e.value,
        },
        'firstServerIndex': {
          for (final e in s.firstServerIndex.entries) e.key.key: e.value,
        },
        'history': s.history.map(_pointToJson).toList(),
        'sets': s.sets.map(_setToJson).toList(),
        'setNumber': s.setNumber,
        'scoreE1': s.scoreE1,
        'scoreE2': s.scoreE2,
        'sidesSwapped': s.sidesSwapped,
        'notes': s.notes,
        'changeSidePromptDismissed': s.changeSidePromptDismissed,
        'matchOver': s.matchOver,
      };

  static MatchState fromJson(Map<String, dynamic> j) {
    final teamsJson = (j['teams'] as Map).cast<String, dynamic>();
    final positionsJson = (j['positions'] as Map).cast<String, dynamic>();
    return MatchState(
      format: _formatFromJson(j['format'] as Map<String, dynamic>?),
      teams: {
        for (final e in teamsJson.entries)
          TeamSide.fromKey(e.key): Team(
            name: (e.value as Map)['name'] as String,
            players: ((e.value as Map)['players'] as List)
                .map((p) => Player(
                      id: (p as Map)['id'] as String,
                      name: p['name'] as String,
                    ))
                .toList(),
          ),
      },
      positions: {
        for (final e in positionsJson.entries)
          e.key: CourtPos(
            (e.value as List)[0] as double,
            (e.value as List)[1] as double,
          ),
      },
      servingPlayerId: j['servingPlayerId'] as String,
      initialServerId: j['initialServerId'] as String,
      nextServerIndex: _intMapFromJson(j['nextServerIndex']),
      firstServerIndex: _nullableIntMapFromJson(j['firstServerIndex']),
      rallyAnnotations: const [],
      rallyImpacts: const [],
      history: (j['history'] as List)
          .map((p) => _pointFromJson(p as Map<String, dynamic>))
          .toList(),
      sets: (j['sets'] as List)
          .map((s) => _setFromJson(s as Map<String, dynamic>))
          .toList(),
      setNumber: j['setNumber'] as int,
      scoreE1: j['scoreE1'] as int,
      scoreE2: j['scoreE2'] as int,
      sidesSwapped: j['sidesSwapped'] as bool,
      notes: j['notes'] as String,
      selectedPointIndex: null,
      changeSidePromptDismissed:
          j['changeSidePromptDismissed'] as bool? ?? false,
      changeSidePromptOpen: false,
      popup: null,
      matchOver: j['matchOver'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _formatToJson(MatchFormat f) => {
        'setsToWin': f.setsToWin,
        'regularSetPoints': f.regularSetPoints,
        'decidingSetPoints': f.decidingSetPoints,
        'winBy': f.winBy,
        'regularChangeSideEvery': f.regularChangeSideEvery,
        'decidingChangeSideEvery': f.decidingChangeSideEvery,
      };

  static MatchFormat _formatFromJson(Map<String, dynamic>? j) {
    if (j == null) return MatchFormat.beachFivb;
    return MatchFormat(
      setsToWin: j['setsToWin'] as int,
      regularSetPoints: j['regularSetPoints'] as int,
      decidingSetPoints: j['decidingSetPoints'] as int,
      winBy: j['winBy'] as int,
      regularChangeSideEvery: j['regularChangeSideEvery'] as int,
      decidingChangeSideEvery: j['decidingChangeSideEvery'] as int,
    );
  }

  static Map<TeamSide, int> _intMapFromJson(dynamic j) {
    final m = (j as Map).cast<String, dynamic>();
    return {
      for (final e in m.entries) TeamSide.fromKey(e.key): e.value as int,
    };
  }

  static Map<TeamSide, int?> _nullableIntMapFromJson(dynamic j) {
    final m = (j as Map).cast<String, dynamic>();
    return {
      for (final e in m.entries) TeamSide.fromKey(e.key): e.value as int?,
    };
  }

  static Map<String, dynamic> _pointToJson(PointRecord p) => {
        'winner': p.winner.key,
        'annotations': p.annotations.map(_annotationToJson).toList(),
        'scoreE1': p.scoreE1,
        'scoreE2': p.scoreE2,
        'setNumber': p.setNumber,
        'serverId': p.serverId,
        'impacts': p.impacts.map(_impactToJson).toList(),
      };

  static PointRecord _pointFromJson(Map<String, dynamic> j) => PointRecord(
        winner: TeamSide.fromKey(j['winner'] as String),
        annotations: (j['annotations'] as List)
            .map((a) => _annotationFromJson(a as Map<String, dynamic>))
            .toList(),
        scoreE1: j['scoreE1'] as int,
        scoreE2: j['scoreE2'] as int,
        setNumber: j['setNumber'] as int? ?? 1,
        serverId: j['serverId'] as String,
        impacts: (j['impacts'] as List? ?? const [])
            .map((i) => _impactFromJson(i as Map<String, dynamic>))
            .toList(),
      );

  static Map<String, dynamic> _annotationToJson(Annotation a) => {
        'type': a.type,
        'text': a.text,
        'team': a.team?.key,
      };

  static Annotation _annotationFromJson(Map<String, dynamic> j) => Annotation(
        type: j['type'] as String,
        text: j['text'] as String,
        team:
            j['team'] == null ? null : TeamSide.fromKey(j['team'] as String),
      );

  static Map<String, dynamic> _impactToJson(BallImpact i) => {
        'x': i.x,
        'y': i.y,
        'isOutside': i.isOutside,
        'teamSide': i.teamSide.key,
        'playerId': i.playerId,
      };

  static BallImpact _impactFromJson(Map<String, dynamic> j) => BallImpact(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        isOutside: j['isOutside'] as bool,
        teamSide: TeamSide.fromKey(j['teamSide'] as String),
        playerId: j['playerId'] as String?,
      );

  static Map<String, dynamic> _setToJson(SetRecord r) => {
        'setNumber': r.setNumber,
        'scoreE1': r.scoreE1,
        'scoreE2': r.scoreE2,
        'winner': r.winner.key,
      };

  static SetRecord _setFromJson(Map<String, dynamic> j) => SetRecord(
        setNumber: j['setNumber'] as int,
        scoreE1: j['scoreE1'] as int,
        scoreE2: j['scoreE2'] as int,
        winner: TeamSide.fromKey(j['winner'] as String),
      );
}
