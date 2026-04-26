import 'package:app/core/theme.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match/widgets/court.dart';
import 'package:app/features/match/widgets/match_notes.dart';
import 'package:app/features/match/widgets/replay_panel.dart';
import 'package:app/features/match/widgets/timeline.dart';
import 'package:app/features/match/widgets/top_score.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/providers/replay_notifier.dart';
import 'package:app/features/match_history/screens/analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ReplayContent extends ConsumerStatefulWidget {
  const _ReplayContent({required this.archive});
  final MatchArchive archive;

  @override
  ConsumerState<_ReplayContent> createState() => _ReplayContentState();
}

class _ReplayContentState extends ConsumerState<_ReplayContent> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _navigate(int delta) {
    final s = ref.read(matchProvider);
    final total = s.history.length;
    if (total == 0) return;
    final current = s.selectedPointIndex;
    final next = current == null
        ? (delta > 0 ? 0 : total - 1)
        : (current + delta).clamp(0, total - 1);
    ref.read(matchProvider.notifier).selectPoint(next);
  }

  @override
  Widget build(BuildContext context) {
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
              _formatDate(widget.archive.startedAt),
              style: MH.mono(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Analyse',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AnalyticsScreen(state: widget.archive.state),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Accueil',
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _navigate(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _navigate(-1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () {
            ref.read(matchProvider.notifier).clearRally();
            ref.read(matchProvider.notifier).clearSelection();
          },
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 200) {
              _navigate(1);
            } else if (v < -200) {
              _navigate(-1);
            }
          },
          behavior: HitTestBehavior.translucent,
          child: const _ReplayLayout(),
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
