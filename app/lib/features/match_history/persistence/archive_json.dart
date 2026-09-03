import 'package:app/features/match/persistence/match_codec.dart';
import 'package:app/features/match_history/domain/match_archive.dart';

/// Shared JSON shape for [MatchArchive], used by every ArchiveStorage
/// backend so a match written by one backend can be read back by another.
/// This is the exact schema `annotator/state.py::MatchCodec` mirrors on the
/// Python side — keep the two in sync.
Map<String, dynamic> archiveToJson(MatchArchive a) => {
      'id': a.id,
      'startedAt': a.startedAt.toIso8601String(),
      'state': MatchCodec.toJson(a.state),
      if (a.videoUrl != null) 'videoUrl': a.videoUrl,
    };

MatchArchive archiveFromJson(Map<String, dynamic> j) => MatchArchive(
      id: j['id'] as String,
      startedAt: DateTime.parse(j['startedAt'] as String),
      state: MatchCodec.fromJson(j['state'] as Map<String, dynamic>),
      videoUrl: j['videoUrl'] as String?,
    );
