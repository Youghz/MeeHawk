import 'dart:async';

import 'package:app/core/theme.dart';
import 'package:app/features/home/home_screen.dart';
import 'package:app/features/match/persistence/match_storage_provider.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeeHawkApp extends ConsumerWidget {
  const MeeHawkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Autosave: mirror every match-state change to local storage.
    // Auto-archive: save completed matches to history when matchOver flips.
    ref.listen(matchProvider, (prev, next) {
      unawaited(ref.read(matchStorageProvider).save(next));
      if (!(prev?.matchOver ?? false) && next.matchOver) {
        final archive = MatchArchive(
          id: 'match_${next.startedAt.millisecondsSinceEpoch}',
          startedAt: next.startedAt,
          state: next,
        );
        unawaited(ref.read(archiveListProvider.notifier).add(archive));
      }
    });
    return MaterialApp(
      title: 'MeeHawk',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
