import 'dart:convert';

import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/persistence/match_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a [MatchState] snapshot to device storage. Single slot — the
/// app supports one active match at a time.
class MatchStorage {
  MatchStorage._(this._prefs);

  static const _key = 'match_state_v1';

  final SharedPreferences _prefs;

  static Future<MatchStorage> open() async {
    final prefs = await SharedPreferences.getInstance();
    return MatchStorage._(prefs);
  }

  /// Load a saved match, or null if nothing is stored (or the payload is
  /// corrupt). Decoding errors are swallowed rather than crash the app on
  /// launch — the worst case is the user starts a fresh match.
  MatchState? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MatchCodec.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(MatchState state) async {
    final json = jsonEncode(MatchCodec.toJson(state));
    await _prefs.setString(_key, json);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
