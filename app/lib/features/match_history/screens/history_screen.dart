import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/annotation_job_provider.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:app/features/match_history/widgets/annotation_job_banner.dart';
import 'package:app/features/match_history/widgets/history_empty_state.dart';
import 'package:app/features/match_history/widgets/history_match_card.dart';
import 'package:app/features/match_history/widgets/history_search_bar.dart';
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
    final activeJobs = ref.watch(activeJobsProvider);
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
          child: HistorySearchBar(
            controller: _searchCtrl,
            onChanged: (q) => setState(() => _query = q),
          ),
        ),
      ),
      body: filtered.isEmpty && activeJobs.isEmpty
          ? HistoryEmptyState(hasQuery: _query.isNotEmpty)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
              itemCount: filtered.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AnnotationJobBanner(jobs: activeJobs),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: HistoryMatchCard(archive: filtered[i - 1]),
                );
              },
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
