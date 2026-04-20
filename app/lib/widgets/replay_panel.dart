import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../theme.dart';

class ReplayPanel extends ConsumerWidget {
  const ReplayPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final idx = state.selectedPointIndex;
    if (idx == null || idx >= state.history.length) {
      return const SizedBox.shrink();
    }
    final point = state.history[idx];
    final winnerTeam = state.teams[point.winner]!;
    final color = point.winner == 'e1' ? MH.them : MH.us;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MH.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('ÉCHANGE ${idx + 1}',
                      style: MH.sans(
                        size: 9,
                        weight: FontWeight.w700,
                        color: MH.paper,
                        letterSpacing: 0.6,
                      )),
                ),
                const SizedBox(width: 6),
                Text(
                  '${point.scoreE1}–${point.scoreE2}',
                  style: MH.sans(
                    size: 10,
                    color: MH.paper.withValues(alpha: 0.6),
                  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const Spacer(),
                Text(
                  'POINT ${winnerTeam.name.toUpperCase()}',
                  style: MH.sans(
                    size: 9,
                    weight: FontWeight.w600,
                    color: MH.ball,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () =>
                      ref.read(matchProvider.notifier).clearSelection(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('×',
                        style: MH.sans(
                          size: 16,
                          color: MH.paper.withValues(alpha: 0.5),
                        )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (point.annotations.isEmpty)
              Text('Aucune annotation pour cet échange',
                  style: MH.sans(
                    size: 11,
                    color: MH.paper.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  )),
            for (final a in point.annotations)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('· ',
                        style: MH.sans(
                          size: 11,
                          color: MH.paper.withValues(alpha: 0.5),
                        )),
                    Expanded(
                      child: Text(a.text,
                          style: MH.sans(
                            size: 11,
                            color: MH.paper,
                            height: 1.3,
                          )),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
