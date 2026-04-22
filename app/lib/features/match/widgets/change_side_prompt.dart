import 'package:app/core/theme.dart';
import 'package:app/core/widgets/ball_icon.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangeSidePrompt extends ConsumerWidget {
  const ChangeSidePrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open =
        ref.watch(matchProvider.select((s) => s.changeSidePromptOpen));
    if (!open) return const SizedBox.shrink();
    final total = ref.watch(
      matchProvider.select((s) => s.scoreE1 + s.scoreE2),
    );
    final notifier = ref.read(matchProvider.notifier);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: notifier.closeChangeSidePrompt,
        child: Container(
          color: const Color(0x8C141210),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(22),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              decoration: BoxDecoration(
                color: MH.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MH.ink, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
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
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: MH.ballSoft,
                      border: Border.all(color: MH.ball, width: 1.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BallIcon(size: 11),
                        const SizedBox(width: 6),
                        Text('$total POINTS JOUÉS',
                            style: MH.sans(
                              size: 10,
                              weight: FontWeight.w700,
                              color: MH.ball,
                              letterSpacing: 0.5,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Changement de côté ?',
                      style: MH.sans(
                        size: 18,
                        weight: FontWeight.w700,
                        height: 1.25,
                      )),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: notifier.swapSides,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MH.ink,
                        foregroundColor: MH.paper,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text('Changer de côté',
                          style: MH.sans(
                            size: 13,
                            weight: FontWeight.w700,
                            color: MH.paper,
                          )),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: notifier.dismissChangeSideForever,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: MH.inkSoft, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Ne pas changer de côté',
                          style: MH.sans(
                            size: 12,
                            weight: FontWeight.w600,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
