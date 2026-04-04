class Detection {
  final int trackerId;
  final List<double> bbox;
  final double confidence;

  Detection({required this.trackerId, required this.bbox, required this.confidence});

  factory Detection.fromJson(Map<String, dynamic> json) => Detection(
        trackerId: json['tracker_id'] as int,
        bbox: (json['bbox'] as List).map((e) => (e as num).toDouble()).toList(),
        confidence: (json['confidence'] as num).toDouble(),
      );

  double get x1 => bbox[0];
  double get y1 => bbox[1];
  double get x2 => bbox[2];
  double get y2 => bbox[3];
  double get width => x2 - x1;
  double get height => y2 - y1;
  double get footX => (x1 + x2) / 2;
  double get footY => y2;
}

class TrackingFrame {
  final int frameNumber;
  final double timestamp;
  final List<Detection> detections;

  TrackingFrame({required this.frameNumber, required this.timestamp, required this.detections});

  factory TrackingFrame.fromJson(Map<String, dynamic> json) => TrackingFrame(
        frameNumber: json['frame_number'] as int,
        timestamp: (json['timestamp'] as num).toDouble(),
        detections:
            (json['detections'] as List).map((d) => Detection.fromJson(d)).toList(),
      );
}

class TrackingData {
  final double fps;
  final int totalFrames;
  final List<TrackingFrame> frames;
  final Map<int, List<Detection>> _frameMap = {};

  TrackingData({required this.fps, required this.totalFrames, required this.frames}) {
    for (final f in frames) {
      _frameMap[f.frameNumber] = f.detections;
    }
  }

  factory TrackingData.fromJson(Map<String, dynamic> json) => TrackingData(
        fps: (json['fps'] as num).toDouble(),
        totalFrames: json['total_frames'] as int,
        frames:
            (json['frames'] as List).map((f) => TrackingFrame.fromJson(f)).toList(),
      );

  List<Detection> detectionsAt(int frameNumber) => _frameMap[frameNumber] ?? [];
}
