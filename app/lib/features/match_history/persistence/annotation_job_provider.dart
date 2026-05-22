import 'dart:async';

import 'package:app/features/auth/auth_providers.dart';
import 'package:app/features/match_history/domain/annotation_job.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeJobsProvider =
    NotifierProvider<_ActiveJobsNotifier, List<AnnotationJob>>(
  _ActiveJobsNotifier.new,
);

class _ActiveJobsNotifier extends Notifier<List<AnnotationJob>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<AnnotationJob> build() {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    unawaited(_sub?.cancel());
    if (uid.isEmpty) return [];
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('jobs')
        .orderBy('startedAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snap) {
      state = snap.docs
          .map((d) => AnnotationJob.fromJson(d.id, d.data()))
          .where((j) => j.isActive)
          .toList();
    });
    ref.onDispose(() => unawaited(_sub?.cancel()));
    return [];
  }
}
