import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';
import '../providers/match_provider.dart';
import '../theme.dart';

class BottomActions extends ConsumerWidget {
  const BottomActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final leftTk = state.sidesSwapped ? 'e2' : 'e1';
    final rightTk = state.sidesSwapped ? 'e1' : 'e2';
    final notifier = ref.read(matchProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PointButton(
                  teamKey: leftTk,
                  teamName: state.teams[leftTk]!.name,
                  onPressed: () => notifier.addPoint(
                    winner: leftTk,
                    annotations: [
                      Annotation(
                        type: 'manual',
                        text: '+1 ${state.teams[leftTk]!.name} (manuel)',
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PointButton(
                  teamKey: rightTk,
                  teamName: state.teams[rightTk]!.name,
                  onPressed: () => notifier.addPoint(
                    winner: rightTk,
                    annotations: [
                      Annotation(
                        type: 'manual',
                        text: '+1 ${state.teams[rightTk]!.name} (manuel)',
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: state.history.isEmpty ? null : notifier.undoPoint,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                side: const BorderSide(color: MH.inkSoft, width: 1.5),
                backgroundColor: MH.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('↶ Annuler le dernier point',
                  style: MH.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    color: MH.inkSoft,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointButton extends StatelessWidget {
  final String teamKey;
  final String teamName;
  final VoidCallback onPressed;
  const _PointButton({
    required this.teamKey,
    required this.teamName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isE1 = teamKey == 'e1';
    final bg = isE1 ? MH.themSoft : MH.usSoft;
    final fg = isE1 ? MH.them : MH.us;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('+ POINT',
                style: MH.sans(
                  size: 10,
                  weight: FontWeight.w600,
                  color: fg,
                  letterSpacing: 0.5,
                )),
            Text(teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MH.sans(
                  size: 15,
                  weight: FontWeight.w700,
                  color: fg,
                )),
          ],
        ),
      ),
    );
  }
}
