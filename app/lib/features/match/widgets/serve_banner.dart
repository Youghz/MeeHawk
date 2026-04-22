import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match/widgets/server_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServeBanner extends ConsumerWidget {
  const ServeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverId = ref.watch(matchProvider.select((s) => s.servingPlayerId));
    final sidesSwapped =
        ref.watch(matchProvider.select((s) => s.sidesSwapped));
    final server =
        ref.watch(matchProvider.select((s) => s.playerById(serverId)));
    final servingTeam =
        ref.watch(matchProvider.select((s) => s.teamOfPlayer(serverId)));
    final serverColor = servingTeam == TeamSide.e1 ? MH.them : MH.us;
    final serverOnLeft = sidesSwapped
        ? (servingTeam == TeamSide.e2)
        : (servingTeam == TeamSide.e1);

    final badge =
        ServerBadge(teamColor: serverColor, playerName: server?.name ?? '—');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: serverOnLeft
                ? Align(child: badge)
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: serverOnLeft
                ? const SizedBox.shrink()
                : Align(child: badge),
          ),
        ],
      ),
    );
  }
}
