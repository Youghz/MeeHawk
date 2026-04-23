import 'dart:convert';

import 'package:app/features/match/persistence/match_codec.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArchiveStorage {
  ArchiveStorage._(this._prefs);

  static const _key = 'match_archives_v4';
  final SharedPreferences _prefs;

  static Future<ArchiveStorage> open() async {
    final prefs = await SharedPreferences.getInstance();
    return ArchiveStorage._(prefs);
  }

  List<MatchArchive> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
    } on Exception catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<MatchArchive> archives) async {
    final json = jsonEncode(archives.map(_toJson).toList());
    await _prefs.setString(_key, json);
  }

  Future<void> add(MatchArchive archive) async {
    await saveAll(loadAll()..insert(0, archive));
  }

  Future<void> remove(String id) async {
    await saveAll(loadAll()..removeWhere((a) => a.id == id));
  }

  bool get isEmpty => loadAll().isEmpty;

  static Map<String, dynamic> _toJson(MatchArchive a) => {
        'id': a.id,
        'startedAt': a.startedAt.toIso8601String(),
        'state': MatchCodec.toJson(a.state),
      };

  static MatchArchive _fromJson(Map<String, dynamic> j) => MatchArchive(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        state: MatchCodec.fromJson(j['state'] as Map<String, dynamic>),
      );
}
