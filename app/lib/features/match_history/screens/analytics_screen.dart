import 'dart:math';
import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({required this.state, super.key});
  final MatchState state;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int? _filterSet;

  MatchState get _s => widget.state;
  String get _e1 => _s.teams[TeamSide.e1]!.name;
  String get _e2 => _s.teams[TeamSide.e2]!.name;

  List<PointRecord> get _pts => _filterSet == null
      ? _s.history
      : _s.history.where((p) => p.setNumber == _filterSet).toList();

  List<int> get _sets => _s.sets.map((s) => s.setNumber).toList()..sort();

  /// Returns (point, servingTeam) by reconstructing server rotation.
  List<({PointRecord pt, TeamSide server})> get _ptsWithServer {
    var serverId = _s.initialServerId;
    final servers = <TeamSide>[];
    for (final p in _s.history) {
      servers.add(_s.teamOfPlayer(serverId) ?? TeamSide.e1);
      serverId = p.serverId;
    }
    return [
      for (var i = 0; i < _s.history.length; i++)
        if (_filterSet == null || _s.history[i].setNumber == _filterSet)
          (pt: _s.history[i], server: servers[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasSets = _sets.length > 1;
    return Scaffold(
      backgroundColor: MH.paper,
      appBar: AppBar(
        backgroundColor: MH.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MH.ink,
        elevation: 0,
        title: Text('Analyse', style: MH.sans(size: 18, weight: FontWeight.w700)),
        bottom: hasSets
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: _SetFilter(
                  sets: _sets,
                  selected: _filterSet,
                  onSelect: (v) => setState(() => _filterSet = v),
                ),
              )
            : null,
      ),
      body: _pts.isEmpty
          ? Center(
              child: Text(
                'Aucun point enregistré',
                style: MH.sans(color: MH.pencil),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              children: [
                _summary(),
                _sep(),
                _serviceEfficiency(),
                _sep(),
                _serviceZones(),
                _sep(),
                _attackZones(),
                _sep(),
                _actionTypes(),
                _sep(),
                _scoreProgression(),
                _sep(),
                _rallyLength(),
                _sep(),
                _keyMoments(),
              ],
            ),
    );
  }

  Widget _sep() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(height: 32, color: MH.rule),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // RÉSUMÉ
  // ─────────────────────────────────────────────────────────────────────────

  Widget _summary() {
    final pts = _pts;
    final e1Pts = pts.where((p) => p.winner == TeamSide.e1).length;
    final e2Pts = pts.where((p) => p.winner == TeamSide.e2).length;
    final setsToShow = _filterSet != null
        ? _s.sets.where((s) => s.setNumber == _filterSet).toList()
        : _s.sets;
    final setsE1 = setsToShow.where((s) => s.winner == TeamSide.e1).length;
    final setsE2 = setsToShow.where((s) => s.winner == TeamSide.e2).length;

    return _Section(
      title: 'RÉSUMÉ',
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(_e1,
                style: MH.sans(weight: FontWeight.w700, color: MH.them),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Text(_e2,
                style: MH.sans(weight: FontWeight.w700, color: MH.us),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$setsE1',
              style: MH.mono(size: 32, weight: FontWeight.w800, color: MH.them)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('–', style: MH.mono(size: 28, color: MH.rule)),
          ),
          Text('$setsE2',
              style: MH.mono(size: 32, weight: FontWeight.w800, color: MH.us)),
        ]),
        Text('sets gagnés', style: MH.mono(), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        _Row3('$e1Pts', 'Points total', '$e2Pts',
            leftBold: e1Pts > e2Pts, rightBold: e2Pts > e1Pts),
        const SizedBox(height: 8),
        ...setsToShow.map((ss) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _Row3(
                '${ss.scoreE1}',
                'Set ${ss.setNumber}',
                '${ss.scoreE2}',
                leftBold: ss.winner == TeamSide.e1,
                rightBold: ss.winner == TeamSide.e2,
              ),
            )),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICE EFFICIENCY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _serviceEfficiency() {
    final pairs = _ptsWithServer;
    if (pairs.isEmpty) return const SizedBox.shrink();

    final e1Serve = pairs.where((p) => p.server == TeamSide.e1).toList();
    final e2Serve = pairs.where((p) => p.server == TeamSide.e2).toList();
    final e1ServeWins = e1Serve.where((p) => p.pt.winner == TeamSide.e1).length;
    final e1RecvWins = e2Serve.where((p) => p.pt.winner == TeamSide.e1).length;
    final e2ServeWins = e2Serve.where((p) => p.pt.winner == TeamSide.e2).length;
    final e2RecvWins = e1Serve.where((p) => p.pt.winner == TeamSide.e2).length;

    return _Section(
      title: 'EFFICACITÉ AU SERVICE',
      child: Column(children: [
        _serviceRow(_e1, MH.them, e1ServeWins, e1Serve.length, e1RecvWins, e2Serve.length),
        const SizedBox(height: 16),
        _serviceRow(_e2, MH.us, e2ServeWins, e2Serve.length, e2RecvWins, e1Serve.length),
      ]),
    );
  }

  Widget _serviceRow(
    String name,
    Color color,
    int serveWins,
    int serveTotal,
    int recvWins,
    int recvTotal,
  ) {
    final sr = serveTotal > 0 ? serveWins / serveTotal : 0.0;
    final rr = recvTotal > 0 ? recvWins / recvTotal : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(name,
                style: MH.sans(size: 12, weight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: _BarStat(
                label: 'Au service',
                count: '$serveWins/$serveTotal',
                rate: sr,
                color: color)),
        const SizedBox(width: 12),
        Expanded(
            child: _BarStat(
                label: 'À la réception',
                count: '$recvWins/$recvTotal',
                rate: rr,
                color: color.withValues(alpha: 0.45))),
      ]),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICE LANDING ZONES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _serviceZones() {
    final pairs = _ptsWithServer;
    final dots = <_Dot>[];

    for (final (:pt, :server) in pairs) {
      // First non-server-position impact = service landing
      BallImpact? landing;
      var seenServer = false;
      for (final imp in pt.impacts) {
        if (imp.isServerPosition) {
          seenServer = true;
          continue;
        }
        if (seenServer) {
          landing = imp;
          break;
        }
      }
      if (landing == null) continue;

      final won = pt.winner == server;
      dots.add(_Dot(
        x: landing.x,
        y: landing.y,
        color: server == TeamSide.e1 ? MH.them : MH.us,
        hollow: !won,
      ));
    }

    return _Section(
      title: 'ZONES DE SERVICE',
      subtitle: 'Réception du service — plein = point gagné · cercle = point perdu',
      child: Column(children: [
        _AnalyticsCourt(dots: dots),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _LegendDot(color: MH.them, label: '$_e1 au service'),
          const SizedBox(width: 16),
          _LegendDot(color: MH.us, label: '$_e2 au service'),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATTACK / ENDING ZONES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _attackZones() {
    final dots = <_Dot>[];
    for (final p in _pts) {
      final real = p.impacts.where((i) => !i.isServerPosition).toList();
      if (real.isEmpty) continue;
      final last = real.last;
      dots.add(_Dot(
        x: last.x,
        y: last.y,
        color: p.winner == TeamSide.e1 ? MH.them : MH.us,
        hollow: last.isOutside,
      ));
    }

    return _Section(
      title: "ZONES D'ATTAQUE",
      subtitle: 'Position finale du ballon — plein = en jeu · cercle = hors',
      child: Column(children: [
        _AnalyticsCourt(dots: dots),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _LegendDot(color: MH.them, label: 'Point $_e1'),
          const SizedBox(width: 16),
          _LegendDot(color: MH.us, label: 'Point $_e2'),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION TYPES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _actionTypes() {
    final pts = _pts;
    if (pts.isEmpty) return const SizedBox.shrink();

    // How each point ends (last annotation type)
    final endings = <String, int>{};
    final attackSubs = <String, ({int total, int wins})>{};

    for (final p in pts) {
      final anns = p.annotations;
      if (anns.isEmpty) continue;
      final last = anns.last;
      endings[last.type] = (endings[last.type] ?? 0) + 1;

      if (last.type == 'attack') {
        final sub = _subtype(last.text);
        if (sub != null && sub.isNotEmpty) {
          final prev = attackSubs[sub] ?? (total: 0, wins: 0);
          final won = last.team == p.winner;
          attackSubs[sub] = (total: prev.total + 1, wins: prev.wins + (won ? 1 : 0));
        }
      }
    }

    final total = pts.length;
    const typeLabels = {
      'attack': 'Attaque gagnante',
      'block': 'Bloc direct',
      'fault': 'Faute adverse',
      'service': 'Ace / retour direct',
    };
    const typeColors = {
      'attack': MH.ink,
      'block': MH.ball,
      'fault': MH.mid,
      'service': MH.pencil,
    };

    final sorted = endings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final subMaxTotal = attackSubs.isEmpty
        ? 1
        : attackSubs.values.map((v) => v.total).reduce(max);

    final subSorted = attackSubs.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return _Section(
      title: 'COMMENT FINISSENT LES POINTS',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...sorted.map((e) {
          final label = typeLabels[e.key] ?? e.key;
          final color = typeColors[e.key] ?? MH.pencil;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LabeledBar(
              label: label,
              value: '${e.value} pts · ${(e.value / total * 100).round()}%',
              ratio: e.value / total,
              color: color,
            ),
          );
        }),
        if (subSorted.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text("Efficacité par type d'attaque",
              style: MH.mono(size: 9)),
          const SizedBox(height: 10),
          ...subSorted.map((e) {
            final wr = e.value.total > 0 ? e.value.wins / e.value.total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LabeledBar(
                label: _cap(e.key),
                value: '${e.value.wins}/${e.value.total} · ${(wr * 100).round()}%',
                ratio: e.value.total / subMaxTotal,
                color: MH.ink,
                winRatio: wr,
              ),
            );
          }),
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCORE PROGRESSION
  // ─────────────────────────────────────────────────────────────────────────

  Widget _scoreProgression() {
    final setsToShow = _filterSet != null ? [_filterSet!] : _sets;

    return _Section(
      title: 'PROGRESSION DU SCORE',
      subtitle: 'Rouge $_e1  ·  Vert $_e2',
      child: Column(
        children: setsToShow.map((setNum) {
          final setPts = _s.history
              .where((p) => p.setNumber == setNum)
              .toList();
          if (setPts.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (setsToShow.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Set $setNum', style: MH.mono(size: 9)),
                ),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  size: const Size(double.infinity, 110),
                  painter: _ScoreChartPainter(points: setPts),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RALLY LENGTH
  // ─────────────────────────────────────────────────────────────────────────

  Widget _rallyLength() {
    final groups = <int, ({int total, int e1Wins})>{};
    for (final p in _pts) {
      final key = min(p.netCrossings, 4);
      final prev = groups[key] ?? (total: 0, e1Wins: 0);
      groups[key] = (
        total: prev.total + 1,
        e1Wins: prev.e1Wins + (p.winner == TeamSide.e1 ? 1 : 0),
      );
    }
    if (groups.isEmpty) return const SizedBox.shrink();

    final maxTotal = groups.values.map((v) => v.total).reduce(max);
    final sorted = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    const labels = {
      0: 'Direct',
      1: '1 passage',
      2: '2 passages',
      3: '3 passages',
      4: '4+ passages',
    };

    return _Section(
      title: 'LONGUEUR DES ÉCHANGES',
      subtitle: 'Passages au filet — rouge $_e1 · vert $_e2',
      child: Column(
        children: sorted.map((e) {
          final label = labels[e.key] ?? '${e.key}+';
          final e1R = e.value.total > 0 ? e.value.e1Wins / e.value.total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RallyBar(
              label: label,
              total: e.value.total,
              maxTotal: maxTotal,
              e1Ratio: e1R,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KEY MOMENTS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _keyMoments() {
    final pts = _pts;
    if (pts.isEmpty) return const SizedBox.shrink();

    final streakE1 = _maxStreak(pts, TeamSide.e1);
    final streakE2 = _maxStreak(pts, TeamSide.e2);

    var leadE1 = 0;
    var leadE2 = 0;
    for (final p in pts) {
      final d = p.scoreE1 - p.scoreE2;
      if (d > leadE1) leadE1 = d;
      if (-d > leadE2) leadE2 = -d;
    }

    final pressurePts = pts.where((p) => p.scoreE1 >= 15 || p.scoreE2 >= 15).toList();
    final pressE1 = pressurePts.where((p) => p.winner == TeamSide.e1).length;

    final decPts = pts.where((p) => p.scoreE1 >= 18 || p.scoreE2 >= 18).toList();
    final decE1 = decPts.where((p) => p.winner == TeamSide.e1).length;

    final first5 = pts.take(min(5, pts.length)).toList();
    final f5E1 = first5.where((p) => p.winner == TeamSide.e1).length;

    return _Section(
      title: 'MOMENTS DÉCISIFS',
      child: Column(children: [
        _Row3('$streakE1 pts', 'Série max consécutive', '$streakE2 pts',
            leftBold: streakE1 > streakE2, rightBold: streakE2 > streakE1),
        const SizedBox(height: 8),
        _Row3('+$leadE1', 'Avance maximale', '+$leadE2',
            leftBold: leadE1 > leadE2, rightBold: leadE2 > leadE1),
        if (pressurePts.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Row3(
            '$pressE1/${pressurePts.length}',
            'Points ≥ 15',
            '${pressurePts.length - pressE1}/${pressurePts.length}',
            leftBold: pressE1 > pressurePts.length - pressE1,
            rightBold: pressE1 < pressurePts.length - pressE1,
          ),
        ],
        if (decPts.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Row3(
            '$decE1/${decPts.length}',
            'Points ≥ 18 (tension)',
            '${decPts.length - decE1}/${decPts.length}',
            leftBold: decE1 > decPts.length - decE1,
            rightBold: decE1 < decPts.length - decE1,
          ),
        ],
        if (first5.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Row3(
            '$f5E1/${first5.length}',
            '5 premiers pts',
            '${first5.length - f5E1}/${first5.length}',
            leftBold: f5E1 > first5.length - f5E1,
            rightBold: f5E1 < first5.length - f5E1,
          ),
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pure helpers
  // ─────────────────────────────────────────────────────────────────────────

  int _maxStreak(List<PointRecord> pts, TeamSide team) {
    var best = 0;
    var cur = 0;
    for (final p in pts) {
      if (p.winner == team) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return best;
  }

  String? _subtype(String text) {
    final parts = text.split('·');
    if (parts.isEmpty) return null;
    final words = parts[0].trim().split(' ');
    if (words.length <= 1) return null;
    return words.sublist(1).join(' ').trim();
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Set filter chips
// ─────────────────────────────────────────────────────────────────────────────

class _SetFilter extends StatelessWidget {
  const _SetFilter({required this.sets, required this.selected, required this.onSelect});
  final List<int> sets;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        color: MH.paper,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          _Chip(label: 'Tout', active: selected == null, onTap: () => onSelect(null)),
          ...sets.map((s) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _Chip(
                  label: 'Set $s',
                  active: selected == s,
                  onTap: () => onSelect(selected == s ? null : s),
                ),
              )),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? MH.ink : MH.sand,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: MH.sans(
              size: 11,
              weight: FontWeight.w600,
              color: active ? MH.paper : MH.inkSoft,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics court
// ─────────────────────────────────────────────────────────────────────────────

class _Dot {
  const _Dot({required this.x, required this.y, required this.color, this.hollow = false});
  final double x;
  final double y;
  final Color color;
  final bool hollow;
}

class _AnalyticsCourt extends StatelessWidget {
  const _AnalyticsCourt({required this.dots});
  final List<_Dot> dots;

  static const _m = 30.0; // margin (slightly smaller than kCourtMargin=36)

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = (w - _m * 2) / 2 + _m * 2;
          return SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: _CourtBgPainter(_m))),
              ...dots.map((d) {
                const r = 5.0;
                return Positioned(
                  left: d.x * w - r,
                  top: d.y * h - r,
                  child: Container(
                    width: r * 2,
                    height: r * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.hollow ? Colors.transparent : d.color.withValues(alpha: 0.8),
                      border: d.hollow ? Border.all(color: d.color, width: 1.5) : null,
                    ),
                  ),
                );
              }),
            ]),
          );
        },
      );
}

class _CourtBgPainter extends CustomPainter {
  const _CourtBgPainter(this.margin);
  final double margin;

  @override
  void paint(Canvas canvas, Size size) {
    final inner = Rect.fromLTWH(
        margin, margin, size.width - margin * 2, size.height - margin * 2);

    canvas
      ..drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = MH.ruleSoft)
      ..drawRect(inner, Paint()..color = MH.sand)
      ..drawLine(
        Offset(size.width / 2, margin),
        Offset(size.width / 2, size.height - margin),
        Paint()..color = MH.pencil..strokeWidth = 1.5,
      )
      ..drawRect(
          inner,
          Paint()
            ..color = MH.rule
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_CourtBgPainter old) => old.margin != margin;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: MH.sans(size: 10, color: MH.pencil),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Score step chart
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreChartPainter extends CustomPainter {
  const _ScoreChartPainter({required this.points});
  final List<PointRecord> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxScore = points.map((p) => max(p.scoreE1, p.scoreE2)).reduce(max).toDouble();
    if (maxScore == 0) return;

    // Grid lines every 5 points
    final gridPaint = Paint()..color = MH.rule..strokeWidth = 0.5;
    for (var s = 0; s <= maxScore.toInt(); s += 5) {
      final y = size.height - (s / maxScore) * (size.height - 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // Score labels
      final tp = TextPainter(
        text: TextSpan(
          text: '$s',
          style: const TextStyle(color: MH.pencil, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height - 1));
    }

    void drawStepLine(Color color, int Function(PointRecord) scoreOf) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(0, size.height);
      var prev = 0;
      for (var i = 0; i < points.length; i++) {
        final x = (i + 1) / points.length * size.width;
        final oldY = size.height - (prev / maxScore) * (size.height - 4);
        path.lineTo(x, oldY);
        final cur = scoreOf(points[i]);
        final newY = size.height - (cur / maxScore) * (size.height - 4);
        path.lineTo(x, newY);
        prev = cur;
      }
      canvas.drawPath(path, paint);
    }

    drawStepLine(MH.them, (p) => p.scoreE1);
    drawStepLine(MH.us, (p) => p.scoreE2);
  }

  @override
  bool shouldRepaint(_ScoreChartPainter old) => old.points != points;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rally bar (stacked E1|E2)
// ─────────────────────────────────────────────────────────────────────────────

class _RallyBar extends StatelessWidget {
  const _RallyBar({
    required this.label,
    required this.total,
    required this.maxTotal,
    required this.e1Ratio,
  });
  final String label;
  final int total;
  final int maxTotal;
  final double e1Ratio;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 80,
          child: Text(label, style: MH.mono()),
        ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            final barW = c.maxWidth * (total / maxTotal);
            final e1W = barW * e1Ratio;
            final e2W = barW * (1 - e1Ratio);
            return Stack(children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: MH.sand,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Row(children: [
                if (e1W > 0)
                  Container(
                    width: e1W,
                    height: 14,
                    decoration: BoxDecoration(
                      color: MH.them,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(3),
                        bottomLeft: const Radius.circular(3),
                        topRight: e2W < 1 ? const Radius.circular(3) : Radius.zero,
                        bottomRight: e2W < 1 ? const Radius.circular(3) : Radius.zero,
                      ),
                    ),
                  ),
                if (e2W > 0)
                  Container(
                    width: e2W,
                    height: 14,
                    decoration: BoxDecoration(
                      color: MH.us,
                      borderRadius: BorderRadius.only(
                        topRight: const Radius.circular(3),
                        bottomRight: const Radius.circular(3),
                        topLeft: e1W < 1 ? const Radius.circular(3) : Radius.zero,
                        bottomLeft: e1W < 1 ? const Radius.circular(3) : Radius.zero,
                      ),
                    ),
                  ),
              ]),
            ]);
          }),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text('$total pts', style: MH.mono(), textAlign: TextAlign.right),
        ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: MH.mono(
                  size: 9, weight: FontWeight.w700, letterSpacing: 1.2)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: MH.sans(size: 10, color: MH.pencil, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      );
}

class _Row3 extends StatelessWidget {
  const _Row3(this.left, this.center, this.right,
      {this.leftBold = false, this.rightBold = false});
  final String left;
  final String center;
  final String right;
  final bool leftBold;
  final bool rightBold;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(left,
              textAlign: TextAlign.center,
              style: MH.mono(
                size: 13,
                weight: leftBold ? FontWeight.w700 : FontWeight.w500,
                color: leftBold ? MH.them : MH.inkSoft,
              )),
        ),
        SizedBox(
          width: 120,
          child: Text(center,
              textAlign: TextAlign.center,
              style: MH.sans(size: 11, color: MH.pencil)),
        ),
        Expanded(
          child: Text(right,
              textAlign: TextAlign.center,
              style: MH.mono(
                size: 13,
                weight: rightBold ? FontWeight.w700 : FontWeight.w500,
                color: rightBold ? MH.us : MH.inkSoft,
              )),
        ),
      ]);
}

class _BarStat extends StatelessWidget {
  const _BarStat({
    required this.label,
    required this.count,
    required this.rate,
    required this.color,
  });
  final String label;
  final String count;
  final double rate;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: MH.sans(size: 10, color: MH.pencil)),
          const SizedBox(height: 5),
          LayoutBuilder(builder: (ctx, c) {
            return Stack(children: [
              Container(
                  height: 8,
                  decoration: BoxDecoration(
                      color: MH.sand, borderRadius: BorderRadius.circular(3))),
              Container(
                  width: c.maxWidth * rate.clamp(0.0, 1.0),
                  height: 8,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(3))),
            ]);
          }),
          const SizedBox(height: 4),
          Text('$count  (${(rate * 100).round()}%)',
              style: MH.mono(size: 9, color: MH.inkSoft)),
        ],
      );
}

class _LabeledBar extends StatelessWidget {
  const _LabeledBar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
    this.winRatio,
  });
  final String label;
  final String value;
  final double ratio;
  final Color color;
  final double? winRatio;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: MH.sans(size: 12, color: MH.inkSoft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (ctx, c) {
              final barW = c.maxWidth * ratio.clamp(0.0, 1.0);
              final fillW = winRatio != null ? barW * winRatio! : barW;
              return Stack(children: [
                Container(
                    height: 10,
                    decoration: BoxDecoration(
                        color: MH.sand, borderRadius: BorderRadius.circular(3))),
                if (barW > 0)
                  Container(
                      width: barW,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3))),
                if (fillW > 0)
                  Container(
                      width: fillW,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(3))),
              ]);
            }),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Text(value,
                style: MH.mono(size: 9), textAlign: TextAlign.right),
          ),
        ],
      );
}
