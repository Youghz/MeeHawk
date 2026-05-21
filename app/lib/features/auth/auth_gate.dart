import 'package:app/core/theme.dart';
import 'package:app/features/auth/auth_providers.dart';
import 'package:app/features/auth/sign_in_screen.dart';
import 'package:app/features/home/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kDebugMode) return const HomeScreen();

    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const _SplashScreen(),
      error: (_, _) => const SignInScreen(),
      data: (user) =>
          user != null ? const HomeScreen() : const SignInScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: MH.paper,
      body: Center(
        child: CircularProgressIndicator(color: MH.ball),
      ),
    );
  }
}
