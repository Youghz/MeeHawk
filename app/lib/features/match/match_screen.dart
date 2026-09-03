import 'package:app/core/theme.dart';
import 'package:app/core/widgets/court/court.dart';
import 'package:app/core/widgets/replay_panel.dart';
import 'package:app/core/widgets/timeline.dart';
import 'package:app/core/widgets/top_score.dart';
import 'package:app/features/match/widgets/bottom_actions.dart';
import 'package:app/features/match/widgets/change_side_prompt.dart';
import 'package:app/features/match/widgets/help_hint.dart';
import 'package:app/features/match/widgets/serve_banner.dart';
import 'package:app/features/match/widgets/set_end_prompt.dart';
import 'package:app/features/match/widgets/swap_sides_button.dart';
import 'package:app/features/match_history/screens/analytics_screen.dart';
import 'package:app/state/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReplay = ref.watch(
      matchProvider.select((s) => s.selectedPointIndex != null),
    );
    return PopScope(
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final s = ref.read(matchProvider);
          final notifier = ref.read(matchProvider.notifier);
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (s.history.isEmpty) return KeyEventResult.handled;
            if (s.selectedPointIndex == null) {
              notifier.selectPoint(s.history.length - 1);
            } else if (s.selectedPointIndex! > 0) {
              notifier.selectPoint(s.selectedPointIndex! - 1);
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final idx = s.selectedPointIndex;
            if (idx == null) return KeyEventResult.handled;
            if (idx >= s.history.length - 1) {
              notifier.clearSelection();
            } else {
              notifier.selectPoint(idx + 1);
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: MH.paper,
          body: GestureDetector(
            onTap: () => ref.read(matchProvider.notifier).clearRally(),
            behavior: HitTestBehavior.translucent,
            child: SafeArea(
              child: Stack(
                children: [
                  const _MatchLayout(),
                  const ChangeSidePrompt(),
                  const SetEndPrompt(),
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
          ),
        ),
      ),
    );
  }
}

class _MatchLayout extends ConsumerStatefulWidget {
  const _MatchLayout();

  @override
  ConsumerState<_MatchLayout> createState() => _MatchLayoutState();
}

class _MatchLayoutState extends ConsumerState<_MatchLayout> {
  bool _helpOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: MH.sand,
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_rounded, color: MH.ink, size: 22),
                  ),
                ),
              ),
              const Spacer(),
              Consumer(
                builder: (context, ref, _) {
                  final hasPoints = ref.watch(
                    matchProvider.select((s) => s.history.isNotEmpty),
                  );
                  if (!hasPoints) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.bar_chart_rounded, color: MH.inkSoft, size: 22),
                    onPressed: () {
                      final state = ref.read(matchProvider);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AnalyticsScreen(state: state),
                        ),
                      );
                    },
                  );
                },
              ),
              GestureDetector(
                onTap: () => setState(() => _helpOpen = !_helpOpen),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _helpOpen
                        ? MH.ink
                        : MH.paper.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: MH.rule),
                  ),
                  child: Text(
                    'Aide',
                    style: MH.sans(
                      size: 13,
                      weight: FontWeight.w700,
                      color: _helpOpen ? MH.paper : MH.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_helpOpen) const HelpPanel(),
        const Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                TopScore(),
                ServeBanner(),
                Court(),
                SwapSidesButton(),
                Timeline(),
                ReplayPanel(),
              ],
            ),
          ),
        ),
        const BottomActions(),
      ],
    );
  }
}
