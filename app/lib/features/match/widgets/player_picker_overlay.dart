import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Micro-bubble anchored to the tap position asking which player made the
/// touch (or block). Shows on the first contact of each side visit.
class PlayerPickerOverlay extends ConsumerWidget {
  const PlayerPickerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup! as PickPlayerPopup;
    final teamSide = popup.winner;
    final team = state.teams[teamSide]!;
    final color = teamSide == TeamSide.e1 ? MH.them : MH.us;
    final notifier = ref.read(matchProvider.notifier);
    final isBlock = popup.pendingImpact.isBlock;

    return _AnchoredPlayerPicker(
      anchor: popup.tapPos,
      color: color,
      label: isBlock ? 'Bloc — qui ?' : 'Touche — qui ?',
      players: team.players,
      onPick: notifier.confirmPlayerPick,
      onDismiss: notifier.dismissPopup,
    );
  }
}

class _AnchoredPlayerPicker extends StatelessWidget {
  const _AnchoredPlayerPicker({
    required this.anchor,
    required this.color,
    required this.label,
    required this.players,
    required this.onPick,
    required this.onDismiss,
  });

  final Offset anchor;
  final Color color;
  final String label;
  final List<Player> players;
  final void Function(String playerId) onPick;
  final VoidCallback onDismiss;

  static const _menuW = 152.0;
  static const _rowH = 38.0;
  static const _headerH = 26.0;

  @override
  Widget build(BuildContext context) {
    final menuH = players.length * _rowH + _headerH;
    return LayoutBuilder(builder: (ctx, constraints) {
      final maxW = constraints.maxWidth;
      final maxH = constraints.maxHeight;
      var left = anchor.dx - _menuW / 2;
      var top = anchor.dy + 10;
      if (left < 4) left = 4;
      if (left + _menuW > maxW - 4) left = maxW - _menuW - 4;
      if (top + menuH > maxH - 4) top = anchor.dy - menuH - 10;
      if (top < 4) top = 4;

      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _menuW,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            color: MH.paper,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: _headerH,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: MH.sans(
                        size: 10,
                        weight: FontWeight.w700,
                        color: MH.paper,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  for (int i = 0; i < players.length; i++)
                    InkWell(
                      onTap: () => onPick(players[i].id),
                      borderRadius: i == players.length - 1
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(8))
                          : BorderRadius.zero,
                      child: Container(
                        height: _rowH,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: i < players.length - 1
                            ? const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: MH.ruleSoft),
                                ),
                              )
                            : null,
                        child: Row(
                          children: [
                            Text(
                              'J${i + 1} ',
                              style: MH.sans(
                                size: 10,
                                weight: FontWeight.w700,
                                color: MH.rule,
                              ),
                            ),
                            Text(
                              players[i].name,
                              style: MH.sans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ]);
    });
  }
}
