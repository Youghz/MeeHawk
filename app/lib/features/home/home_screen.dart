import 'package:app/core/theme.dart';
import 'package:app/core/widgets/ball_icon.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/match_screen.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_history/screens/history_screen.dart';
import 'package:app/features/match_setup/match_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasOngoing = ref.watch(matchProvider.select(
      (s) => s.history.isNotEmpty && !s.matchOver,
    ));
    return Scaffold(
      backgroundColor: MH.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                const _Header(),
                const SizedBox(height: 40),
                if (hasOngoing) ...[
                  _ResumeCta(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MatchScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _PrimaryCta(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MatchSetupScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  'EXPLORER',
                  style: MH.mono(
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _MenuItem(
                  icon: Icons.history,
                  label: 'Historique des matchs',
                  subtitle: 'Revoir les matchs passés',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryScreen(),
                    ),
                  ),
                ),
                const _MenuItem(
                  icon: Icons.query_stats,
                  label: 'Statistiques',
                  subtitle: 'Performances sur la durée',
                ),
                const _MenuItem(
                  icon: Icons.groups_outlined,
                  label: 'Équipes & joueurs',
                  subtitle: 'Gérer les rosters',
                ),
                const _MenuItem(
                  icon: Icons.tune,
                  label: 'Paramètres',
                  subtitle: "Préférences de l'application",
                ),
                const SizedBox(height: 28),
                const _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MH.ballSoft,
              shape: BoxShape.circle,
              border: Border.all(color: MH.ball, width: 1.5),
            ),
            child: const BallIcon(size: 38),
          ),
          const SizedBox(height: 14),
          Text(
            'MeeHawk',
            style: MH.sans(
              size: 36,
              weight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Beach volley — scoring live',
            style: MH.sans(
              size: 13,
              color: MH.pencil,
              letterSpacing: 0.4,
            ),
          ),
        ],
      );
}

class _ResumeCta extends ConsumerWidget {
  const _ResumeCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(matchProvider.select((s) => s.teams));
    final scoreE1 = ref.watch(matchProvider.select((s) => s.scoreE1));
    final scoreE2 = ref.watch(matchProvider.select((s) => s.scoreE2));
    final setNumber = ref.watch(matchProvider.select((s) => s.setNumber));
    final setsE1 = ref.watch(
      matchProvider.select((s) => s.setsWonOf(TeamSide.e1)),
    );
    final setsE2 = ref.watch(
      matchProvider.select((s) => s.setsWonOf(TeamSide.e2)),
    );
    final name1 = teams[TeamSide.e1]!.name;
    final name2 = teams[TeamSide.e2]!.name;

    return Material(
      color: MH.sand,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: MH.ink,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.play_arrow, size: 20, color: MH.paper),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reprendre le match',
                      style: MH.sans(
                        size: 15,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$name1 $scoreE1 · $scoreE2 $name2  ·  set $setNumber ($setsE1-$setsE2)',
                      style: MH.sans(size: 11, color: MH.pencil),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 16, color: MH.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: MH.ink,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: MH.paper.withValues(alpha: 0.08),
          splashColor: MH.paper.withValues(alpha: 0.14),
          highlightColor: MH.paper.withValues(alpha: 0.10),
          child: Padding(
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
                  child: const Icon(Icons.add, size: 22, color: MH.paper),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nouvelle partie',
                        style: MH.sans(
                          size: 17,
                          weight: FontWeight.w700,
                          color: MH.paper,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Configurer et démarrer l'annotation",
                        style: MH.sans(
                          size: 12,
                          color: MH.paper.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: MH.paper.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  void _showSoon(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MH.ink,
        content: Text(
          'Bientôt disponible',
          style: MH.sans(size: 13, color: MH.paper),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: MH.paper,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap ?? () => _showSoon(context),
            hoverColor: MH.ink.withValues(alpha: 0.04),
            splashColor: MH.ink.withValues(alpha: 0.10),
            highlightColor: MH.ink.withValues(alpha: 0.06),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: MH.rule, width: 1.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MH.sand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: MH.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: MH.sans(
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: MH.sans(size: 12, color: MH.pencil),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: MH.pencil,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'MeeHawk · v0.1',
          style: MH.mono(color: MH.rule),
        ),
      );
}
