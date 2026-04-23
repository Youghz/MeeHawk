import 'package:app/core/theme.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match/widgets/court.dart';
import 'package:app/features/match/widgets/match_notes.dart';
import 'package:app/features/match/widgets/replay_panel.dart';
import 'package:app/features/match/widgets/timeline.dart';
import 'package:app/features/match/widgets/top_score.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/providers/replay_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchReplayScreen extends StatelessWidget {
  const MatchReplayScreen({required this.archive, super.key});

  final MatchArchive archive;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        matchProvider.overrideWith(() => ReplayNotifier(archive.state)),
      ],
      child: _ReplayContent(archive: archive),
    );
  }
}

class _ReplayContent extends ConsumerWidget {
  const _ReplayContent({required this.archive});
  final MatchArchive archive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReplay = ref.watch(
      matchProvider.select((s) => s.selectedPointIndex != null),
    );

    return Scaffold(
      backgroundColor: MH.paper,
      appBar: AppBar(
        backgroundColor: MH.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MH.ink,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Replay',
              style: MH.sans(size: 16, weight: FontWeight.w700),
            ),
            Text(
              _formatDate(archive.startedAt),
              style: MH.mono(),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => ref.read(matchProvider.notifier).clearRally(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            const _ReplayLayout(),
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

class _ReplayLayout extends StatelessWidget {
  const _ReplayLayout();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
        child: Column(
          children: [
            TopScore(),
            Court(),
            Timeline(),
            ReplayPanel(),
            MatchNotes(),
            SizedBox(height: 24),
          ],
        ),
      );
}

String _formatDate(DateTime dt) {
  const months = [
    'jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  const days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  final weekday = days[dt.weekday - 1];
  final month = months[dt.month - 1];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$weekday ${dt.day} $month · ${h}h$m';
}
