import 'package:app/core/theme.dart';
import 'package:app/features/home/widgets/home_header.dart';
import 'package:app/features/home/widgets/nav_card.dart';
import 'package:app/features/home/widgets/new_match_cta.dart';
import 'package:app/features/home/widgets/ongoing_card.dart';
import 'package:app/features/home/widgets/recent_match_card.dart';
import 'package:app/features/home/widgets/section_label.dart';
import 'package:app/features/match_history/screens/history_screen.dart';
import 'package:app/features/match_setup/match_setup_screen.dart';
import 'package:app/state/archive_provider.dart';
import 'package:app/state/match_provider.dart';
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
    final recentMatches = ref.watch(archiveListProvider.select(
      (list) => list
          .where((a) => a.state.matchOver)
          .take(3)
          .toList(),
    ));
    final currentMatchId = ref.watch(
      matchProvider.select(
        (s) => 'match_${s.startedAt.toIso8601String().replaceAll(RegExp('[-:.]'), '').replaceAll('Z', '')}',
      ),
    );

    return Scaffold(
      backgroundColor: MH.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const HomeHeader(),
            const SizedBox(height: 14),
            NewMatchCta(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MatchSetupScreen(),
                ),
              ),
            ),
            if (ongoingMatches.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionLabel(label: 'EN COURS'),
              const SizedBox(height: 10),
              for (final archive in ongoingMatches) ...[
                OngoingCard(
                  archive: archive,
                  isCurrent: archive.id == currentMatchId,
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (recentMatches.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionLabel(label: 'RÉCENTS'),
              const SizedBox(height: 10),
              for (final archive in recentMatches) ...[
                RecentMatchCard(archive: archive),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 24),
            NavCard(
              children: [
                NavMenuItem(
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
                const NavMenuItem(
                  icon: Icons.query_stats_rounded,
                  label: 'Statistiques',
                  subtitle: 'Performances sur la durée',
                  iconColor: MH.them,
                  enabled: false,
                ),
                const NavMenuItem(
                  icon: Icons.groups_rounded,
                  label: 'Équipes & joueurs',
                  subtitle: 'Gérer les rosters',
                  iconColor: MH.us,
                  enabled: false,
                ),
                const NavMenuItem(
                  icon: Icons.tune_rounded,
                  label: 'Paramètres',
                  subtitle: "Préférences de l'application",
                  iconColor: MH.pencil,
                  enabled: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
