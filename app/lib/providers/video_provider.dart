import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_info.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider((_) => ApiService());

final selectedVideoIdProvider = NotifierProvider<SelectedVideoNotifier, String?>(
    SelectedVideoNotifier.new);

class SelectedVideoNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

// --- Videos ---

final videosProvider = NotifierProvider<VideosNotifier, List<VideoInfo>>(VideosNotifier.new);

class VideosNotifier extends Notifier<List<VideoInfo>> {
  Timer? _pollTimer;

  @override
  List<VideoInfo> build() {
    ref.onDispose(() => _pollTimer?.cancel());
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      state = await ref.read(apiServiceProvider).getVideos();
    } catch (_) {}
    _updatePolling();
  }

  Future<void> refresh() => _load();

  void _updatePolling() {
    final hasProcessing = state.any((v) => v.isProcessing);
    if (hasProcessing && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
    } else if (!hasProcessing && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }
}

// --- Jobs ---

final activeJobsProvider = NotifierProvider<JobsNotifier, List<JobInfo>>(JobsNotifier.new);

class JobsNotifier extends Notifier<List<JobInfo>> {
  Timer? _pollTimer;

  @override
  List<JobInfo> build() {
    ref.onDispose(() => _pollTimer?.cancel());
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      state = await ref.read(apiServiceProvider).getActiveJobs();
    } catch (_) {}
    _updatePolling();
  }

  Future<void> refresh() => _load();

  void _updatePolling() {
    final hasRunning = state.any((j) => j.isRunning);
    if (hasRunning && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
    } else if (!hasRunning && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }
}
