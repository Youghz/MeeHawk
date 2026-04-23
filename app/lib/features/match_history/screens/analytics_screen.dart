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
  TeamSide _selectedTeam = TeamSide.e1;
  String? _filterPlayerId;

  MatchState get _s => widget.state;
  Team get _team => _s.teams[_selectedTeam]!;
  Color get _color => _selectedTeam == TeamSide.e1 ? MH.them : MH.us;

  List<PointRecord> get _pts => _filterSet == null
      ? _s.history
      : _s.history.where((p) => p.setNumber == _filterSet).toList();

  List<int> get _sets => _s.sets.map((s) => s.setNumber).toList()..sort();

  /// Set-filtered points narrowed to those where the selected player had an
  /// annotation. Used by action-type and zone sections.
  List<PointRecord> get _ptsForPlayer {
    if (_filterPlayerId == null) return _pts;
    final player = _team.players.firstWhere(
      (p) => p.id == _filterPlayerId,
      orElse: () => const Player(id: '', name: ''),
    );
    if (player.id.isEmpty) return _pts;
    return _pts
        .where((pt) => pt.annotations.any((a) => a.text.contains(player.name)))
        .toList();
  }

  /// Reconstructs serving player per point (set-filtered).
  List<({PointRecord pt, TeamSide server, String serverId})>
      get _ptsWithServer {
    var serverId = _s.initialServerId;
    final result =
        <({PointRecord pt, TeamSide server, String serverId})>[];
    for (final p in _s.history) {
      final team = _s.teamOfPlayer(serverId) ?? TeamSide.e1;
      if (_filterSet == null || p.setNumber == _filterSet) {
        result.add((pt: p, server: team, serverId: serverId));
      }
      serverId = p.serverId;
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _teamRow(),
          _playerRow(),
          const Divider(height: 1, color: MH.rule),
          Expanded(
            child: _pts.isEmpty
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
                      _rallyLength(),
                      _sep(),
                      _keyMoments(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Team / player selectors (sticky header)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _teamRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            Expanded(child: _teamChip(TeamSide.e1)),
            const SizedBox(width: 8),
            Expanded(child: _teamChip(TeamSide.e2)),
          ],
        ),
      );

  Widget _teamChip(TeamSide side) {
    final team = _s.teams[side]!;
    final color = side == TeamSide.e1 ? MH.them : MH.us;
    final active = _selectedTeam == side;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTeam = side;
        _filterPlayerId = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border.all(color: color, width: 1.5)
              : Border.all(color: MH.rule),
        ),
        alignment: Alignment.center,
        child: Text(
          team.name,
          style: MH.sans(
            size: 13,
            weight: FontWeight.w700,
            color: active ? color : MH.pencil,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _playerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Row(
          children: [
            _playerChip(null, 'Tous'),
            for (final p in _team.players)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _playerChip(p.id, p.name),
              ),
          ],
        ),
      );

  Widget _playerChip(String? id, String label) {
    final active = _filterPlayerId == id;
    return GestureDetector(
      onTap: () =>
          setState(() => _filterPlayerId = active && id != null ? null : id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _color : MH.rule),
        ),
        child: Text(
          label,
          style: MH.sans(
            size: 11,
            weight: FontWeight.w600,
            color: active ? _color : MH.pencil,
          ),
        ),
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
    if (pts.isEmpty) return const SizedBox.shrink();

    final pairs = _ptsWithServer;
    final myWins = pts.where((p) => p.winner == _selectedTeam).length;

    final setsToShow = _filterSet != null
        ? _s.sets.where((s) => s.setNumber == _filterSet).toList()
        : _s.sets;
    final setsWon =
        setsToShow.where((s) => s.winner == _selectedTeam).length;

    final myServes =
        pairs.where((p) => p.server == _selectedTeam).toList();
    final myRecv =
        pairs.where((p) => p.server != _selectedTeam).toList();
    final myServeWins =
        myServes.where((p) => p.pt.winner == _selectedTeam).length;
    final myRecvWins =
        myRecv.where((p) => p.pt.winner == _selectedTeam).length;

    return _Section(
      title: 'RÉSUMÉ',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 14, color: _color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _team.name,
              style: MH.sans(weight: FontWeight.w700, color: _color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'vs ${_s.teams[_selectedTeam.other]!.name}',
            style: MH.sans(size: 11, color: MH.pencil),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
        const SizedBox(height: 14),
        if (_filterSet == null && setsToShow.isNotEmpty) ...[
          _BarStat(
            label: 'Sets gagnés',
            count: '$setsWon/${setsToShow.length}',
            rate: setsWon / setsToShow.length,
            color: _color,
          ),
          const SizedBox(height: 12),
        ],
        _BarStat(
          label: 'Points gagnés',
          count: '$myWins/${pts.length}',
          rate: pts.isNotEmpty ? myWins / pts.length : 0,
          color: _color,
        ),
        const SizedBox(height: 12),
        _BarStat(
          label: 'Au service',
          count: '$myServeWins/${myServes.length}',
          rate: myServes.isNotEmpty ? myServeWins / myServes.length : 0,
          color: _color,
        ),
        const SizedBox(height: 12),
        _BarStat(
          label: 'À la réception',
          count: '$myRecvWins/${myRecv.length}',
          rate: myRecv.isNotEmpty ? myRecvWins / myRecv.length : 0,
          color: _color.withValues(alpha: 0.5),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICE EFFICIENCY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _serviceEfficiency() {
    final pairs = _ptsWithServer;
    if (pairs.isEmpty) return const SizedBox.shrink();

    // Apply player filter to service side.
    final myServes = pairs.where((p) {
      if (p.server != _selectedTeam) return false;
      if (_filterPlayerId != null && p.serverId != _filterPlayerId) return false;
      return true;
    }).toList();

    if (myServes.isEmpty) return const SizedBox.shrink();

    final serveWins =
        myServes.where((p) => p.pt.winner == _selectedTeam).length;
    final serveRate = serveWins / myServes.length;

    final players = _team.players;

    return _Section(
      title: 'EFFICACITÉ AU SERVICE',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _BarStat(
          label: _filterPlayerId != null ? _playerName() : 'Total équipe',
          count: '$serveWins/${myServes.length}',
          rate: serveRate,
          color: _color,
        ),
        // Per-player breakdown when showing full team.
        if (_filterPlayerId == null && players.length > 1) ...[
          const SizedBox(height: 12),
          for (final player in players) ...[
            Builder(builder: (_) {
              final ps = pairs
                  .where((p) =>
                      p.server == _selectedTeam && p.serverId == player.id)
                  .toList();
              if (ps.isEmpty) return const SizedBox.shrink();
              final w = ps.where((p) => p.pt.winner == _selectedTeam).length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BarStat(
                  label: player.name,
                  count: '$w/${ps.length}',
                  rate: w / ps.length,
                  color: _color.withValues(alpha: 0.55),
                ),
              );
            }),
          ],
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICE LANDING ZONES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _serviceZones() {
    final pairs = _ptsWithServer;
    final dots = <_Dot>[];

    for (final (:pt, :server, :serverId) in pairs) {
      if (server != _selectedTeam) continue;
      if (_filterPlayerId != null && serverId != _filterPlayerId) continue;

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

      dots.add(_Dot(
        x: landing.x,
        y: landing.y,
        color: _color,
        hollow: pt.winner != _selectedTeam,
      ));
    }

    if (dots.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'ZONES DE SERVICE',
      subtitle: 'Réception — plein = point gagné · cercle = point perdu',
      child: _AnalyticsCourt(dots: dots),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATTACK ZONES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _attackZones() {
    final pts = _ptsForPlayer;
    final dots = <_Dot>[];
    final opponent = _selectedTeam.other;

    for (final p in pts) {
      // Last impact on opponent's side = our team's last attack.
      BallImpact? attackLanding;
      for (final imp in p.impacts.reversed) {
        if (imp.isServerPosition) continue;
        if (imp.teamSide == opponent) {
          attackLanding = imp;
          break;
        }
      }
      if (attackLanding == null) continue;

      dots.add(_Dot(
        x: attackLanding.x,
        y: attackLanding.y,
        color: _color,
        hollow: attackLanding.isOutside || p.winner != _selectedTeam,
      ));
    }

    if (dots.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: "ZONES D'ATTAQUE",
      subtitle: 'Dernière frappe — plein = point gagné · cercle = faute / repoussé',
      child: _AnalyticsCourt(dots: dots),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION TYPES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _actionTypes() {
    final pts = _ptsForPlayer;
    if (pts.isEmpty) return const SizedBox.shrink();

    // Last annotation belonging to the selected team per point.
    final endings = <String, ({int total, int wins})>{};
    final attackSubs = <String, ({int total, int wins})>{};

    for (final p in pts) {
      Annotation? last;
      for (final a in p.annotations.reversed) {
        if (a.team == _selectedTeam) {
          last = a;
          break;
        }
      }
      if (last == null) continue;

      final won = p.winner == _selectedTeam;
      final prev = endings[last.type] ?? (total: 0, wins: 0);
      endings[last.type] =
          (total: prev.total + 1, wins: prev.wins + (won ? 1 : 0));

      if (last.type == 'attack') {
        final sub = _subtype(last.text);
        if (sub != null && sub.isNotEmpty) {
          final prevSub = attackSubs[sub] ?? (total: 0, wins: 0);
          attackSubs[sub] = (
            total: prevSub.total + 1,
            wins: prevSub.wins + (won ? 1 : 0),
          );
        }
      }
    }

    if (endings.isEmpty) return const SizedBox.shrink();

    const typeLabels = {
      'attack': 'Attaque',
      'block': 'Bloc',
      'fault': 'Faute adverse',
      'service': 'Ace / direct',
    };
    const typeColors = {
      'attack': MH.ink,
      'block': MH.ball,
      'fault': MH.mid,
      'service': MH.pencil,
    };

    final grandTotal =
        endings.values.map((v) => v.total).reduce((a, b) => a + b);
    final sorted = endings.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    final subMaxTotal = attackSubs.isEmpty
        ? 1
        : attackSubs.values.map((v) => v.total).reduce(max);
    final subSorted = attackSubs.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return _Section(
      title: 'COMMENT FINISSENT LES POINTS',
      subtitle: 'Dernière action de ${_team.name} — barre pleine = gagné',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in sorted) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LabeledBar(
              label: typeLabels[e.key] ?? e.key,
              value:
                  '${e.value.wins}/${e.value.total}  ${(e.value.total / grandTotal * 100).round()}%',
              ratio: e.value.total / grandTotal,
              color: typeColors[e.key] ?? MH.pencil,
              winRatio:
                  e.value.total > 0 ? e.value.wins / e.value.total : 0,
            ),
          ),
        ],
        if (subSorted.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Détail attaques',
              style: MH.mono(size: 9, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          for (final e in subSorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LabeledBar(
                label: _cap(e.key),
                value:
                    '${e.value.wins}/${e.value.total}  ${(e.value.total / subMaxTotal * 100).round()}%',
                ratio: e.value.total / subMaxTotal,
                color: MH.ink,
                winRatio:
                    e.value.total > 0 ? e.value.wins / e.value.total : 0,
              ),
            ),
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RALLY LENGTH
  // ─────────────────────────────────────────────────────────────────────────

  Widget _rallyLength() {
    final pairs = _ptsWithServer;
    if (pairs.isEmpty) return const SizedBox.shrink();

    // serveW/serveT: when team served; recvW/recvT: when team received.
    final data =
        <int, ({int serveW, int serveT, int recvW, int recvT})>{};

    for (final (:pt, :server, :serverId) in pairs) {
      // Player filter only on service side (can't track who received).
      if (_filterPlayerId != null &&
          server == _selectedTeam &&
          serverId != _filterPlayerId) {
        continue;
      }

      final ex = _exchanges(pt);
      final isServing = server == _selectedTeam;
      final won = pt.winner == _selectedTeam;
      final prev = data[ex] ?? (serveW: 0, serveT: 0, recvW: 0, recvT: 0);

      data[ex] = isServing
          ? (
              serveW: prev.serveW + (won ? 1 : 0),
              serveT: prev.serveT + 1,
              recvW: prev.recvW,
              recvT: prev.recvT,
            )
          : (
              serveW: prev.serveW,
              serveT: prev.serveT,
              recvW: prev.recvW + (won ? 1 : 0),
              recvT: prev.recvT + 1,
            );
    }

    if (data.isEmpty) return const SizedBox.shrink();

    const labels = {
      0: 'Direct',
      1: '1 échange',
      2: '2 échanges',
      3: '3 échanges',
      4: '4+ échanges',
    };

    final sorted = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return _Section(
      title: 'LONGUEUR DES ÉCHANGES',
      child: Column(children: [
        for (final e in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _RallyRow(
              label: labels[e.key] ?? '${e.key}+ échanges',
              color: _color,
              serveWins: e.value.serveW,
              serveTotal: e.value.serveT,
              recvWins: e.value.recvW,
              recvTotal: e.value.recvT,
            ),
          ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KEY MOMENTS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _keyMoments() {
    final pts = _pts;
    if (pts.isEmpty) return const SizedBox.shrink();

    final streak = _maxStreak(pts, _selectedTeam);

    var maxLead = 0;
    for (final p in pts) {
      final lead = p.scoreOf(_selectedTeam) - p.scoreOf(_selectedTeam.other);
      if (lead > maxLead) maxLead = lead;
    }

    final pressurePts = pts
        .where((p) =>
            p.scoreOf(_selectedTeam) >= 15 ||
            p.scoreOf(_selectedTeam.other) >= 15)
        .toList();
    final pressWins =
        pressurePts.where((p) => p.winner == _selectedTeam).length;

    final decPts = pts
        .where((p) =>
            p.scoreOf(_selectedTeam) >= 18 ||
            p.scoreOf(_selectedTeam.other) >= 18)
        .toList();
    final decWins = decPts.where((p) => p.winner == _selectedTeam).length;

    final first5 = pts.take(min(5, pts.length)).toList();
    final f5Wins = first5.where((p) => p.winner == _selectedTeam).length;

    return _Section(
      title: 'MOMENTS DÉCISIFS',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _KeyRow(label: 'Série max consécutive', value: '$streak pts'),
        const SizedBox(height: 8),
        _KeyRow(label: 'Avance maximale', value: '+$maxLead pts'),
        const SizedBox(height: 12),
        if (pressurePts.isNotEmpty) ...[
          _BarStat(
            label: 'Points ≥ 15 (pression)',
            count: '$pressWins/${pressurePts.length}',
            rate: pressWins / pressurePts.length,
            color: _color,
          ),
          const SizedBox(height: 12),
        ],
        if (decPts.isNotEmpty) ...[
          _BarStat(
            label: 'Points ≥ 18 (tension)',
            count: '$decWins/${decPts.length}',
            rate: decWins / decPts.length,
            color: _color,
          ),
          const SizedBox(height: 12),
        ],
        _BarStat(
          label: '5 premiers points',
          count: '$f5Wins/${first5.length}',
          rate: first5.isNotEmpty ? f5Wins / first5.length : 0,
          color: _color,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pure helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Exchanges = net crossings minus the service crossing (capped at 4).
  /// netCrossings 0-1 → 0 exchanges (ace / service fault / direct point).
  int _exchanges(PointRecord p) {
    final nc = p.netCrossings;
    if (nc <= 1) return 0;
    return min(nc - 1, 4);
  }

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

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _playerName() {
    if (_filterPlayerId == null) return '';
    return _team.players
        .firstWhere(
          (p) => p.id == _filterPlayerId,
          orElse: () => const Player(id: '', name: ''),
        )
        .name;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set filter chips
// ─────────────────────────────────────────────────────────────────────────────

class _SetFilter extends StatelessWidget {
  const _SetFilter(
      {required this.sets, required this.selected, required this.onSelect});
  final List<int> sets;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        color: MH.paper,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          _Chip(
              label: 'Tout',
              active: selected == null,
              onTap: () => onSelect(null)),
          for (final s in sets)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _Chip(
                label: 'Set $s',
                active: selected == s,
                onTap: () => onSelect(selected == s ? null : s),
              ),
            ),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
  const _Dot(
      {required this.x,
      required this.y,
      required this.color,
      this.hollow = false});
  final double x;
  final double y;
  final Color color;
  final bool hollow;
}

class _AnalyticsCourt extends StatelessWidget {
  const _AnalyticsCourt({required this.dots});
  final List<_Dot> dots;

  static const _m = 30.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = (w - _m * 2) / 2 + _m * 2;
          return SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              const Positioned.fill(
                  child: CustomPaint(painter: _CourtBgPainter(_m))),
              for (final d in dots)
                Positioned(
                  left: d.x * w - 5,
                  top: d.y * h - 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.hollow
                          ? Colors.transparent
                          : d.color.withValues(alpha: 0.8),
                      border: d.hollow
                          ? Border.all(color: d.color, width: 1.5)
                          : null,
                    ),
                  ),
                ),
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
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = MH.ruleSoft)
      ..drawRect(inner, Paint()..color = MH.sand)
      ..drawLine(
        Offset(size.width / 2, margin),
        Offset(size.width / 2, size.height - margin),
        Paint()
          ..color = MH.pencil
          ..strokeWidth = 1.5,
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

// ─────────────────────────────────────────────────────────────────────────────
// Rally length: two mini-bars per bucket (service / réception)
// ─────────────────────────────────────────────────────────────────────────────

class _RallyRow extends StatelessWidget {
  const _RallyRow({
    required this.label,
    required this.color,
    required this.serveWins,
    required this.serveTotal,
    required this.recvWins,
    required this.recvTotal,
  });
  final String label;
  final Color color;
  final int serveWins;
  final int serveTotal;
  final int recvWins;
  final int recvTotal;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: MH.mono(weight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (serveTotal > 0)
            _MiniBar(
              icon: Icons.arrow_upward_rounded,
              label: 'Service',
              wins: serveWins,
              total: serveTotal,
              color: color,
            ),
          if (serveTotal > 0 && recvTotal > 0) const SizedBox(height: 4),
          if (recvTotal > 0)
            _MiniBar(
              icon: Icons.arrow_downward_rounded,
              label: 'Réception',
              wins: recvWins,
              total: recvTotal,
              color: color.withValues(alpha: 0.5),
            ),
        ],
      );
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.icon,
    required this.label,
    required this.wins,
    required this.total,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int wins;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rate = total > 0 ? wins / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Row(
            children: [
              Icon(icon, size: 10, color: MH.pencil),
              const SizedBox(width: 4),
              Text(label, style: MH.sans(size: 10, color: MH.pencil)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            return Stack(children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: MH.sand,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                width: c.maxWidth * rate.clamp(0.0, 1.0),
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 68,
          child: Text(
            '$wins/$total  ${(rate * 100).round()}%',
            style: MH.mono(size: 9, color: MH.inkSoft),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
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
                style: MH.sans(
                    size: 10,
                    color: MH.pencil,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      );
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(label,
                style: MH.sans(size: 12, color: MH.inkSoft)),
          ),
          Text(value,
              style: MH.mono(size: 13, weight: FontWeight.w600)),
        ],
      );
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
                      color: MH.sand,
                      borderRadius: BorderRadius.circular(3))),
              Container(
                  width: c.maxWidth * rate.clamp(0.0, 1.0),
                  height: 8,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3))),
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
                        color: MH.sand,
                        borderRadius: BorderRadius.circular(3))),
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
                          color: color,
                          borderRadius: BorderRadius.circular(3))),
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
