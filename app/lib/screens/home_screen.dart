import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/ball_icon.dart';
import 'match_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  _PrimaryCta(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MatchSetupScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'EXPLORER',
                    style: MH.mono(
                      size: 10,
                      color: MH.pencil,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MenuItem(
                    icon: Icons.history,
                    label: 'Historique des matchs',
                    subtitle: 'Revoir les matchs passés',
                  ),
                  _MenuItem(
                    icon: Icons.query_stats,
                    label: 'Statistiques',
                    subtitle: 'Performances sur la durée',
                  ),
                  _MenuItem(
                    icon: Icons.groups_outlined,
                    label: 'Équipes & joueurs',
                    subtitle: 'Gérer les rosters',
                  ),
                  _MenuItem(
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
              color: MH.ink,
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

class _PrimaryCta extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryCta({required this.onTap});

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
  final IconData icon;
  final String label;
  final String subtitle;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

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
            onTap: () => _showSoon(context),
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
                            size: 14,
                            weight: FontWeight.w600,
                            color: MH.ink,
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
          style: MH.mono(size: 10, color: MH.rule, letterSpacing: 1),
        ),
      );
}
