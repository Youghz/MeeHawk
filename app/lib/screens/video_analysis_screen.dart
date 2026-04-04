import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/video_info.dart';
import '../providers/video_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/video_library.dart';
import '../widgets/video_uploader.dart';

class VideoAnalysisScreen extends ConsumerWidget {
  const VideoAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedVideoIdProvider);
    final videos = ref.watch(videosProvider);

    VideoInfo? selectedVideo;
    if (selectedId != null) {
      try {
        selectedVideo = videos.firstWhere((v) => v.videoId == selectedId);
      } catch (_) {}
    }

    return Row(
      children: [
        // Sidebar
        SizedBox(
          width: 280,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                const Expanded(child: VideoLibrary()),
                const Divider(height: 1, color: AppColors.border),
                const VideoUploader(),
              ],
            ),
          ),
        ),
        // Main area
        Expanded(
          child: selectedVideo == null
              ? const Center(
                  child: Text('Select a video from the library or upload a new one',
                      style: TextStyle(color: AppColors.textMuted)))
              : _MainContent(video: selectedVideo),
        ),
      ],
    );
  }
}

class _MainContent extends StatefulWidget {
  final VideoInfo video;

  const _MainContent({required this.video});

  @override
  State<_MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<_MainContent> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant _MainContent old) {
    super.didUpdateWidget(old);
    if (old.video.videoId != widget.video.videoId) {
      _controller?.dispose();
      _initPlayer();
    }
  }

  void _initPlayer() {
    final api = ApiService();
    final url = api.getSourceVideoUrl(widget.video.videoId);
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
              ),
              Expanded(
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.accent,
                    bufferedColor: AppColors.surfaceLight,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDuration(_controller!.value.position),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
