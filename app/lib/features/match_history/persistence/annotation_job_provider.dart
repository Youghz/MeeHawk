import 'package:app/features/match_history/domain/annotation_job.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jobs d'annotation vidéo en cours. Sans backend distant en local, il n'y
/// en a jamais — ce provider garde l'interface utilisée par HistoryScreen
/// stable pour quand le traitement vidéo sera reconnecté (branche
/// feature/video-analysis).
final activeJobsProvider = Provider<List<AnnotationJob>>((ref) => []);
