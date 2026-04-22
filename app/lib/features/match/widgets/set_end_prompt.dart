import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen overlay shown at the end of a set or a match.
/// Dismissable only via the action buttons — tapping outside does NOT
/// close it (would hide match-ending info that the user wants to read).
class SetEndPrompt extends ConsumerWidget {
  const SetEndPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popup = ref.watch(matchProvider.select((s) => s.popup));
    if (popup == null ||
        (popup.kind != PopupKind.setEnd &&
            popup.kind != PopupKind.matchEnd)) {
      return const SizedBox.shrink();
    }
    final state = ref.read(matchProvider);
    final isMatch = popup.kind == PopupKind.matchEnd;
    final winnerTeam = state.teams[popup.winner]!;
    final color = popup.winner == TeamSide.e1 ? MH.them : MH.us;
    final setsE1 = state.setsWonOf(TeamSide.e1);
    final setsE2 = state.setsWonOf(TeamSide.e2);
    final notifier = ref.read(matchProvider.notifier);

    return Positioned.fill(
      child: Container(
        color: const Color(0xC6141210),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(22),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: MH.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isMatch
                      ? 'MATCH · ${winnerTeam.name.toUpperCase()}'
                      : 'SET ${state.setNumber} · ${winnerTeam.name.toUpperCase()}',
                  style: MH.sans(
                    size: 10,
                    weight: FontWeight.w700,
                    color: MH.paper,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isMatch ? 'Match gagné' : 'Set gagné',
                style: MH.sans(
                  size: 22,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${state.scoreE1} — ${state.scoreE2} · sets $setsE1-$setsE2',
                style: MH.sans(
                  size: 13,
                  weight: FontWeight.w500,
                  color: MH.pencil,
                ),
              ),
              const SizedBox(height: 16),
              if (isMatch) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      notifier.dismissPopup();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    style: _primaryBtn(),
                    child: Text(
                      "Retour à l'accueil",
                      style: MH.sans(
                        weight: FontWeight.w700,
                        color: MH.paper,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: notifier.startNextSet,
                    style: _primaryBtn(),
                    child: Text('Commencer le set suivant',
                        style: MH.sans(
                          weight: FontWeight.w700,
                          color: MH.paper,
                        )),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: notifier.undoPoint,
                  child: Text(
                    'Annuler le dernier point',
                    style: MH.sans(
                      size: 12,
                      color: MH.inkSoft,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _primaryBtn() => ElevatedButton.styleFrom(
        backgroundColor: MH.ink,
        foregroundColor: MH.paper,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      );
}
