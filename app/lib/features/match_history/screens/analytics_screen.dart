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
  List<int> get _sets => _s.sets.map((s) => s.setNumber).toList()..sort();

  static const _sep = Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Divider(height: 32, color: MH.rule),
  );

  @override
  Widget build(BuildContext context) {
    final hasSets = _sets.length > 1;
    final input = _buildInput();
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
          _filterBar(input),
          const Divider(height: 1, color: MH.rule),
          Expanded(
            child: input.pts.isEmpty
                ? Center(
                    child: Text(
                      'Aucun point enregistré',
                      style: MH.sans(color: MH.pencil),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                    children: [
                      _Summary(input),
                      _sep,
                      _ServiceZones(input),
                      _sep,
                      _AttackZones(input),
                      _sep,
                      _ActionTypes(input),
                      _sep,
                      _RallyLength(input),
                      _sep,
                      _KeyMoments(input),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds pre-computed analytics data for this render pass.
  /// The server history scan is expensive; computing it here ensures it runs once.
  _AnalyticsInput _buildInput() {
    final team = _s.teams[_selectedTeam]!;
    final color = _selectedTeam == TeamSide.e1 ? MH.them : MH.us;

    final pts = _filterSet == null
        ? _s.history
        : _s.history.where((p) => p.setNumber == _filterSet).toList();

    var serverId = _s.initialServerId;
    final ptsWithServer =
        <({PointRecord pt, TeamSide server, String serverId})>[];
    for (final p in _s.history) {
      final srv = _s.teamOfPlayer(serverId) ?? TeamSide.e1;
      if (_filterSet == null || p.setNumber == _filterSet) {
        ptsWithServer.add((pt: p, server: srv, serverId: serverId));
      }
      serverId = p.serverId;
    }

    final filteredPlayer = _filterPlayerId == null
        ? null
        : team.players.firstWhere(
            (p) => p.id == _filterPlayerId,
            orElse: () => const Player(id: '', name: ''),
          );
    final ptsForPlayer = filteredPlayer == null || filteredPlayer.id.isEmpty
        ? pts
        : pts
            .where((pt) =>
                pt.annotations.any((a) => a.text.contains(filteredPlayer.name)))
            .toList();

    return _AnalyticsInput(
      pts: pts,
      ptsWithServer: ptsWithServer,
      ptsForPlayer: ptsForPlayer,
      selectedTeam: _selectedTeam,
      otherTeamName: _s.teams[_selectedTeam.other]!.name,
      team: team,
      color: color,
      filterPlayerId: _filterPlayerId,
    );
  }

  // ── Filter bar (teams + players, single horizontal row) ───────────────────

  Widget _filterBar(_AnalyticsInput input) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            _teamToggleChip(TeamSide.e1, input),
            const SizedBox(width: 6),
            _teamToggleChip(TeamSide.e2, input),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: MH.rule,
            ),
            _playerChip(null, 'Tous', input),
            for (final p in input.team.players) ...[
              const SizedBox(width: 6),
              _playerChip(p.id, p.name, input),
            ],
          ],
        ),
      );

  Widget _teamToggleChip(TeamSide side, _AnalyticsInput input) {
    final team = _s.teams[side]!;
    final color = side == TeamSide.e1 ? MH.them : MH.us;
    final active = input.selectedTeam == side;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTeam = side;
        _filterPlayerId = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : MH.rule,
            width: active ? 1.5 : 1,
          ),
        ),
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

  Widget _playerChip(String? id, String label, _AnalyticsInput input) {
    final active = input.filterPlayerId == id;
    return GestureDetector(
      onTap: () =>
          setState(() => _filterPlayerId = active && id != null ? null : id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              active ? input.color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? input.color : MH.rule,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: MH.sans(
            size: 12,
            weight: FontWeight.w600,
            color: active ? input.color : MH.pencil,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-computed analytics data (built once per render pass)
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsInput {
  const _AnalyticsInput({
    required this.pts,
    required this.ptsWithServer,
    required this.ptsForPlayer,
    required this.selectedTeam,
    required this.otherTeamName,
    required this.team,
    required this.color,
    required this.filterPlayerId,
  });

  final List<PointRecord> pts;
  final List<({PointRecord pt, TeamSide server, String serverId})> ptsWithServer;
  final List<PointRecord> ptsForPlayer;
  final TeamSide selectedTeam;
  final String otherTeamName;
  final Team team;
  final Color color;
  final String? filterPlayerId;
}

// ─────────────────────────────────────────────────────────────────────────────
// Section widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary(this.input);
  final _AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final pts = input.pts;
    if (pts.isEmpty) return const SizedBox.shrink();

    final pairs = input.ptsWithServer;
    final myWins = pts.where((p) => p.winner == input.selectedTeam).length;

    final myServes =
        pairs.where((p) => p.server == input.selectedTeam).toList();
    final myRecv =
        pairs.where((p) => p.server != input.selectedTeam).toList();
    final myServeWins =
        myServes.where((p) => p.pt.winner == input.selectedTeam).length;
    final myRecvWins =
        myRecv.where((p) => p.pt.winner == input.selectedTeam).length;

    // Per-player service breakdown
    final players = input.team.players;
    final showPlayerBreakdown =
        input.filterPlayerId == null && players.length > 1 && myServes.isNotEmpty;

    return _Section(
      title: 'RÉSUMÉ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 14, color: input.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                input.team.name,
                style: MH.sans(weight: FontWeight.w700, color: input.color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'vs ${input.otherTeamName}',
              style: MH.sans(size: 11, color: MH.pencil),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RingStat(
                  label: 'Points',
                  count: '$myWins/${pts.length}',
                  rate: pts.isNotEmpty ? myWins / pts.length : 0,
                  color: input.color,
                ),
              ),
              Expanded(
                child: _RingStat(
                  label: 'Service',
                  count: '$myServeWins/${myServes.length}',
                  rate:
                      myServes.isNotEmpty ? myServeWins / myServes.length : 0,
                  color: input.color,
                ),
              ),
              Expanded(
                child: _RingStat(
                  label: 'Réception',
                  count: '$myRecvWins/${myRecv.length}',
                  rate: myRecv.isNotEmpty ? myRecvWins / myRecv.length : 0,
                  color: input.color.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (showPlayerBreakdown) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: MH.rule),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final player in players)
                  Expanded(
                    child: Builder(builder: (_) {
                      final ps = pairs
                          .where((p) =>
                              p.server == input.selectedTeam &&
                              p.serverId == player.id)
                          .toList();
                      if (ps.isEmpty) return const SizedBox.shrink();
                      final w = ps
                          .where((p) => p.pt.winner == input.selectedTeam)
                          .length;
                      return _RingStat(
                        label: '${player.name} (serv.)',
                        count: '$w/${ps.length}',
                        rate: w / ps.length,
                        color: input.color.withValues(alpha: 0.7),
                      );
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceZones extends StatelessWidget {
  const _ServiceZones(this.input);
  final _AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final dots = <_Dot>[];

    for (final (:pt, :server, :serverId) in input.ptsWithServer) {
      if (server != input.selectedTeam) continue;
      if (input.filterPlayerId != null && serverId != input.filterPlayerId) {
        continue;
      }

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
        x: _halfX(input.selectedTeam, landing.x),
        y: landing.y,
        won: pt.winner == input.selectedTeam,
      ));
    }

    if (dots.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'ZONES DE SERVICE',
      subtitle: '● Point gagné   ○ Point perdu   ← Filet',
      child: _AnalyticsCourt(dots: dots, halfCourt: true),
    );
  }
}

class _AttackZones extends StatelessWidget {
  const _AttackZones(this.input);
  final _AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final dots = <_Dot>[];
    final opponent = input.selectedTeam.other;

    for (final p in input.ptsForPlayer) {
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
        x: _halfX(input.selectedTeam, attackLanding.x),
        y: attackLanding.y,
        won: !attackLanding.isOutside && p.winner == input.selectedTeam,
      ));
    }

    if (dots.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: "ZONES D'ATTAQUE",
      subtitle: '● Point gagné   ○ Faute / repoussé   ← Filet',
      child: _AnalyticsCourt(dots: dots, halfCourt: true),
    );
  }
}

class _ActionTypes extends StatelessWidget {
  const _ActionTypes(this.input);
  final _AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final pts = input.ptsForPlayer;
    if (pts.isEmpty) return const SizedBox.shrink();

    final endings = <String, ({int total, int wins})>{};
    final attackSubs = <String, ({int total, int wins})>{};

    for (final p in pts) {
      Annotation? last;
      for (final a in p.annotations.reversed) {
        if (a.team == input.selectedTeam) {
          last = a;
          break;
        }
      }
      if (last == null) continue;

      final won = p.winner == input.selectedTeam;
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
      title: 'FIN DE RALLYE',
      subtitle: 'Dernière action de ${input.team.name} · barre pleine = gagné',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            Text(
              'Détail attaques',
              style: MH.mono(size: 9, letterSpacing: 0.8),
            ),
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
        ],
      ),
    );
  }
}

class _RallyLength extends StatelessWidget {
  const _RallyLength(this.input);
  final _AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final pairs = input.ptsWithServer;
    if (pairs.isEmpty) return const SizedBox.shrink();

    final data = <int, ({int serveW, int serveT, int recvW, int recvT})>{};

    for (final (:pt, :server, :serverId) in pairs) {
      if (input.filterPlayerId != null &&
          server == input.selectedTeam &&
          serverId != input.filterPlayerId) {
        continue;
      }

      final ex = _exchanges(pt);
      final isServing = server == input.selectedTeam;
      final won = pt.winner == input.selectedTeam;
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
      title: 'DURÉE DES ÉCHANGES',
      child: Column(
        children: [
          for (final e in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RallyRow(
                label: labels[e.key] ?? '${e.key}+ échanges',
                color: input.color,
                serveWins: e.value.serveW,
                serveTotal: e.value.serveT,
                recvWins: e.value.recvW,
                recvTotal: e.value.recvT,
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyMoments extends StatelessWidget {
  const _KeyMoments(this.input);
  final _AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final pts = input.pts;
    if (pts.isEmpty) return const SizedBox.shrink();

    final streak = _maxStreak(pts, input.selectedTeam);

    var maxLead = 0;
    for (final p in pts) {
      final lead =
          p.scoreOf(input.selectedTeam) - p.scoreOf(input.selectedTeam.other);
      if (lead > maxLead) maxLead = lead;
    }

    final pressurePts = pts
        .where((p) =>
            p.scoreOf(input.selectedTeam) >= 15 ||
            p.scoreOf(input.selectedTeam.other) >= 15)
        .toList();
    final pressWins =
        pressurePts.where((p) => p.winner == input.selectedTeam).length;

    final decPts = pts
        .where((p) =>
            p.scoreOf(input.selectedTeam) >= 18 ||
            p.scoreOf(input.selectedTeam.other) >= 18)
        .toList();
    final decWins = decPts.where((p) => p.winner == input.selectedTeam).length;

    final first5 = pts.take(min(5, pts.length)).toList();
    final f5Wins = first5.where((p) => p.winner == input.selectedTeam).length;

    return _Section(
      title: 'POINTS CLÉS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KeyRow(label: 'Série max consécutive', value: '$streak pts'),
          const SizedBox(height: 8),
          _KeyRow(label: 'Avance maximale', value: '+$maxLead pts'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pressurePts.isNotEmpty)
                Expanded(
                  child: _RingStat(
                    label: 'Points ≥ 15',
                    count: '$pressWins/${pressurePts.length}',
                    rate: pressWins / pressurePts.length,
                    color: input.color,
                  ),
                ),
              if (decPts.isNotEmpty)
                Expanded(
                  child: _RingStat(
                    label: 'Points ≥ 18',
                    count: '$decWins/${decPts.length}',
                    rate: decWins / decPts.length,
                    color: input.color,
                  ),
                ),
              Expanded(
                child: _RingStat(
                  label: '5 premiers',
                  count: '$f5Wins/${first5.length}',
                  rate: first5.isNotEmpty ? f5Wins / first5.length : 0,
                  color: input.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Exchanges = net crossings minus the service crossing (capped at 4).
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

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Maps a raw court x ∈ [0, 1] to a half-court x ∈ [0=net, 1=baseline].
/// The selected team's zone always lands on the opponent's half.
double _halfX(TeamSide selectedTeam, double x) {
  if (selectedTeam == TeamSide.e1) {
    return ((x - 0.5) * 2).clamp(0.0, 1.0);
  }
  return ((0.5 - x) * 2).clamp(0.0, 1.0);
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
  const _Dot({required this.x, required this.y, required this.won});
  final double x;
  final double y;
  final bool won;
}

class _AnalyticsCourt extends StatelessWidget {
  const _AnalyticsCourt({required this.dots, this.halfCourt = false});
  final List<_Dot> dots;
  final bool halfCourt;

  static const _m = 30.0;
  static const _mHalf = 20.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final m = halfCourt ? _mHalf : _m;
          final courtW = w - m * 2;
          // Half-court: 2:3 ratio (taller than square for better readability)
          final courtH = halfCourt ? courtW * 0.65 : courtW / 2;
          final h = courtH + m * 2;
          return SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                    painter: _CourtBgPainter(m, halfCourt: halfCourt)),
              ),
              for (final d in dots)
                Positioned(
                  left: m + d.x * courtW - 6,
                  top: m + d.y * courtH - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.won
                          ? MH.good.withValues(alpha: 0.85)
                          : Colors.transparent,
                      border: d.won
                          ? null
                          : Border.all(color: MH.bad, width: 1.5),
                    ),
                  ),
                ),
            ]),
          );
        },
      );
}

class _CourtBgPainter extends CustomPainter {
  const _CourtBgPainter(this.margin, {this.halfCourt = false});
  final double margin;
  final bool halfCourt;

  @override
  void paint(Canvas canvas, Size size) {
    final inner = Rect.fromLTWH(
        margin, margin, size.width - margin * 2, size.height - margin * 2);

    canvas
      ..drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = MH.ruleSoft)
      ..drawRect(inner, Paint()..color = MH.sand);

    if (!halfCourt) {
      canvas.drawLine(
        Offset(size.width / 2, margin),
        Offset(size.width / 2, size.height - margin),
        Paint()
          ..color = MH.pencil
          ..strokeWidth = 1.5,
      );
    } else {
      canvas.drawLine(
        Offset(margin, margin),
        Offset(margin, size.height - margin),
        Paint()
          ..color = MH.inkSoft
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawRect(
        inner,
        Paint()
          ..color = MH.rule
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_CourtBgPainter old) =>
      old.margin != margin || old.halfCourt != halfCourt;
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
          Text(label, style: MH.mono(weight: FontWeight.w600)),
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
            const SizedBox(height: 3),
            Text(subtitle!, style: MH.sans(size: 11, color: MH.pencil)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Ring stat (donut arc + %)
// ─────────────────────────────────────────────────────────────────────────────

class _RingStat extends StatelessWidget {
  const _RingStat({
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
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: _ArcPainter(rate: rate, color: color),
              child: Center(
                child: Text(
                  '${(rate * 100).round()}%',
                  style: MH.sans(
                      size: 13,
                      weight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: MH.sans(size: 10, color: MH.pencil),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(count,
              style: MH.mono(size: 9, color: MH.inkSoft),
              textAlign: TextAlign.center),
        ],
      );
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.rate, required this.color});
  final double rate;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide - 16) / 2;
    final bg = Paint()
      ..color = MH.sand
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), -pi / 2, pi * 2, false, bg);
    if (rate > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2,
          pi * 2 * rate.clamp(0.0, 1.0), false, fg);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.rate != rate || o.color != color;
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
