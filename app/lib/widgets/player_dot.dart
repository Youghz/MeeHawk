import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';
import '../providers/match_provider.dart';
import '../theme.dart';
import 'ball_icon.dart';

class PlayerDot extends ConsumerStatefulWidget {
  final String playerId;
  final double courtWidth;
  final double courtHeight;
  const PlayerDot({
    super.key,
    required this.playerId,
    required this.courtWidth,
    required this.courtHeight,
  });

  @override
  ConsumerState<PlayerDot> createState() => _PlayerDotState();
}

class _PlayerDotState extends ConsumerState<PlayerDot> {
  CourtPos? _localPos;
  bool _dragging = false;
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);
    final player = state.playerById(widget.playerId)!;
    final teamKey = state.teamOfPlayer(widget.playerId)!;
    final color = teamKey == 'e1' ? MH.them : MH.us;
    final pos = _localPos ?? state.positions[widget.playerId]!;
    final isServer = state.servingPlayerId == widget.playerId;

    return Positioned(
      left: pos.x * widget.courtWidth,
      top: pos.y * widget.courtHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) {
            setState(() {
              _dragging = true;
              _moved = false;
            });
          },
          onLongPressMoveUpdate: (details) {
            final base = state.positions[widget.playerId]!;
            final nx = (base.x + details.offsetFromOrigin.dx / widget.courtWidth)
                .clamp(0.05, 0.95);
            final ny = (base.y + details.offsetFromOrigin.dy / widget.courtHeight)
                .clamp(0.10, 0.90);
            setState(() {
              _localPos = CourtPos(nx, ny);
              _moved = details.offsetFromOrigin.distance > 4;
            });
          },
          onLongPressEnd: (_) {
            final notifier = ref.read(matchProvider.notifier);
            if (_moved && _localPos != null) {
              notifier.movePlayer(widget.playerId, _localPos!);
            } else {
              final opposing = teamKey == 'e1' ? 'e2' : 'e1';
              notifier.showPopup(MatchPopup(
                kind: PopupKind.fault,
                winner: opposing,
                playerId: widget.playerId,
              ));
            }
            setState(() {
              _dragging = false;
              _localPos = null;
              _moved = false;
            });
          },
          child: AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minWidth: 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: MH.paper,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color, width: 2),
              boxShadow: isServer
                  ? [BoxShadow(color: MH.ballSoft, spreadRadius: 3)]
                  : null,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
