import 'package:app/core/theme.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match/widgets/bottom_actions.dart';
import 'package:app/features/match/widgets/change_side_prompt.dart';
import 'package:app/features/match/widgets/court.dart';
import 'package:app/features/match/widgets/help_hint.dart';
import 'package:app/features/match/widgets/match_notes.dart';
import 'package:app/features/match/widgets/replay_panel.dart';
import 'package:app/features/match/widgets/serve_banner.dart';
import 'package:app/features/match/widgets/set_end_prompt.dart';
import 'package:app/features/match/widgets/swap_sides_button.dart';
import 'package:app/features/match/widgets/timeline.dart';
import 'package:app/features/match/widgets/top_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReplay = ref.watch(
      matchProvider.select((s) => s.selectedPointIndex != null),
    );
    return Scaffold(
      backgroundColor: MH.paper,
      body: SafeArea(
        child: Stack(
          children: [
            const _MatchLayout(),
            const HelpHint(),
            const ChangeSidePrompt(),
            const SetEndPrompt(),
            // Full-screen raw pointer listener in replay mode: any pointer
            // down anywhere in the app exits the replay. Uses Listener
            // (not GestureDetector) with translucent hit-test so the tap
            // still propagates to the widget below — the gesture then
            // fires in live mode.
            if (isReplay)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) =>
                      ref.read(matchProvider.notifier).clearSelection(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchLayout extends StatelessWidget {
  const _MatchLayout();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TopScore(),
                  ServeBanner(),
                  Court(),
                  SwapSidesButton(),
                  Timeline(),
                  ReplayPanel(),
                  MatchNotes(),
                ],
              ),
            ),
          ),
          BottomActions(),
        ],
      );
}
