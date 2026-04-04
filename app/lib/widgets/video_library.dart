import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_info.dart';
import '../providers/video_provider.dart';
import '../theme.dart';

class VideoLibrary extends ConsumerWidget {
  const VideoLibrary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(videosProvider);
    final jobs = ref.watch(activeJobsProvider);
    final selectedId = ref.watch(selectedVideoIdProvider);

    final roots = videos.where((v) => !v.isChild).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('VIDEOS',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: videos.isEmpty
              ? Center(
                  child: Text('No videos yet.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    for (final v in roots) ...[
                      _VideoItem(
                        video: v,
                        isSelected: v.videoId == selectedId,
                        job: _findJob(jobs, v.videoId),
                        isChild: false,
                        onTap: () => ref.read(selectedVideoIdProvider.notifier).select(v.videoId),
                        ref: ref,
                      ),
                      for (final child in videos.where((c) => c.parentId == v.videoId))
                        _VideoItem(
                          video: child,
                          isSelected: child.videoId == selectedId,
                          job: _findJob(jobs, child.videoId),
                          isChild: true,
                          onTap: () =>
                              ref.read(selectedVideoIdProvider.notifier).select(child.videoId),
                          ref: ref,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  JobInfo? _findJob(List<JobInfo> jobs, String videoId) {
    try {
      return jobs.firstWhere((j) => j.videoId == videoId && j.isRunning);
    } catch (_) {
      return null;
    }
  }
}

class _VideoItem extends StatelessWidget {
  final VideoInfo video;
  final bool isSelected;
  final bool isChild;
  final JobInfo? job;
  final VoidCallback onTap;
  final WidgetRef ref;

  const _VideoItem({
    required this.video,
    required this.isSelected,
    required this.isChild,
    required this.job,
    required this.onTap,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiServiceProvider);
    final showActions = isSelected && !video.isProcessing && job == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: EdgeInsets.only(
          left: isChild ? 20 : 10,
          right: 6,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C2A3A) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? const Border(left: BorderSide(color: AppColors.accent, width: 3))
              : null,
        ),
        child: Row(
          children: [
            if (isChild)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('└', style: TextStyle(color: AppColors.border, fontSize: 12)),
              ),
            _statusDot(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                video.originalName,
                style: TextStyle(fontSize: isChild ? 12 : 13, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (video.isProcessing && video.progress != null)
              Text('${video.progress!['percent'] ?? 0}%',
                  style: const TextStyle(fontSize: 11, color: AppColors.orange)),
            if (job != null && job!.progress != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  job!.progress!['step'] == 'detecting' ? 'Detecting' : 'Splitting',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 4),
                Text('${job!.progress!['percent'] ?? 0}%',
                    style: const TextStyle(fontSize: 11, color: AppColors.orange)),
              ]),
            if ((video.isProcessing || job != null) && isSelected)
              _actionPill('■', AppColors.red, () async {
                await api.cancelProcessing(video.videoId);
                ref.read(videosProvider.notifier).refresh();
              }),
            if (showActions) ...[
              if (!isChild) ...[
                _actionPill('Track', AppColors.accent, () async {
                  await api.analyzeVideo(video.videoId);
                  ref.read(videosProvider.notifier).refresh();
                }),
                _actionPill('Points', AppColors.green, () async {
                  await api.detectPoints(video.videoId);
                  ref.read(activeJobsProvider.notifier).refresh();
                }),
              ] else
                _actionPill('Track', AppColors.accent, () async {
                  await api.analyzeVideo(video.videoId);
                  ref.read(videosProvider.notifier).refresh();
                }),
              if (video.isCompleted)
                _actionPill('↺', AppColors.orange, () async {
                  await api.clearAnnotations(video.videoId);
                  ref.read(videosProvider.notifier).refresh();
                }),
              _actionPill('✕', AppColors.red, () async {
                await api.deleteVideo(video.videoId);
                ref.read(videosProvider.notifier).refresh();
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusDot() {
    Color color;
    switch (video.status) {
      case 'completed':
        color = AppColors.green;
      case 'processing':
        color = AppColors.orange;
      case 'failed':
        color = AppColors.red;
      default:
        color = AppColors.textMuted;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _actionPill(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, color: color)),
        ),
      ),
    );
  }
}
