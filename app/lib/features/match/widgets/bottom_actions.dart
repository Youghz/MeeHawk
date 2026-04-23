import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomActions extends ConsumerWidget {
  const BottomActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leftTeam = ref.watch(matchProvider.select((s) => s.leftTeam));
    final leftName =
        ref.watch(matchProvider.select((s) => s.teams[leftTeam]!.name));
    final rightName =
        ref.watch(matchProvider.select((s) => s.teams[leftTeam.other]!.name));
    final canUndo = ref.watch(
      matchProvider.select((s) => s.history.isNotEmpty),
    );
    final hasRallyImpacts = ref.watch(
      matchProvider.select((s) => s.rallyImpacts.isNotEmpty),
    );
    final matchOver =
        ref.watch(matchProvider.select((s) => s.matchOver));
    final notifier = ref.read(matchProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        children: [
          if (hasRallyImpacts) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: notifier.undoLastImpact,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  side: const BorderSide(color: MH.ball, width: 1.5),
                  backgroundColor: MH.ballSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '↺ Annuler la dernière action',
                  style: MH.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    color: MH.ball,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _PointButton(
                  teamKey: leftTeam,
                  teamName: leftName,
                  enabled: !matchOver,
                  onPressed: () => notifier.addPoint(
                    winner: leftTeam,
                    annotations: [
                      Annotation(
                        type: 'manual',
                        text: '+1 $leftName (manuel)',
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PointButton(
                  teamKey: leftTeam.other,
                  teamName: rightName,
                  enabled: !matchOver,
                  onPressed: () => notifier.addPoint(
                    winner: leftTeam.other,
                    annotations: [
                      Annotation(
                        type: 'manual',
                        text: '+1 $rightName (manuel)',
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
              onPressed: canUndo ? notifier.undoPoint : null,
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
  const _PointButton({
    required this.teamKey,
    required this.teamName,
    required this.enabled,
    required this.onPressed,
  });

  final TeamSide teamKey;
  final String teamName;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isE1 = teamKey == TeamSide.e1;
    final bg = isE1 ? MH.themSoft : MH.usSoft;
    final fg = isE1 ? MH.them : MH.us;
    final opacity = enabled ? 1.0 : 0.4;
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: enabled ? onPressed : null,
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
      ),
    );
  }
}
