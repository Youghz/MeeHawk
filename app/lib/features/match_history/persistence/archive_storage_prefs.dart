import 'dart:async';
import 'dart:convert';

import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:app/features/match_history/persistence/archive_json.dart';
import 'package:app/features/match_history/persistence/archive_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ArchiveStorage> openArchiveStorage() => PrefsArchiveStorage.open();

/// Web backend: the whole archive list as one JSON string in
/// SharedPreferences (localStorage). No filesystem access on web, so this
/// is the only option there.
class PrefsArchiveStorage implements ArchiveStorage {
  PrefsArchiveStorage(this._prefs);

  static const _key = 'match_archives_v1';

  final SharedPreferences _prefs;
  final _controller = StreamController<List<MatchArchive>>.broadcast();

  /// First launch after the Firestore removal: seed local storage with the
  /// matches recovered from the old per-user Firestore archive, so history
  /// isn't empty for existing users. No-op once [_key] already has data.
  static Future<ArchiveStorage> open() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = PrefsArchiveStorage(prefs);
    if (!prefs.containsKey(_key)) {
      await storage._seedFromRecovered();
    }
    return storage;
  }

  Future<void> _seedFromRecovered() async {
    try {
      final raw =
          await rootBundle.loadString('assets/recovered_matches.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final archives =
          list.map((j) => archiveFromJson(j as Map<String, dynamic>)).toList();
      await _save(archives);
    } on Object {
      // No recovered-matches asset, or it's malformed — start empty.
    }
  }

  @override
  Stream<List<MatchArchive>> watchAll() {
    scheduleMicrotask(() => _controller.add(_loadAll()));
    return _controller.stream;
  }

  @override
  Future<void> upsert(MatchArchive archive) async {
    final all = _loadAll();
    final index = all.indexWhere((a) => a.id == archive.id);
    if (index >= 0) {
      all[index] = archive;
    } else {
      all.add(archive);
    }
    await _save(all);
  }

  @override
  Future<void> remove(String id) async {
    final all = _loadAll()..removeWhere((a) => a.id == id);
    await _save(all);
  }

  List<MatchArchive> _loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((j) => archiveFromJson(j as Map<String, dynamic>)).toList();
    } on Object {
      return [];
    }
  }

  Future<void> _save(List<MatchArchive> all) async {
    final json = jsonEncode(all.map(archiveToJson).toList());
    await _prefs.setString(_key, json);
    _controller.add(all);
  }
}
