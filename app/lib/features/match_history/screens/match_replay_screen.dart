import 'dart:async';

import 'package:app/core/theme.dart';
import 'package:app/core/widgets/court.dart';
import 'package:app/core/widgets/replay_panel.dart';
import 'package:app/core/widgets/timeline.dart';
import 'package:app/core/widgets/top_score.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_history/domain/date_format.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:app/features/match_history/providers/replay_notifier.dart';
import 'package:app/features/match_history/screens/analytics_screen.dart';
import 'package:app/features/match_history/widgets/match_notes.dart';
import 'package:app/features/match_history/widgets/video_player_widget.dart';
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
  late MatchArchive _archive;

  @override
  void initState() {
    super.initState();
    _archive = widget.archive;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _editVideoUrl() async {
    final ctrl = TextEditingController(text: _archive.videoUrl ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MH.sand,
        title: Text('URL vidéo', style: MH.sans(weight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: MH.mono(size: 13),
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: MH.mono(size: 13, color: MH.inkSoft),
            filled: true,
            fillColor: MH.paper,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: MH.sans(color: MH.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text('Enregistrer', style: MH.sans(color: MH.ball)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    final newUrl = result.isEmpty ? null : result;
    final updated = _archive.copyWith(videoUrl: newUrl);
    unawaited(
      ref.read(archiveListProvider.notifier).upsert(updated),
    );
    setState(() => _archive = updated);
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
              formatMatchDate(_archive.startedAt),
              style: MH.mono(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: _archive.videoUrl == null ? 'Attacher une vidéo' : 'Modifier la vidéo',
            onPressed: _editVideoUrl,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Analyse',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AnalyticsScreen(state: _archive.state),
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
          child: _ReplayLayout(videoUrl: _archive.videoUrl),
        ),
      ),
    );
  }
}

class _ReplayLayout extends StatelessWidget {
  const _ReplayLayout({this.videoUrl});

  final String? videoUrl;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(
          children: [
            if (videoUrl != null)
              VideoPlayerWidget(key: ValueKey(videoUrl), videoUrl: videoUrl!),
            const TopScore(),
            const Court(),
            const Timeline(),
            const ReplayPanel(),
            const MatchNotes(),
            const SizedBox(height: 24),
          ],
        ),
      );
}
