import 'package:app/core/theme.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/state/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PickServerOverlay extends ConsumerWidget {
  const PickServerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final popup = state.popup! as PickServerPopup;
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
