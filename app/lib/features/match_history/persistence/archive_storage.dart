import 'dart:async';
import 'dart:convert';

import 'package:app/features/match/persistence/match_codec.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the list of archived matches to device storage. Local-only —
/// no auth, no network.
class ArchiveStorage {
  ArchiveStorage(this._prefs);

  static const _key = 'match_archives_v1';

  final SharedPreferences _prefs;
  final _controller = StreamController<List<MatchArchive>>.broadcast();

  static Future<ArchiveStorage> open() async {
    final prefs = await SharedPreferences.getInstance();
    return ArchiveStorage(prefs);
  }

  /// Emits the current list immediately, then again after every write.
  Stream<List<MatchArchive>> watchAll() {
    scheduleMicrotask(() => _controller.add(_loadAll()));
    return _controller.stream;
  }

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

  Future<void> remove(String id) async {
    final all = _loadAll()..removeWhere((a) => a.id == id);
    await _save(all);
  }

  List<MatchArchive> _loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((j) => _fromJson(j as Map<String, dynamic>)).toList();
    } on Object {
      return [];
    }
  }

  Future<void> _save(List<MatchArchive> all) async {
    final json = jsonEncode(all.map(_toJson).toList());
    await _prefs.setString(_key, json);
    _controller.add(all);
  }

  static Map<String, dynamic> _toJson(MatchArchive a) => {
        'id': a.id,
        'startedAt': a.startedAt.toIso8601String(),
        'state': MatchCodec.toJson(a.state),
        if (a.videoUrl != null) 'videoUrl': a.videoUrl,
      };

  static MatchArchive _fromJson(Map<String, dynamic> j) => MatchArchive(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        state: MatchCodec.fromJson(j['state'] as Map<String, dynamic>),
        videoUrl: j['videoUrl'] as String?,
      );
}
