import 'dart:async';

import 'package:app/core/theme.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match/widgets/bottom_actions.dart';
import 'package:app/features/match/widgets/change_side_prompt.dart';
import 'package:app/features/match/widgets/court.dart';
import 'package:app/features/match/widgets/help_hint.dart';
import 'package:app/features/match/widgets/replay_panel.dart';
import 'package:app/features/match/widgets/serve_banner.dart';
import 'package:app/features/match/widgets/set_end_prompt.dart';
import 'package:app/features/match/widgets/swap_sides_button.dart';
import 'package:app/features/match/widgets/timeline.dart';
import 'package:app/features/match/widgets/top_score.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      unawaited(_autoSave());
    }
  }

  Future<void> _autoSave() async {
    final matchState = ref.read(matchProvider);
    if (!matchState.started) return;
    final archive = MatchArchive(
      id: 'match_${matchState.startedAt.millisecondsSinceEpoch}',
      startedAt: matchState.startedAt,
      state: matchState,
    );
    await ref.read(archiveListProvider.notifier).upsert(archive);
  }

  @override
  Widget build(BuildContext context) {
    final isReplay = ref.watch(
      matchProvider.select((s) => s.selectedPointIndex != null),
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_autoSave());
      },
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
                  const HelpHint(),
                  const ChangeSidePrompt(),
                  const SetEndPrompt(),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Material(
                      color: MH.sand,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                              Icons.home_outlined, color: MH.ink, size: 20),
                        ),
                      ),
                    ),
                  ),
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
                ],
              ),
            ),
          ),
          BottomActions(),
        ],
      );
}
