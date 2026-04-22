import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../theme.dart';
import '../widgets/bottom_actions.dart';
import '../widgets/change_side_prompt.dart';
import '../widgets/court.dart';
import '../widgets/help_hint.dart';
import '../widgets/match_notes.dart';
import '../widgets/replay_panel.dart';
import '../widgets/serve_banner.dart';
import '../widgets/swap_sides_button.dart';
import '../widgets/timeline.dart';
import '../widgets/top_score.dart';

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
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: const [
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
          const BottomActions(),
        ],
      );
}
