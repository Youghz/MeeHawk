import 'package:app/core/theme.dart';
import 'package:app/state/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SwapSidesButton extends ConsumerWidget {
  const SwapSidesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlight = ref.watch(matchProvider.select((s) {
      if (s.matchOver) return false;
      final total = s.scoreE1 + s.scoreE2;
      final every = s.format.regularChangeSideEvery;
      return total > 0 && every > 0 && total % every == 0;
    }));

    return AnimatedOpacity(
      opacity: highlight ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: highlight ? MH.ball.withValues(alpha: 0.12) : MH.paper,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: highlight ? MH.ball : MH.rule,
                width: highlight ? 1.5 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => ref.read(matchProvider.notifier).swapSides(),
                splashColor: MH.ball.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        size: 20,
                        color: highlight ? MH.ball : MH.ink,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Changer de côté',
                        style: MH.sans(
                          size: 15,
                          weight: FontWeight.w600,
                          color: highlight ? MH.ball : MH.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
