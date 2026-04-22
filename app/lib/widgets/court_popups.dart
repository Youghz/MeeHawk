import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';
import '../providers/match_provider.dart';
import '../theme.dart';

const _faultTypes = ['Filet', 'Double', 'Contrôle'];
const _blockDirections = ['Ligne', 'Diagonale'];

class _AnchoredDropdown extends StatelessWidget {
  final Offset anchor;
  final Color color;
  final List<String> items;
  final void Function(String) onPick;
  final VoidCallback onDismiss;

  const _AnchoredDropdown({
    required this.anchor,
    required this.color,
    required this.items,
    required this.onPick,
    required this.onDismiss,
  });

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
  final String label;
  final Color color;
  final bool showDivider;
  final double height;
  final VoidCallback onTap;
  const _DropdownRow({
    required this.label,
    required this.color,
    required this.showDivider,
    required this.height,
    required this.onTap,
  });

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
                    bottom: BorderSide(color: MH.ruleSoft, width: 1),
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
    final color = popup.winner == 'e1' ? MH.them : MH.us;

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

class BlockPopup extends ConsumerStatefulWidget {
  const BlockPopup({super.key});

  @override
  ConsumerState<BlockPopup> createState() => _BlockPopupState();
}

class _BlockPopupState extends ConsumerState<BlockPopup> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);
    final popup = state.popup!;
    final notifier = ref.read(matchProvider.notifier);
    final teamKey = popup.winner;
    final color = teamKey == 'e1' ? MH.them : MH.us;
    // Blocker = nearest player attributed on the double-tap impact (last one).
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

class OutsideFaultPopup extends ConsumerStatefulWidget {
  const OutsideFaultPopup({super.key});

  @override
  ConsumerState<OutsideFaultPopup> createState() => _OutsideFaultPopupState();
}

class _OutsideFaultPopupState extends ConsumerState<OutsideFaultPopup> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);
    final popup = state.popup!;
    final notifier = ref.read(matchProvider.notifier);
    final winner = popup.winner;
    final faultTeamKey = winner == 'e1' ? 'e2' : 'e1';
    const color = MH.bad;
    // Faulter = last touch before the ball went out (previous impact; the
    // outside impact itself was just recorded so its playerId is a nearest-
    // defender heuristic — not the faulter).
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
    final loserTeam = popup.winner == 'e1' ? 'e2' : 'e1';
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
  final Widget child;
  final VoidCallback onDismiss;
  const _PopupScrim({required this.child, required this.onDismiss});

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
  final Color color;
  final String header;
  final String title;
  final List<Widget> children;
  const _PopupCard({
    required this.color,
    required this.header,
    required this.title,
    required this.children,
  });

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
                    color: MH.ink,
                  )),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

