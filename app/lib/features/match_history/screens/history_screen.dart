import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match_history/domain/date_format.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:app/features/match_history/screens/match_replay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final archives = ref.watch(archiveListProvider);
    final filtered = _query.isEmpty
        ? archives
        : archives.where((a) => _matches(a, _query)).toList();

    return Scaffold(
      backgroundColor: MH.paper,
      appBar: AppBar(
        backgroundColor: MH.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MH.ink,
        elevation: 0,
        title: Text(
          'Historique',
          style: MH.sans(size: 18, weight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _SearchBar(
            controller: _searchCtrl,
            onChanged: (q) => setState(() => _query = q),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? _EmptyState(hasQuery: _query.isNotEmpty)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => _MatchCard(archive: filtered[i]),
            ),
    );
  }

  bool _matches(MatchArchive a, String q) {
    final lower = _normalize(q);
    final e1 = a.state.teams[TeamSide.e1]!;
    final e2 = a.state.teams[TeamSide.e2]!;
    if (_normalize(e1.name).contains(lower)) return true;
    if (_normalize(e2.name).contains(lower)) return true;
    for (final p in [...e1.players, ...e2.players]) {
      if (_normalize(p.name).contains(lower)) return true;
    }
    return false;
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('î', 'i')
      .replaceAll('ô', 'o')
      .replaceAll("'", ' ');
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        color: MH.paper,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: MH.sans(),
          decoration: InputDecoration(
            hintText: 'Rechercher équipe ou joueur…',
            hintStyle: MH.sans(color: MH.pencil),
            prefixIcon: const Icon(Icons.search, size: 20, color: MH.pencil),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: MH.pencil),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: MH.sand,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasQuery ? Icons.search_off : Icons.history,
                size: 48,
                color: MH.rule,
              ),
              const SizedBox(height: 16),
              Text(
                hasQuery ? 'Aucun résultat' : 'Aucun match archivé',
                style: MH.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: MH.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasQuery
                    ? "Essayez un autre nom de joueur ou d'équipe"
                    : 'Les matchs terminés apparaîtront ici',
                textAlign: TextAlign.center,
                style: MH.sans(size: 13, color: MH.pencil),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Match card
// ---------------------------------------------------------------------------

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.archive});
  final MatchArchive archive;

  @override
  Widget build(BuildContext context) {
    final state = archive.state;
    final e1 = state.teams[TeamSide.e1]!;
    final e2 = state.teams[TeamSide.e2]!;
    final setsE1 = state.setsWonOf(TeamSide.e1);
    final setsE2 = state.setsWonOf(TeamSide.e2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: MH.paper,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MatchReplayScreen(archive: archive),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: MH.rule, width: 1.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      formatMatchDate(archive.startedAt),
                      style: MH.mono(),
                    ),
                    const Spacer(),
                    Text(
                      'REPLAY',
                      style: MH.sans(
                        size: 9,
                        weight: FontWeight.w700,
                        color: MH.ball,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.play_circle_outline,
                        size: 14, color: MH.ball),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _TeamBlock(team: e1, side: TeamSide.e1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$setsE1 – $setsE2',
                            style: MH.mono(
                              size: 22,
                              weight: FontWeight.w800,
                              color: MH.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _setScores(state),
                            style: MH.mono(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _TeamBlock(
                        team: e2,
                        side: TeamSide.e2,
                        rightAlign: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${state.history.length} échanges',
                      style: MH.mono(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _setScores(MatchState s) =>
      s.sets.map((r) => '${r.scoreE1}–${r.scoreE2}').join('  ·  ');
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.team,
    required this.side,
    this.rightAlign = false,
  });
  final Team team;
  final TeamSide side;
  final bool rightAlign;

  @override
  Widget build(BuildContext context) {
    final color = side == TeamSide.e1 ? MH.them : MH.us;
    final playerNames = team.players.map((p) => p.name).join(' · ');
    return Row(
      mainAxisAlignment:
          rightAlign ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: rightAlign
          ? [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      team.name,
                      textAlign: TextAlign.end,
                      style: MH.sans(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playerNames,
                      textAlign: TextAlign.end,
                      style: MH.sans(size: 11, color: MH.pencil),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 4, height: 36, color: color),
            ]
          : [
              Container(width: 4, height: 36, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: MH.sans(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playerNames,
                      style: MH.sans(size: 11, color: MH.pencil),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
    );
  }
}
