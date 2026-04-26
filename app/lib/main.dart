import 'package:app/app.dart';
import 'package:app/features/match/persistence/match_storage.dart';
import 'package:app/features/match/persistence/match_storage_provider.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_history/data/seed_matches.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await MatchStorage.open();
  final archiveStorage = await ArchiveStorage.open();

  // Rescue: if the current match state is a completed match that is not yet
  // in the archive (e.g. after a codec migration wiped the archive list),
  // add it back so the user doesn't lose their data.
  final currentMatch = storage.load();
  if (currentMatch != null && currentMatch.matchOver) {
    final archiveId = 'match_${currentMatch.startedAt.millisecondsSinceEpoch}';
    final archives = archiveStorage.loadAll();
    if (!archives.any((a) => a.id == archiveId)) {
      await archiveStorage.upsert(
        MatchArchive(
          id: archiveId,
          startedAt: currentMatch.startedAt,
          state: currentMatch,
        ),
      );
    }
  }

  // Seed fictitious matches on first launch — only when the archive is truly
  // empty and there is no current in-progress match either.
  final hasRealData = currentMatch != null &&
      (currentMatch.history.isNotEmpty || currentMatch.sets.isNotEmpty);
  if (archiveStorage.isEmpty && !hasRealData) {
    await archiveStorage.saveAll(buildSeedMatches());
  }

  MatchNotifier.bootstrapState = currentMatch;
  runApp(
    ProviderScope(
      overrides: [
        matchStorageProvider.overrideWithValue(storage),
        archiveStorageProvider.overrideWithValue(archiveStorage),
      ],
      child: const MeeHawkApp(),
    ),
  );
}
