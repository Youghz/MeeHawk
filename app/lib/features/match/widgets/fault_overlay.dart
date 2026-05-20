import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _faultTypes = ['Filet', 'Double', 'Contrôle'];

class FaultOverlay extends ConsumerWidget {
  const FaultOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup! as FaultPopup;
    final loserTeam = popup.winner.other;
    final loserPlayer = state.playerById(popup.playerId);
    const color = MH.bad;
    final notifier = ref.read(matchProvider.notifier);

    return _AnchoredDropdown(
      anchor: popup.tapPos,
      color: color,
      items: _faultTypes,
      onPick: (t) => notifier.addPoint(
        winner: popup.winner,
        annotations: [
          Annotation(
            type: 'fault',
            text: 'Faute $t · ${loserPlayer?.name ?? '—'}',
            team: loserTeam,
          ),
        ],
      ),
      onDismiss: notifier.dismissPopup,
    );
  }
}

class _AnchoredDropdown extends StatelessWidget {
  const _AnchoredDropdown({
    required this.anchor,
    required this.color,
    required this.items,
    required this.onPick,
    required this.onDismiss,
  });

  final Offset anchor;
  final Color color;
  final List<String> items;
  final void Function(String) onPick;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const menuW = 140.0;
    const rowH = 34.0;
    final menuH = items.length * rowH;
    return LayoutBuilder(builder: (ctx, constraints) {
      final maxW = constraints.maxWidth;
      final maxH = constraints.maxHeight;
      var left = anchor.dx - menuW / 2;
      var top = anchor.dy + 8;
      if (left < 4) left = 4;
      if (left + menuW > maxW - 4) left = maxW - menuW - 4;
      if (top + menuH > maxH - 4) top = anchor.dy - menuH - 8;
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
          width: menuW,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            color: MH.paper,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++)
                    _DropdownRow(
                      label: items[i],
                      color: color,
                      showDivider: i < items.length - 1,
                      height: rowH,
                      onTap: () => onPick(items[i]),
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

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.color,
    required this.showDivider,
    required this.height,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool showDivider;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: MH.ruleSoft),
                  )
                : null,
          ),
          child: Text(label,
              style: MH.sans(
                size: 13,
                weight: FontWeight.w600,
                color: color,
              )),
        ),
      );
}
