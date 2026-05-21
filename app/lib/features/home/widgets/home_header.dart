import 'package:app/core/theme.dart';
import 'package:app/features/auth/auth_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Row(
      children: [
        Expanded(
          child: Text(
            'CRABCOACH',
            style: MH.sans(
              size: 36,
              weight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (user != null)
          _UserAvatar(
            photoUrl: user.photoURL,
            onSignOut: () => FirebaseAuth.instance.signOut(),
          ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.photoUrl, required this.onSignOut});

  final String? photoUrl;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Compte',
      color: MH.sand,
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (value == 'signout') onSignOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 16, color: MH.inkSoft),
              const SizedBox(width: 8),
              Text('Déconnexion', style: MH.sans(color: MH.inkSoft)),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 16,
        backgroundColor: MH.rule,
        backgroundImage:
            photoUrl != null ? NetworkImage(photoUrl!) : null,
        child: photoUrl == null
            ? const Icon(Icons.person_rounded, size: 16, color: MH.inkSoft)
            : null,
      ),
    );
  }
}
