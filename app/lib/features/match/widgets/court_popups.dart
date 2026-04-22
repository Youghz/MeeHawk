import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _faultTypes = ['Filet', 'Double', 'Contrôle'];
const _blockDirections = ['Ligne', 'Diagonale'];

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

class PickServerPopup extends ConsumerWidget {
  const PickServerPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup!;
    final team = state.teams[popup.winner]!;
    final color = popup.winner == TeamSide.e1 ? MH.them : MH.us;

    return _PopupScrim(
      onDismiss: () => ref.read(matchProvider.notifier).dismissPopup(),
      child: _PopupCard(
        color: color,
        header: 'PREMIER SERVICE · ${team.name.toUpperCase()}',
        title: 'Qui sert en premier ?',
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in team.players)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => ref
                        .read(matchProvider.notifier)
                        .pickFirstServer(p.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(p.name,
                          style: MH.sans(
                            size: 13,
                            weight: FontWeight.w600,
                            color: color,
                          )),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class BlockPopup extends ConsumerWidget {
  const BlockPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup!;
    final notifier = ref.read(matchProvider.notifier);
    final teamKey = popup.winner;
    final color = teamKey == TeamSide.e1 ? MH.them : MH.us;
    final blocker = state.rallyImpacts.isNotEmpty
        ? state.playerById(state.rallyImpacts.last.playerId ?? '')
        : null;
    return _AnchoredDropdown(
      anchor: popup.tapPos ?? Offset.zero,
      color: color,
      items: _blockDirections,
      onPick: (dir) => notifier.addRallyAnnotation(
        Annotation(
          type: 'block',
          text: 'Bloc $dir · ${blocker?.name ?? '—'}',
          team: teamKey,
        ),
      ),
      onDismiss: notifier.dismissPopup,
    );
  }
}

class OutsideFaultPopup extends ConsumerWidget {
  const OutsideFaultPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup!;
    final notifier = ref.read(matchProvider.notifier);
    final winner = popup.winner;
    final faultTeamKey = winner.other;
    const color = MH.bad;
    final faulter = state.rallyImpacts.length >= 2
        ? state.playerById(
            state.rallyImpacts[state.rallyImpacts.length - 2].playerId ?? '',
          )
        : null;
    return _AnchoredDropdown(
      anchor: popup.tapPos ?? Offset.zero,
      color: color,
      items: _faultTypes,
      onPick: (t) => notifier.addPoint(
        winner: winner,
        annotations: [
          Annotation(
            type: 'fault',
            text: 'Faute $t · ${faulter?.name ?? '—'}',
            team: faultTeamKey,
          ),
        ],
      ),
      onDismiss: notifier.dismissPopup,
    );
  }
}

class FaultPopup extends ConsumerWidget {
  const FaultPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup!;
    final loserTeam = popup.winner.other;
    final loserPlayer = state.playerById(popup.playerId!);
    const color = MH.bad;
    final notifier = ref.read(matchProvider.notifier);

    return _AnchoredDropdown(
      anchor: popup.tapPos ?? Offset.zero,
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

class _PopupScrim extends StatelessWidget {
  const _PopupScrim({required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: child,
          ),
        ),
      );
}

class _PopupCard extends StatelessWidget {
  const _PopupCard({
    required this.color,
    required this.header,
    required this.title,
    required this.children,
  });

  final Color color;
  final String header;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        widthFactor: 0.88,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MH.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(header,
                  style: MH.sans(
                    size: 10,
                    weight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.6,
                  )),
              const SizedBox(height: 2),
              Text(title,
                  style: MH.sans(
                    size: 15,
                    weight: FontWeight.w700,
                  )),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}
