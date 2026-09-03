import 'dart:async';

import 'package:app/core/theme.dart';
import 'package:app/features/home/home_screen.dart';
import 'package:app/features/match/persistence/match_storage_provider.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrabCoachApp extends ConsumerWidget {
  const CrabCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(matchProvider, (prev, next) {
      unawaited(ref.read(matchStorageProvider).save(next));
      if (next.started) {
        final archive = MatchArchive(
          id: 'match_${next.startedAt.toIso8601String().replaceAll(RegExp('[-:.]'), '').replaceAll('Z', '')}',
          startedAt: next.startedAt,
          state: next,
          videoUrl: ref.read(matchVideoUrlProvider),
        );
        unawaited(ref.read(archiveListProvider.notifier).upsert(archive));
      }
    });
    return MaterialApp(
      title: 'CrabCoach',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
