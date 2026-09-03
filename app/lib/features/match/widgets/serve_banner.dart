import 'package:app/core/theme.dart';
import 'package:app/core/widgets/ball_icon.dart';
import 'package:app/core/widgets/court/court_constants.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/state/match_provider.dart';
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
        _ServerBadge(teamColor: serverColor, playerName: server?.name ?? '—');

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          const SizedBox(width: kCourtMargin),
          Expanded(
            child: serverOnLeft ? Center(child: badge) : const SizedBox.shrink(),
          ),
          Expanded(
            child: serverOnLeft ? const SizedBox.shrink() : Center(child: badge),
          ),
          const SizedBox(width: kCourtMargin),
        ],
      ),
    );
  }
}

class _ServerBadge extends StatelessWidget {
  const _ServerBadge({
    required this.teamColor,
    required this.playerName,
  });

  final Color teamColor;
  final String playerName;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: MH.ballSoft,
          border: Border.all(color: MH.ball, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BallIcon(size: 15),
            const SizedBox(width: 6),
            Text('Service',
                style: MH.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: MH.ball,
                )),
            Text(' · ',
                style: MH.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: MH.ball,
                )),
            Text(playerName,
                style: MH.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: teamColor,
                )),
          ],
        ),
      );
}
