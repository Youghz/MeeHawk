import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_json.dart';
import 'package:app/features/match_history/persistence/archive_storage.dart';

Future<ArchiveStorage> openArchiveStorage() => FileArchiveStorage.open();

/// Desktop/mobile backend: one real `.json` file per match under
/// `match_history/` at the repo root — `<matchId>.json`. Deliberately a
/// plain shared folder instead of the OS app-documents directory: a local
/// Python agent (annotator/state.py::MatchCodec, kept schema-identical)
/// reads these same files directly to verify its own output against a
/// human-scored match, no API in between.
///
/// Resolves the repo root as one level above the current working
/// directory, matching every `flutter` command in this project
/// (`cd app && flutter ...`). Override with `MATCH_HISTORY_DIR` if you
/// invoke flutter from somewhere else.
class FileArchiveStorage implements ArchiveStorage {
  FileArchiveStorage(this._dir);

  final Directory _dir;
  final _controller = StreamController<List<MatchArchive>>.broadcast();

  /// [dir] overrides the resolved directory — used by tests. Runtime
  /// callers rely on the default (repo root, or `MATCH_HISTORY_DIR`).
  static Future<ArchiveStorage> open({Directory? dir}) async {
    final resolved = dir ?? _resolveDir();
    if (!resolved.existsSync()) {
      await resolved.create(recursive: true);
    }
    return FileArchiveStorage(resolved);
  }

  static Directory _resolveDir() {
    final override = Platform.environment['MATCH_HISTORY_DIR'];
    if (override != null && override.isNotEmpty) return Directory(override);
    return Directory('${Directory.current.parent.path}/match_history');
  }

  @override
  Stream<List<MatchArchive>> watchAll() {
    scheduleMicrotask(() => _controller.add(_loadAll()));
    return _controller.stream;
  }

  @override
  Future<void> upsert(MatchArchive archive) async {
    final file = File('${_dir.path}/${archive.id}.json');
    await file.writeAsString(jsonEncode(archiveToJson(archive)));
    _controller.add(_loadAll());
  }

  @override
  Future<void> remove(String id) async {
    final file = File('${_dir.path}/$id.json');
    if (file.existsSync()) await file.delete();
    _controller.add(_loadAll());
  }

  List<MatchArchive> _loadAll() {
    if (!_dir.existsSync()) return [];
    final archives = <MatchArchive>[];
    for (final entity in _dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
        archives.add(archiveFromJson(j));
      } on Object {
        // Skip a corrupt/partial file rather than fail the whole load.
      }
    }
    archives.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return archives;
  }
}
