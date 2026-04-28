import 'dart:async';

import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/match_screen.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:app/features/match_history/screens/history_screen.dart';
import 'package:app/features/match_setup/match_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ongoingMatches = ref.watch(archiveListProvider.select(
      (list) => list
          .where((a) => a.state.started && !a.state.matchOver)
          .toList(),
    ));
    final currentMatchId = ref.watch(
      matchProvider.select(
          (s) => 'match_${s.startedAt.millisecondsSinceEpoch}'),
    );

    return Scaffold(
      backgroundColor: MH.paper,
      body: SafeArea(
        child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const _Header(),
                const SizedBox(height: 10),
                _PrimaryCta(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MatchSetupScreen(),
                    ),
                  ),
                ),
                if (ongoingMatches.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionLabel(label: 'EN COURS'),
                  const SizedBox(height: 8),
                  for (final archive in ongoingMatches) ...[
                    _OngoingCard(
                      archive: archive,
                      isCurrent: archive.id == currentMatchId,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 16),
                const _SectionLabel(label: 'NAVIGATION'),
                const SizedBox(height: 8),
                _NavCard(
                  children: [
                    _MenuItem(
                      icon: Icons.history_rounded,
                      label: 'Historique des matchs',
                      subtitle: 'Revoir les matchs passés',
                      iconColor: MH.ball,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HistoryScreen(),
                        ),
                      ),
                    ),
                    const _MenuItem(
                      icon: Icons.query_stats_rounded,
                      label: 'Statistiques',
                      subtitle: 'Performances sur la durée',
                      iconColor: MH.them,
                    ),
                    const _MenuItem(
                      icon: Icons.groups_rounded,
                      label: 'Équipes & joueurs',
                      subtitle: 'Gérer les rosters',
                      iconColor: MH.us,
                    ),
                    const _MenuItem(
                      icon: Icons.tune_rounded,
                      label: 'Paramètres',
                      subtitle: "Préférences de l'application",
                      iconColor: MH.pencil,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _Footer(),
              ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            'MEEHAWK',
            style: MH.sans(
              size: 30,
              weight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Text(
            'v0.1',
            style: MH.mono(
              size: 9,
              color: MH.rule,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3,
            height: 11,
            decoration: BoxDecoration(
              color: MH.ball,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: MH.mono(
              size: 9,
              weight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _OngoingCard extends ConsumerWidget {
  const _OngoingCard({
    required this.archive,
    required this.isCurrent,
  });

  final MatchArchive archive;
  final bool isCurrent;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(archiveListProvider.notifier).remove(archive.id);
    if (isCurrent) ref.read(matchProvider.notifier).resetMatch();
  }

  void _resume(BuildContext context, WidgetRef ref) {
    if (!isCurrent) ref.read(matchProvider.notifier).resumeMatch(archive.state);
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MatchScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = archive.state;
    final name1 = s.teams[TeamSide.e1]!.name;
    final name2 = s.teams[TeamSide.e2]!.name;
    final setsE1 = s.setsWonOf(TeamSide.e1);
    final setsE2 = s.setsWonOf(TeamSide.e2);

    return Material(
      color: MH.sand,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _resume(context, ref),
        splashColor: MH.ball.withValues(alpha: 0.10),
        highlightColor: MH.ball.withValues(alpha: 0.06),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: MH.ball, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: MH.ball,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Reprendre le match',
                        style: MH.sans(size: 13, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$name1 ${s.scoreE1} – ${s.scoreE2} $name2'
                        '  ·  set ${s.setNumber} ($setsE1–$setsE2)',
                        style: MH.mono(letterSpacing: 0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: MH.pencil,
                  ),
                  onPressed: () async { await _delete(context, ref); },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: MH.sand,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: MH.ball.withValues(alpha: 0.10),
          highlightColor: MH.ball.withValues(alpha: 0.06),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: MH.ball.withValues(alpha: 0.40),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: MH.ball,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NOUVELLE PARTIE',
                        style: MH.sans(
                          weight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Configurer et démarrer l'annotation",
                        style: MH.sans(size: 11, color: MH.pencil),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: MH.ball,
                ),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  const _NavCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: MH.sand,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MH.rule),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: MH.rule),
                children[i],
              ],
            ],
          ),
        ),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback? onTap;

  void _showSoon(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MH.sand,
        content: Text(
          'Bientôt disponible',
          style: MH.sans(size: 13),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => _showSoon(context),
          splashColor: MH.ink.withValues(alpha: 0.14),
          highlightColor: MH.ink.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: MH.sans(size: 13, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: MH.sans(size: 11, color: MH.pencil),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: MH.pencil,
                ),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'MEEHAWK · v0.1',
          style: MH.mono(
            size: 9,
            color: MH.rule,
          ),
        ),
      );
}
