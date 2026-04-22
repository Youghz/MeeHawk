import 'package:app/core/theme.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SwapSidesButton extends ConsumerWidget {
  const SwapSidesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.read(matchProvider.notifier).swapSides(),
            icon: const Icon(Icons.swap_horiz, size: 14, color: MH.ink),
            label: Text('Changer de côté',
                style: MH.sans(
                  size: 11,
                  weight: FontWeight.w600,
                )),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              side: const BorderSide(color: MH.ink, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              backgroundColor: MH.paper,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      );
}
