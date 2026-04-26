import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final archiveStorageProvider = Provider<ArchiveStorage>((ref) {
  throw StateError('archiveStorageProvider must be overridden in main()');
});

final archiveListProvider =
    NotifierProvider<ArchiveListNotifier, List<MatchArchive>>(
  ArchiveListNotifier.new,
);

class ArchiveListNotifier extends Notifier<List<MatchArchive>> {
  @override
  List<MatchArchive> build() {
    return ref.watch(archiveStorageProvider).loadAll();
  }

  Future<void> upsert(MatchArchive archive) async {
    await ref.read(archiveStorageProvider).upsert(archive);
    state = ref.read(archiveStorageProvider).loadAll();
  }

  Future<void> add(MatchArchive archive) async {
    await ref.read(archiveStorageProvider).add(archive);
    state = ref.read(archiveStorageProvider).loadAll();
  }

  Future<void> remove(String id) async {
    await ref.read(archiveStorageProvider).remove(id);
    state = ref.read(archiveStorageProvider).loadAll();
  }
}
