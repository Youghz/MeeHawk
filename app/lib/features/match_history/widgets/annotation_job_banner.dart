import 'package:app/core/theme.dart';
import 'package:app/features/match_history/domain/annotation_job.dart';
import 'package:flutter/material.dart';

class AnnotationJobBanner extends StatelessWidget {
  const AnnotationJobBanner({required this.jobs, super.key});

  final List<AnnotationJob> jobs;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final job in jobs) _JobCard(job: job),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final AnnotationJob job;

  IconData get _icon {
    return switch (job.status) {
      'analyzing' => Icons.visibility_outlined,
      'annotating' => Icons.edit_outlined,
      'importing' => Icons.cloud_upload_outlined,
      'error' => Icons.error_outline,
      _ => Icons.hourglass_empty_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isError = job.status == 'error';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: MH.sand,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? Colors.redAccent.withValues(alpha: 0.4) : MH.rule,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _icon,
                size: 16,
                color: isError ? Colors.redAccent : MH.ball,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  job.message,
                  style: MH.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: isError ? Colors.redAccent : MH.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (job.videoUrl != null) ...[
            const SizedBox(height: 2),
            Text(
              job.videoUrl!,
              style: MH.mono(size: 11, color: MH.inkSoft),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
          if (!isError) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.progress > 0 ? job.progress : null,
                backgroundColor: MH.rule,
                valueColor: const AlwaysStoppedAnimation<Color>(MH.ball),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
