import 'dart:async';

import 'package:app/core/theme.dart';
import 'package:app/domain/match_archive.dart';
import 'package:app/features/home/home_screen.dart';
import 'package:app/state/archive_provider.dart';
import 'package:app/state/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrabCoachApp extends ConsumerWidget {
  const CrabCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Single source of persistence for the whole app. Screens must not save
    // on their own lifecycle callbacks — that is how duplicate writes creep in.
    ref.listen(matchProvider, (previous, next) {
      // Opening a popup or selecting a timeline point changes the state but
      // not what gets stored. Skipping those keeps a live match at one write
      // per scoring action instead of one per tap.
      if (previous != null && next.hasSamePersistedStateAs(previous)) return;

      unawaited(ref.read(matchStorageProvider).save(next));
      if (!next.started) return;

      unawaited(
        ref.read(archiveListProvider.notifier).upsert(
              MatchArchive.of(next, videoUrl: ref.read(matchVideoUrlProvider)),
            ),
      );
    });

    return MaterialApp(
      title: 'CrabCoach',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
