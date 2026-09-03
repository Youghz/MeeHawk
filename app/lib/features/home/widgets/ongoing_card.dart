import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/match_screen.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OngoingCard extends ConsumerWidget {
  const OngoingCard({
    required this.archive,
    required this.isCurrent,
    super.key,
  });

  final MatchArchive archive;
  final bool isCurrent;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(archiveListProvider.notifier).remove(archive.id);
    if (isCurrent) ref.read(matchProvider.notifier).resetMatch();
  }

  void _resume(BuildContext context, WidgetRef ref) {
    if (!isCurrent) ref.read(matchProvider.notifier).resumeMatch(archive.state);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MatchScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = archive.state;
    final name1 = s.teams[TeamSide.e1]!.name;
    final name2 = s.teams[TeamSide.e2]!.name;
    final setsE1 = s.setsWonOf(TeamSide.e1);
    final setsE2 = s.setsWonOf(TeamSide.e2);

    return Material(
      color: MH.sand,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _resume(context, ref),
        splashColor: MH.ball.withValues(alpha: 0.10),
        highlightColor: MH.ball.withValues(alpha: 0.06),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: MH.ball, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: MH.ball,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Reprendre le match',
                        style: MH.sans(size: 15, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$name1 ${s.scoreE1} – ${s.scoreE2} $name2'
                        '  ·  set ${s.setNumber} ($setsE1–$setsE2)',
                        style: MH.mono(letterSpacing: 0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: MH.pencil,
                  ),
                  onPressed: () async {
                    await _delete(context, ref);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
