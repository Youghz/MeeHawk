import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../theme.dart';
import 'server_badge.dart';

class ServeBanner extends ConsumerWidget {
  const ServeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final server = state.playerById(state.servingPlayerId);
    final servingTeamKey = state.teamOfPlayer(state.servingPlayerId);
    final serverColor = servingTeamKey == 'e1' ? MH.them : MH.us;
    final serverOnLeft = state.sidesSwapped
        ? (servingTeamKey == 'e2')
        : (servingTeamKey == 'e1');

    final badge =
        ServerBadge(teamColor: serverColor, playerName: server?.name ?? '—');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: serverOnLeft
                ? Align(alignment: Alignment.center, child: badge)
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: serverOnLeft
                ? const SizedBox.shrink()
                : Align(alignment: Alignment.center, child: badge),
          ),
        ],
      ),
    );
  }
}
