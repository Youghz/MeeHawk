import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';
import '../providers/match_provider.dart';
import '../theme.dart';

const _attackTypes = ['Cut', 'Line', 'Shot', 'Power', 'Ace', 'Bloc'];
const _faultTypes = ['Service', 'Filet', 'Double', 'Out', 'Pied', 'Autre'];

class AttackPopup extends ConsumerWidget {
  const AttackPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup!;
    final team = state.teams[popup.winner]!;
    final color = popup.winner == 'e1' ? MH.them : MH.us;

    void pick(String t) {
      ref.read(matchProvider.notifier).addPoint(
        winner: popup.winner,
        annotations: [
          Annotation(
            type: 'attack',
            text: 'Attaque $t',
            team: popup.winner,
          ),
        ],
      );
    }

    return _PopupScrim(
      onDismiss: () => ref.read(matchProvider.notifier).dismissPopup(),
      child: _PopupCard(
        color: color,
        header: 'POINT ${team.name.toUpperCase()}',
        title: "Type d'attaque",
        children: [
          _TypeGrid(
            types: _attackTypes,
            color: color,
            onPick: pick,
          ),
        ],
      ),
    );
  }
}

class FaultPopup extends ConsumerWidget {
  const FaultPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup!;
    final team = state.teams[popup.winner]!;
    final loserTeam = popup.winner == 'e1' ? 'e2' : 'e1';
    final loserPlayer = state.playerById(popup.playerId!);
    const color = MH.them;

    void pick(String t) {
      ref.read(matchProvider.notifier).addPoint(
        winner: popup.winner,
        annotations: [
          Annotation(
            type: 'fault',
            text: 'Faute $t · ${loserPlayer?.name ?? '—'}',
            team: loserTeam,
          ),
        ],
      );
    }

    return _PopupScrim(
      onDismiss: () => ref.read(matchProvider.notifier).dismissPopup(),
      child: _PopupCard(
        color: color,
        header: 'FAUTE · ${loserPlayer?.name.toUpperCase() ?? ''}',
        title: 'Type de faute',
        children: [
          _TypeGrid(types: _faultTypes, color: color, onPick: pick),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Point pour ${team.name}',
              style: MH.sans(size: 10, color: MH.pencil),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupScrim extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;
  const _PopupScrim({required this.child, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: GestureDetector(
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

class _TypeGrid extends StatelessWidget {
  final List<String> types;
  final Color color;
  final void Function(String) onPick;
  const _TypeGrid(
      {required this.types, required this.color, required this.onPick});

  @override
  Widget build(BuildContext context) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.4,
        children: types
            .map((t) => InkWell(
                  onTap: () => onPick(t),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: color, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t,
                        style: MH.sans(
                          size: 12,
                          weight: FontWeight.w600,
                          color: color,
                        )),
                  ),
                ))
            .toList(),
      );
}
