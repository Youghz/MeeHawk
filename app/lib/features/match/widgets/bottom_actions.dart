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
    final hasPopup = ref.watch(
      matchProvider.select(
        (s) =>
            s.popup != null &&
            (s.popup!.kind == PopupKind.fault ||
                s.popup!.kind == PopupKind.pickPlayer),
      ),
    );
    final matchOver =
        ref.watch(matchProvider.select((s) => s.matchOver));
    final notifier = ref.read(matchProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: MH.sand,
        border: Border(top: BorderSide(color: MH.rule)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
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
          Row(
            children: [
              Expanded(
                child: _UndoButton(
                  label: hasPopup
                      ? '↺  Annuler la sélection'
                      : "↺  Annuler l'action",
                  onPressed: hasPopup
                      ? notifier.dismissPopup
                      : hasRallyImpacts
                          ? notifier.undoLastImpact
                          : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _UndoButton(
                  label: '↶  Annuler le point',
                  onPressed: canUndo ? notifier.undoPoint : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fgColor = enabled ? MH.inkSoft : MH.pencil.withValues(alpha: 0.4);
    return Material(
      color: enabled
          ? MH.rule.withValues(alpha: 0.40)
          : MH.rule.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        splashColor: MH.ink.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MH.sans(
                size: 12,
                weight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ),
        ),
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
    final baseColor = isE1 ? MH.them : MH.us;
    // amber (us) is bright — use dark text; blue (them) — use white
    final textColor = isE1 ? Colors.white : MH.paper;
    final alpha = enabled ? 1.0 : 0.30;
    final bg = baseColor.withValues(alpha: alpha);
    final fg = textColor.withValues(alpha: enabled ? 1.0 : 0.5);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        splashColor: Colors.black.withValues(alpha: 0.15),
        highlightColor: Colors.black.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'POINT',
                style: MH.mono(
                  size: 8,
                  weight: FontWeight.w600,
                  color: fg.withValues(alpha: (enabled ? 0.65 : 0.4)),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MH.sans(
                  size: 15,
                  weight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
