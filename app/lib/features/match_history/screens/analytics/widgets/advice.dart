import 'package:app/core/rules/analytics_rules.dart';
import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match_history/screens/analytics/analytics_input.dart';
import 'package:flutter/material.dart';

class AdviceTip {
  const AdviceTip(
      {required this.icon, required this.text, this.positive = false});
  final IconData icon;
  final String text;
  final bool positive;
}

List<AdviceTip> buildAdvice(AnalyticsInput input) {
  final tips = <AdviceTip>[];
  final pts = input.pts;
  if (pts.isEmpty) return tips;

  final player = input.filterPlayerId == null
      ? null
      : input.team.players.firstWhere(
          (p) => p.id == input.filterPlayerId,
          orElse: () => const Player(id: '', name: ''),
        );
  final actorName =
      (player != null && player.name.isNotEmpty) ? player.name : input.team.name;

  // 1. Service
  final myServes = input.ptsWithServer
      .where((p) => p.server == input.selectedTeam)
      .toList();
  if (myServes.length >= 3) {
    final wins =
        myServes.where((p) => p.pt.winner == input.selectedTeam).length;
    final rate = wins / myServes.length;
    if (rate < 0.45) {
      tips.add(AdviceTip(
        icon: Icons.arrow_upward_rounded,
        text:
            'Service fragile : $actorName ne gagne que ${(rate * 100).round()}% des points au service. Variez les zones ou agressez davantage.',
      ));
    } else if (rate >= 0.60) {
      tips.add(AdviceTip(
        icon: Icons.arrow_upward_rounded,
        text:
            'Service dominant : $actorName gagne ${(rate * 100).round()}% des points au service. Continuez à presser.',
        positive: true,
      ));
    }
  }

  // 2. Attack type comparison (best vs worst, if diff ≥ 15pp)
  final attackSubs = <String, ({int wins, int total})>{};
  for (final p in input.ptsForPlayer) {
    Annotation? last;
    for (final a in p.annotations.reversed) {
      if (a.team == input.selectedTeam) {
        last = a;
        break;
      }
    }
    if (last?.type != 'attack') continue;
    final sub = AnalyticsRules.subtype(last!.text);
    if (sub == null || sub.isEmpty) continue;
    final won = p.winner == input.selectedTeam;
    final prev = attackSubs[sub] ?? (wins: 0, total: 0);
    attackSubs[sub] = (wins: prev.wins + (won ? 1 : 0), total: prev.total + 1);
  }
  final validSubs =
      attackSubs.entries.where((e) => e.value.total >= 2).toList();
  if (validSubs.length >= 2) {
    validSubs.sort((a, b) {
      final ra = a.value.wins / a.value.total;
      final rb = b.value.wins / b.value.total;
      return rb.compareTo(ra);
    });
    final best = validSubs.first;
    final worst = validSubs.last;
    final bestRate = (best.value.wins / best.value.total * 100).round();
    final worstRate = (worst.value.wins / worst.value.total * 100).round();
    if (bestRate - worstRate >= 15) {
      tips.add(AdviceTip(
        icon: Icons.sports_volleyball_outlined,
        text:
            '${AnalyticsRules.cap(best.key)} à $bestRate% contre ${AnalyticsRules.cap(worst.key).toLowerCase()} à $worstRate% — jouer davantage ${best.key.toLowerCase()} serait un avantage tactique.',
        positive: true,
      ));
    }
  }

  // 3. Best rally length bucket
  final rallyData = <int, ({int wins, int total})>{};
  for (final pt in pts) {
    final ex = AnalyticsRules.exchanges(pt);
    final won = pt.winner == input.selectedTeam;
    final prev = rallyData[ex] ?? (wins: 0, total: 0);
    rallyData[ex] = (wins: prev.wins + (won ? 1 : 0), total: prev.total + 1);
  }
  final validBuckets =
      rallyData.entries.where((e) => e.value.total >= 2).toList();
  if (validBuckets.length >= 2) {
    validBuckets.sort((a, b) {
      final ra = a.value.wins / a.value.total;
      final rb = b.value.wins / b.value.total;
      return rb.compareTo(ra);
    });
    final best = validBuckets.first;
    final rate = (best.value.wins / best.value.total * 100).round();
    const bucketLabels = {
      0: 'points directs',
      1: 'échanges courts',
      2: 'échanges à 2 touches',
      3: 'longs échanges',
      4: 'très longs échanges',
    };
    final label = bucketLabels[best.key] ?? 'échanges longs';
    final advice = best.key <= 1
        ? 'Attaquez vite et directement.'
        : 'Soyez patients — votre efficacité augmente avec le temps.';
    tips.add(AdviceTip(
      icon: Icons.sync_alt_rounded,
      text: 'Meilleur taux sur $label ($rate%). $advice',
      positive: rate >= 55,
    ));
  }

  // 4. Pressure (≥18 : clutch or choke)
  final decPts = pts
      .where((p) =>
          p.scoreOf(input.selectedTeam) >= 18 ||
          p.scoreOf(input.selectedTeam.other) >= 18)
      .toList();
  if (decPts.length >= 3) {
    final wins =
        decPts.where((p) => p.winner == input.selectedTeam).length;
    final rate = wins / decPts.length;
    if (rate < 0.40) {
      tips.add(AdviceTip(
        icon: Icons.psychology_outlined,
        text:
            'Points décisifs (≥18) : seulement ${(rate * 100).round()}% de réussite. Travaillez la gestion du stress en fin de set.',
      ));
    } else if (rate >= 0.65) {
      tips.add(AdviceTip(
        icon: Icons.psychology_outlined,
        text:
            'Clutch à ${(rate * 100).round()}% sur les points décisifs (≥18) — un vrai atout mental.',
        positive: true,
      ));
    }
  }

  return tips.take(4).toList();
}

class AdviceSection extends StatelessWidget {
  const AdviceSection(this.input, {super.key});
  final AnalyticsInput input;

  @override
  Widget build(BuildContext context) {
    final tips = buildAdvice(input);
    if (tips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tip in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: (tip.positive ? MH.good : MH.mid)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tip.icon,
                      size: 13,
                      color: tip.positive ? MH.good : MH.mid),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tip.text,
                      style: MH.sans(size: 12, color: MH.inkSoft, height: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
