import 'dart:async';

import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The ArchiveStorage instance for the app. Must be overridden at startup
/// after SharedPreferences is opened.
final archiveStorageProvider = Provider<ArchiveStorage>((ref) {
  throw StateError('archiveStorageProvider must be overridden in main()');
});

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
