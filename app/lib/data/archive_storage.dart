import 'package:app/data/archive_storage_prefs.dart'
    if (dart.library.io) 'package:app/data/archive_storage_file.dart'
    as impl;
import 'package:app/domain/match_archive.dart';

/// Persists the list of archived matches to device storage. Local-only —
/// no auth, no network.
///
/// Two backends, picked at compile time:
/// - Web: PrefsArchiveStorage (SharedPreferences/localStorage).
/// - Everywhere else (desktop, mobile): FileArchiveStorage, one real
///   `.json` file per match under `match_history/` at the repo root — so a
///   local Python agent can read the exact same match archives to verify
///   its own output, without any API layer in between.
abstract class ArchiveStorage {
  Stream<List<MatchArchive>> watchAll();
  Future<void> upsert(MatchArchive archive);
  Future<void> remove(String id);

  static Future<ArchiveStorage> open() => impl.openArchiveStorage();
}
