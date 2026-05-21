import 'package:app/features/match/persistence/match_codec.dart';
import 'package:app/features/match_history/domain/match_archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArchiveStorage {
  ArchiveStorage({required this.uid})
      : _db = FirebaseFirestore.instance;

  static const _collection = 'matches';
  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('users').doc(uid).collection(_collection);

  Stream<List<MatchArchive>> watchAll() => _ref
      .orderBy('startedAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => _fromJson(d.data())).toList(),
      );

  Future<void> upsert(MatchArchive archive) {
    if (uid.isEmpty) return Future.value();
    return _ref.doc(archive.id).set(_toJson(archive));
  }

  Future<void> remove(String id) {
    if (uid.isEmpty) return Future.value();
    return _ref.doc(id).delete();
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
