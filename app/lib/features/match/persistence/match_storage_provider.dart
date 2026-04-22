import 'package:app/features/match/persistence/match_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The MatchStorage instance for the app. Must be overridden at startup
/// after SharedPreferences is opened.
final matchStorageProvider = Provider<MatchStorage>((ref) {
  throw StateError('matchStorageProvider must be overridden in main()');
});
