import 'package:app/core/theme.dart';
import 'package:app/core/widgets/ball_icon.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/drag_preview_provider.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match/widgets/court.dart' show kCourtMargin;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerDot extends ConsumerWidget {
  const PlayerDot({
    required this.playerId,
    required this.courtWidth,
    required this.courtHeight,
    super.key,
  });

  final String playerId;
  final double courtWidth;
  final double courtHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(
      matchProvider.select((s) => s.playerById(playerId)!),
    );
    final teamKey = ref.watch(
      matchProvider.select((s) => s.teamOfPlayer(playerId)!),
    );
    final originalPos = ref.watch(
      matchProvider.select((s) => s.positions[playerId]!),
    );
    final isServer = ref.watch(
      matchProvider.select((s) => s.servingPlayerId == playerId),
    );
    final mateId = ref.watch(matchProvider.select((s) {
      final team = s.teams[teamKey]!;
      return team.players.firstWhere((p) => p.id != playerId).id;
    }));
    final matePos = ref.watch(
      matchProvider.select((s) => s.positions[mateId]!),
    );

    final drag = ref.watch(dragPreviewProvider);
    final color = teamKey == TeamSide.e1 ? MH.them : MH.us;
    final amDragger = drag?.playerId == playerId;
    final isMateOfDragger =
        drag != null && drag.playerId != playerId && drag.playerId == mateId;
    final armed = drag?.armed ?? false;

    CourtPos pos;
    if (amDragger) {
      pos = drag!.pos ?? originalPos;
    } else if (isMateOfDragger && armed) {
      pos = matePos;
    } else {
      pos = originalPos;
    }

    return AnimatedPositioned(
      duration: amDragger ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      left: pos.x * courtWidth,
      top: pos.y * courtHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTap(ref, originalPos, teamKey),
          onLongPressStart: (_) =>
              ref.read(dragPreviewProvider.notifier).start(playerId),
          onLongPressMoveUpdate: (details) {
            final nx = (originalPos.x +
                    details.offsetFromOrigin.dx / courtWidth)
                .clamp(0.0, 1.0);
            final ny = (originalPos.y +
                    details.offsetFromOrigin.dy / courtHeight)
                .clamp(0.0, 1.0);
            final newPos = CourtPos(nx, ny);
            final armedNow = _closerTo(newPos, matePos, originalPos);
            ref
                .read(dragPreviewProvider.notifier)
                .move(newPos, armed: armedNow);
          },
          onLongPressEnd: (_) => _release(ref, armed),
          onLongPressCancel: () => _release(ref, false),
          child: AnimatedScale(
            scale: amDragger ? 1.12 : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minWidth: 52),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MH.paper,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: color,
                  width: amDragger ? 2.5 : 2,
                ),
                boxShadow: [
                  if (isServer)
                    const BoxShadow(color: MH.ballSoft, spreadRadius: 3),
                  if (amDragger)
                    BoxShadow(
                      color: color.withValues(alpha: armed ? 0.5 : 0.25),
                      blurRadius: armed ? 14 : 10,
                      spreadRadius: armed ? 6 : 4,
                    ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Text(
                    player.name,
                    style: MH.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (isServer)
                    const Positioned(
                      top: -20,
                      child: BallIcon(size: 12),
                    ),
                  if (amDragger)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: _SwapBadge(color: armed ? color : MH.ink),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(WidgetRef ref, CourtPos pos, TeamSide teamKey) {
    final opposing = teamKey.other;
    final anchor = Offset(
      kCourtMargin + pos.x * courtWidth,
      kCourtMargin + pos.y * courtHeight,
    );
    ref.read(matchProvider.notifier).showPopup(
          MatchPopup(
            kind: PopupKind.fault,
            winner: opposing,
            playerId: playerId,
            tapPos: anchor,
          ),
        );
  }

  void _release(WidgetRef ref, bool armed) {
    if (armed) {
      ref.read(matchProvider.notifier).swapTeammates(playerId);
    }
    ref.read(dragPreviewProvider.notifier).clear();
  }

  static bool _closerTo(CourtPos p, CourtPos target, CourtPos origin) {
    final dT =
        (p.x - target.x) * (p.x - target.x) + (p.y - target.y) * (p.y - target.y);
    final dO =
        (p.x - origin.x) * (p.x - origin.x) + (p.y - origin.y) * (p.y - origin.y);
    return dT < dO;
  }
}

class _SwapBadge extends StatelessWidget {
  const _SwapBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: const Icon(
          Icons.swap_vert,
          size: 14,
          color: MH.paper,
        ),
      );
}
