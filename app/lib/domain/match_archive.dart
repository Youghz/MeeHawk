import 'package:app/domain/match_state.dart';

/// A finished or in-progress match, as stored in the history.
class MatchArchive {
  const MatchArchive({
    required this.id,
    required this.startedAt,
    required this.state,
    this.videoUrl,
  });

  /// Build an archive of [state], deriving its id from the match start time.
  factory MatchArchive.of(MatchState state, {String? videoUrl}) => MatchArchive(
        id: idFor(state.startedAt),
        startedAt: state.startedAt,
        state: state,
        videoUrl: videoUrl,
      );

  /// Stable id for the match that started at [startedAt].
  ///
  /// Derived from the timestamp rather than random, so re-saving the same
  /// match overwrites its archive instead of piling up duplicates.
  ///
  /// Mirrored by `annotator/importer.py::match_id_for` — the Python agent must
  /// produce the same id for the same match, or an imported annotation would
  /// land beside the human-scored one instead of replacing it.
  static String idFor(DateTime startedAt) {
    final stamp =
        startedAt.toIso8601String().replaceAll(RegExp('[-:.]|Z'), '');
    return 'match_$stamp';
  }

  final String id;
  final DateTime startedAt;
  final MatchState state;
  final String? videoUrl;

  MatchArchive copyWith({String? videoUrl}) => MatchArchive(
        id: id,
        startedAt: startedAt,
        state: state,
        videoUrl: videoUrl ?? this.videoUrl,
      );
}
