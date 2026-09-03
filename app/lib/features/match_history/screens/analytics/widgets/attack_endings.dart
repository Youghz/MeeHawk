import 'package:app/core/theme.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/domain/rules/analytics_rules.dart';
import 'package:app/features/match_history/screens/analytics/analytics_input.dart';
import 'package:app/features/match_history/screens/analytics/widgets/analytics_court.dart';
import 'package:app/features/match_history/screens/analytics/widgets/analytics_primitives.dart';
import 'package:flutter/material.dart';

class AttackEndingsSection extends StatelessWidget {
  const AttackEndingsSection(this.input, {super.key});
  final AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final pts = input.ptsForPlayer;
    final opponent = input.selectedTeam.other;

    final dots = <AnalyticsDot>[];
    for (final p in pts) {
      BallImpact? attackLanding;
      for (final imp in p.impacts.reversed) {
        if (imp.isServerPosition) continue;
        if (imp.teamSide == opponent) {
          attackLanding = imp;
          break;
        }
      }
      if (attackLanding == null) continue;
      dots.add(AnalyticsDot(
        x: AnalyticsRules.halfX(attackLanding.x),
        y: attackLanding.y,
        kind: !attackLanding.isOutside && p.winner == input.selectedTeam
            ? AnalyticsDotKind.won
            : AnalyticsDotKind.lost,
      ));
    }

    final endings = <String, ({int total, int wins})>{};
    final attackSubs = <String, ({int total, int wins})>{};

    for (final p in pts) {
      Annotation? last;
      for (final a in p.annotations.reversed) {
        if (a.team == input.selectedTeam) {
          last = a;
          break;
        }
      }
      if (last == null) continue;

      final won = p.winner == input.selectedTeam;
      final prev = endings[last.type] ?? (total: 0, wins: 0);
      endings[last.type] =
          (total: prev.total + 1, wins: prev.wins + (won ? 1 : 0));

      if (last.type == 'attack') {
        final sub = AnalyticsRules.subtype(last.text);
        if (sub != null && sub.isNotEmpty) {
          final prevSub = attackSubs[sub] ?? (total: 0, wins: 0);
          attackSubs[sub] = (
            total: prevSub.total + 1,
            wins: prevSub.wins + (won ? 1 : 0),
          );
        }
      }
    }

    if (dots.isEmpty && endings.isEmpty) return const SizedBox.shrink();

    const typeLabels = {
      'attack': 'Attaque',
      'block': 'Bloc',
      'fault': 'Faute adverse',
      'service': 'Ace / direct',
    };
    const typeColors = {
      'attack': MH.ink,
      'block': MH.ball,
      'fault': MH.mid,
      'service': MH.pencil,
    };

    final grandTotal = endings.isEmpty
        ? 1
        : endings.values.map((v) => v.total).reduce((a, b) => a + b);
    final sorted = endings.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    final subSorted = attackSubs.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dots.isNotEmpty) ...[
          AnalyticsCourt(dots: dots, halfCourt: true),
          const SizedBox(height: 16),
        ],
        if (endings.isNotEmpty) ...[
          Text(
            'Dernière action de ${input.team.name} · barre pleine = gagné',
            style: MH.sans(size: 11, color: MH.pencil),
          ),
          const SizedBox(height: 14),
          for (final e in sorted) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnalyticsLabeledBar(
                label: typeLabels[e.key] ?? e.key,
                value:
                    '${e.value.wins}/${e.value.total}  ${(e.value.total / grandTotal * 100).round()}%',
                ratio: e.value.total / grandTotal,
                color: typeColors[e.key] ?? MH.pencil,
                winRatio:
                    e.value.total > 0 ? e.value.wins / e.value.total : 0,
              ),
            ),
            if (e.key == 'attack')
              for (final sub in subSorted)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 10),
                  child: AnalyticsLabeledBar(
                    label: AnalyticsRules.cap(sub.key),
                    value:
                        '${sub.value.wins}/${sub.value.total}  ${(sub.value.total / grandTotal * 100).round()}%',
                    ratio: sub.value.total / grandTotal,
                    color: MH.pencil,
                    winRatio: sub.value.total > 0
                        ? sub.value.wins / sub.value.total
                        : 0,
                  ),
                ),
          ],
        ],
      ],
    );
  }
}
