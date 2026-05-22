import 'package:cloud_firestore/cloud_firestore.dart';

class AnnotationJob {
  const AnnotationJob({
    required this.id,
    required this.status,
    required this.progress,
    required this.message,
    required this.startedAt,
    this.videoUrl,
  });

  factory AnnotationJob.fromJson(String id, Map<String, dynamic> j) =>
      AnnotationJob(
        id: id,
        status: j['status'] as String? ?? 'analyzing',
        progress: (j['progress'] as num?)?.toDouble() ?? 0.0,
        message: j['message'] as String? ?? '',
        startedAt: switch (j['startedAt']) {
          final Timestamp t => t.toDate(),
          final String s => DateTime.parse(s),
          _ => DateTime.now(),
        },
        videoUrl: j['videoUrl'] as String?,
      );

  final String id;

  /// 'analyzing' | 'annotating' | 'importing' | 'done' | 'error'
  final String status;

  /// 0.0 → 1.0
  final double progress;

  final String message;
  final DateTime startedAt;
  final String? videoUrl;

  bool get isActive => status != 'done' && status != 'error';
}
