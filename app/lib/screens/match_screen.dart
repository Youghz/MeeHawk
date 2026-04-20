import 'package:flutter/material.dart';
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

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MH.paper,
        body: SafeArea(
          child: Stack(
            children: const [
              _MatchColumn(),
              HelpHint(),
              ChangeSidePrompt(),
            ],
          ),
        ),
      );
}

class _MatchColumn extends StatelessWidget {
  const _MatchColumn();

  @override
  Widget build(BuildContext context) => Column(
        children: const [
          TopScore(),
          ServeBanner(),
          Court(),
          SwapSidesButton(),
          Timeline(),
          ReplayPanel(),
          MatchNotes(),
          Spacer(),
          BottomActions(),
        ],
      );
}
