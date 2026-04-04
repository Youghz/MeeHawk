class VideoInfo {
  final String videoId;
  final String originalName;
  final String status;
  final String? parentId;
  final Map<String, dynamic>? progress;

  VideoInfo({
    required this.videoId,
    required this.originalName,
    required this.status,
    this.parentId,
    this.progress,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
        videoId: json['video_id'] as String,
        originalName: json['original_name'] as String,
        status: json['status'] as String,
        parentId: json['parent_id'] as String?,
        progress: json['progress'] as Map<String, dynamic>?,
      );

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isChild => parentId != null;
}

class JobInfo {
  final String jobId;
  final String videoId;
  final String type;
  final String status;
  final Map<String, dynamic>? progress;

  JobInfo({
    required this.jobId,
    required this.videoId,
    required this.type,
    required this.status,
    this.progress,
  });

  factory JobInfo.fromJson(Map<String, dynamic> json) => JobInfo(
        jobId: json['job_id'] as String,
        videoId: json['video_id'] as String,
        type: json['type'] as String,
        status: json['status'] as String,
        progress: json['progress'] as Map<String, dynamic>?,
      );

  bool get isRunning => status == 'running';
}
