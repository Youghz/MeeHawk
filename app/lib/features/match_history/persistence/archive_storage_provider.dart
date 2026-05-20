import 'dart:async';

import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final archiveStorageProvider = Provider<ArchiveStorage>(
  (_) => ArchiveStorage(),
);

final archiveListProvider =
    NotifierProvider<ArchiveListNotifier, List<MatchArchive>>(
  ArchiveListNotifier.new,
);

class ArchiveListNotifier extends Notifier<List<MatchArchive>> {
  StreamSubscription<List<MatchArchive>>? _sub;

  @override
  List<MatchArchive> build() {
    final storage = ref.watch(archiveStorageProvider);
    unawaited(_sub?.cancel());
    _sub = storage.watchAll().listen((archives) => state = archives);
    ref.onDispose(() => unawaited(_sub?.cancel()));
    return [];
  }

  Future<void> upsert(MatchArchive archive) =>
      ref.read(archiveStorageProvider).upsert(archive);

  Future<void> remove(String id) =>
      ref.read(archiveStorageProvider).remove(id);
}
