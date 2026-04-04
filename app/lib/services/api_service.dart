import 'package:dio/dio.dart';
import '../models/video_info.dart';
import '../models/tracking_data.dart';

class ApiService {
  static const _baseUrl = 'http://localhost:8000/api';
  final _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  // --- Videos ---

  Future<List<VideoInfo>> getVideos() async {
    final resp = await _dio.get('/videos');
    return (resp.data['videos'] as List).map((v) => VideoInfo.fromJson(v)).toList();
  }

  Future<Map<String, dynamic>> getVideo(String videoId) async {
    final resp = await _dio.get('/videos/$videoId');
    return resp.data;
  }

  Future<Map<String, dynamic>> uploadVideo(
    String filePath,
    String fileName, {
    void Function(int, int)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final resp = await _dio.post('/videos/upload', data: formData,
        onSendProgress: onProgress);
    return resp.data;
  }

  Future<Map<String, dynamic>> uploadYoutube(String url) async {
    final resp = await _dio.post('/videos/upload/youtube', data: {'url': url});
    return resp.data;
  }

  Future<void> deleteVideo(String videoId) async {
    await _dio.delete('/videos/$videoId');
  }

  Future<void> clearAnnotations(String videoId) async {
    await _dio.delete('/videos/$videoId/annotations');
  }

  // --- Analysis ---

  Future<void> analyzeVideo(String videoId) async {
    await _dio.post('/videos/$videoId/analyze');
  }

  Future<void> cancelProcessing(String videoId) async {
    await _dio.post('/videos/$videoId/cancel');
  }

  Future<void> detectPoints(String videoId) async {
    await _dio.post('/videos/$videoId/detect-points');
  }

  String getSourceVideoUrl(String videoId) => '$_baseUrl/videos/$videoId/source';

  String getPointVideoUrl(String videoId, int pointId) =>
      '$_baseUrl/videos/$videoId/points/$pointId/video';

  // --- Tracking ---

  Future<TrackingData> getTrackingData(String videoId) async {
    final resp = await _dio.get('/videos/$videoId/result/data');
    return TrackingData.fromJson(resp.data);
  }

  // --- Corrections ---

  Future<void> saveFrameCorrection(
    String videoId, {
    required int frameNumber,
    Map<String, int>? idSwaps,
    List<int>? removedIds,
  }) async {
    await _dio.post('/videos/$videoId/corrections/frame', data: {
      'frame_number': frameNumber,
      'id_swaps': idSwaps ?? {},
      'removed_ids': removedIds ?? [],
    });
  }

  // --- Jobs ---

  Future<List<JobInfo>> getActiveJobs() async {
    final resp = await _dio.get('/videos/jobs/active');
    return (resp.data['jobs'] as List).map((j) => JobInfo.fromJson(j)).toList();
  }
}
