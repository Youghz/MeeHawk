import 'package:app/features/match/persistence/match_codec.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArchiveStorage {
  ArchiveStorage() : _db = FirebaseFirestore.instance;

  static const _collection = 'matches';
  final FirebaseFirestore _db;

  Stream<List<MatchArchive>> watchAll() => _db
      .collection(_collection)
      .orderBy('startedAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => _fromJson(d.data())).toList(),
      );

  Future<void> upsert(MatchArchive archive) =>
      _db.collection(_collection).doc(archive.id).set(_toJson(archive));

  Future<void> remove(String id) =>
      _db.collection(_collection).doc(id).delete();

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
