import 'package:app/app.dart';
import 'package:app/data/archive_storage.dart';
import 'package:app/data/match_storage.dart';
import 'package:app/state/archive_provider.dart';
import 'package:app/state/match_provider.dart';
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
