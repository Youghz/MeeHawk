import 'package:app/app.dart';
import 'package:app/features/match/persistence/match_storage.dart';
import 'package:app/features/match/persistence/match_storage_provider.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_history/persistence/archive_storage.dart';
import 'package:app/features/match_history/persistence/archive_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await MatchStorage.open();
  MatchNotifier.bootstrapState = storage.load();
  final archiveStorage = await ArchiveStorage.open();

  runApp(
    ProviderScope(
      overrides: [
        matchStorageProvider.overrideWithValue(storage),
        archiveStorageProvider.overrideWithValue(archiveStorage),
      ],
      child: const CrabCoachApp(),
    ),
  );
}
