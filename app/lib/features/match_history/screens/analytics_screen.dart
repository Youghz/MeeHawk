import 'package:app/core/theme.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/domain/rules/rally_analyzer.dart';
import 'package:app/features/match_history/screens/analytics/analytics_input.dart';
import 'package:app/features/match_history/screens/analytics/widgets/advice.dart';
import 'package:app/features/match_history/screens/analytics/widgets/analytics_primitives.dart';
import 'package:app/features/match_history/screens/analytics/widgets/attack_endings.dart';
import 'package:app/features/match_history/screens/analytics/widgets/rally_length.dart';
import 'package:app/features/match_history/screens/analytics/widgets/reception_zones.dart';
import 'package:app/features/match_history/screens/analytics/widgets/service_zones.dart';
import 'package:app/features/match_history/screens/analytics/widgets/summary.dart';
import 'package:app/features/match_history/services/pdf_exporter.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

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
  bool _isExporting = false;

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
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: MH.pencil),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              tooltip: 'Exporter en PDF',
              onPressed:
                  input.pts.isEmpty ? null : () => _exportPdf(input),
            ),
        ],
        bottom: hasSets
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: AnalyticsSetFilter(
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
                      AnalyticsSection(
                          title: 'RÉSUMÉ',
                          child: AnalyticsSummary(input)),
                      _sep,
                      AnalyticsSection(
                          title: 'ÉCHANGES',
                          child: RallyLengthSection(input)),
                      _sep,
                      AnalyticsSection(
                          title: 'ZONES DE SERVICE',
                          child: ServiceZonesSection(input)),
                      _sep,
                      AnalyticsSection(
                          title: 'ZONES DE RÉCEPTION',
                          child: ReceptionZonesSection(input)),
                      _sep,
                      AnalyticsSection(
                          title: 'ATTAQUE & FIN DE RALLYE',
                          subtitle: '● Gagné   ● Perdu / faute   ← Filet',
                          child: AttackEndingsSection(input)),
                      _sep,
                      AnalyticsSection(
                          title: 'CONSEILS',
                          child: AdviceSection(input)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  AnalyticsInput _buildInput() {
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

    var sumUs = 0.0;
    var sumThem = 0.0;
    for (final p in pts) {
      final m = RallyAnalyzer.averageTouchesPerVisit(p.impacts);
      sumUs += m[_selectedTeam] ?? 0;
      sumThem += m[_selectedTeam.other] ?? 0;
    }
    final avgTouchesUs = pts.isEmpty ? 0.0 : sumUs / pts.length;
    final avgTouchesThem = pts.isEmpty ? 0.0 : sumThem / pts.length;

    return AnalyticsInput(
      pts: pts,
      ptsWithServer: ptsWithServer,
      ptsForPlayer: ptsForPlayer,
      selectedTeam: _selectedTeam,
      otherTeamName: _s.teams[_selectedTeam.other]!.name,
      team: team,
      color: color,
      filterPlayerId: _filterPlayerId,
      filterSetNumber: _filterSet,
      avgTouchesUs: avgTouchesUs,
      avgTouchesThem: avgTouchesThem,
    );
  }

  Future<void> _exportPdf(AnalyticsInput input) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await generateAnalyticsPdf(input);
      final name = 'Analyse_${input.team.name.replaceAll(' ', '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _filterBar(AnalyticsInput input) => SingleChildScrollView(
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

  Widget _teamToggleChip(TeamSide side, AnalyticsInput input) {
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

  Widget _playerChip(String? id, String label, AnalyticsInput input) {
    final active = input.filterPlayerId == id;
    return GestureDetector(
      onTap: () =>
          setState(() => _filterPlayerId = active && id != null ? null : id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? input.color.withValues(alpha: 0.12)
              : Colors.transparent,
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
