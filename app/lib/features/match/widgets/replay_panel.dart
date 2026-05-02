import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReplayPanel extends ConsumerWidget {
  const ReplayPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx =
        ref.watch(matchProvider.select((s) => s.selectedPointIndex));
    final history =
        ref.watch(matchProvider.select((s) => s.history));
    if (idx == null || idx >= history.length) {
      return const SizedBox.shrink();
    }
    final point = history[idx];
    final teams =
        ref.watch(matchProvider.select((s) => s.teams));
    final winnerTeam = teams[point.winner]!;
    final color = point.winner == TeamSide.e1 ? MH.them : MH.us;
    final lastAction = point.annotations.isNotEmpty
        ? point.annotations.last
        : null;
    final crossings = point.netCrossings;
    final actionType = lastAction?.type;

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
                        size: 10,
                        weight: FontWeight.w700,
                        color: MH.paper,
                        letterSpacing: 0.6,
                      )),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '$crossings passage${crossings > 1 ? 's' : ''} au filet',
                    overflow: TextOverflow.ellipsis,
                    style: MH.sans(
                      size: 11,
                      color: MH.paper.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'POINT ${winnerTeam.name.toUpperCase()}',
                  overflow: TextOverflow.ellipsis,
                  style: MH.sans(
                    size: 10,
                    weight: FontWeight.w600,
                    color: MH.ball,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _actionIcon(actionType),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lastAction?.text ?? 'Aucune action enregistrée',
                    style: MH.sans(
                      size: 12,
                      color: MH.paper,
                      height: 1.3,
                      fontStyle: lastAction == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _actionIcon(String? type) {
  switch (type) {
    case 'fault':
      return const Icon(Icons.close_rounded, size: 16, color: MH.bad);
    case 'service':
      return const Icon(Icons.bolt_rounded, size: 16, color: MH.ball);
    case 'block':
      return const Icon(Icons.back_hand, size: 16, color: MH.paper);
    case 'attack':
      return const Icon(
          Icons.arrow_forward_rounded, size: 16, color: MH.paper);
    default:
      return const SizedBox(width: 16);
  }
}
