import 'package:app/core/theme.dart';
import 'package:app/features/home/home_screen.dart';
import 'package:app/features/match/persistence/match_storage_provider.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeeHawkApp extends ConsumerWidget {
  const MeeHawkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Autosave: mirror every match-state change to local storage.
    // Fire-and-forget; failures are non-fatal.
    ref.listen(matchProvider, (_, next) {
      ref.read(matchStorageProvider).save(next);
    });
    return MaterialApp(
      title: 'MeeHawk',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
