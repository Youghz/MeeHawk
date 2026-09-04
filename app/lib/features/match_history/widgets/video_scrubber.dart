import 'package:app/core/theme.dart';
import 'package:app/domain/match_state.dart';
import 'package:flutter/material.dart';

/// A point marker on the video timeline: where the rally starts and the score
/// going into it.
typedef RallyMarker = ({
  double timeSec,
  int scoreE1,
  int scoreE2,
  int index,
});

/// One marker per rally that carries a video timestamp.
///
/// The timestamp comes from the rally's server-position impact — the only one
/// stamped reliably, since it marks the start of the clip the annotator cut.
/// Rallies scored live (no video) yield no marker.
List<RallyMarker> buildRallyMarkers(List<PointRecord> history) {
  final markers = <RallyMarker>[];
  for (var i = 0; i < history.length; i++) {
    for (final impact in history[i].impacts) {
      if (impact.isServerPosition && impact.videoTimeSec != null) {
        markers.add((
          timeSec: impact.videoTimeSec!,
          scoreE1: i == 0 ? 0 : history[i - 1].scoreE1,
          scoreE2: i == 0 ? 0 : history[i - 1].scoreE2,
          index: i,
        ));
        break;
      }
    }
  }
  return markers;
}

/// Scrub bar with a tick per rally. Purely presentational — it reports
/// positions in seconds and lets the caller decide what to do.
class VideoScrubber extends StatelessWidget {
  const VideoScrubber({
    required this.position,
    required this.duration,
    required this.markers,
    required this.hoveredIndex,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    required this.onSeek,
    required this.onMarkerTap,
    required this.onHoverMarker,
    super.key,
  });

  static const _height = 44.0;

  /// Hit radius around a marker tick, in pixels.
  static const _markerHitRadius = 8.0;

  final double position;
  final double duration;
  final List<RallyMarker> markers;
  final int? hoveredIndex;

  final ValueChanged<double> onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;

  /// The user tapped the bar away from any marker.
  final ValueChanged<double> onSeek;

  /// The user tapped a rally tick — index into the match history.
  final ValueChanged<int> onMarkerTap;

  /// Marker under the cursor, or null when the cursor left the bar.
  final ValueChanged<int?> onHoverMarker;

  double _secondsAt(double x, double width) =>
      duration <= 0 ? 0 : (x / width * duration).clamp(0.0, duration);

  int? _markerNear(double x, double width) {
    if (duration <= 0) return null;
    for (final m in markers) {
      final markerX = (m.timeSec / duration) * width;
      if ((x - markerX).abs() <= _markerHitRadius) return m.index;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, constraints) {
          final width = constraints.maxWidth;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onHover: (e) => onHoverMarker(_markerNear(e.localPosition.dx, width)),
            onExit: (_) => onHoverMarker(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final marker = _markerNear(d.localPosition.dx, width);
                if (marker != null) {
                  onMarkerTap(marker);
                } else {
                  onSeek(_secondsAt(d.localPosition.dx, width));
                }
              },
              onHorizontalDragStart: (d) =>
                  onScrubStart(_secondsAt(d.localPosition.dx, width)),
              onHorizontalDragUpdate: (d) =>
                  onScrubUpdate(_secondsAt(d.localPosition.dx, width)),
              onHorizontalDragEnd: (_) => onScrubEnd(position),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(width, _height),
                  painter: _ScrubberPainter(
                    position: position,
                    duration: duration,
                    markers: markers,
                    hoveredIndex: hoveredIndex,
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.position,
    required this.duration,
    required this.markers,
    required this.hoveredIndex,
  });

  final double position;
  final double duration;
  final List<RallyMarker> markers;
  final int? hoveredIndex;

  static const _trackY = 30.0;
  static const _trackH = 3.0;
  static const _thumbR = 6.0;
  static const _tickHalfHeight = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    void track(double width, Color color) => canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, _trackY - _trackH / 2, width, _trackH),
            const Radius.circular(_trackH / 2),
          ),
          Paint()..color = color,
        );

    track(size.width, MH.rule);
    if (duration <= 0) return;

    final fraction = (position / duration).clamp(0.0, 1.0);
    track(fraction * size.width, MH.ball);

    for (final m in markers) {
      _paintMarker(canvas, size, m);
    }

    canvas.drawCircle(
      Offset(fraction * size.width, _trackY),
      _thumbR,
      Paint()..color = MH.ball,
    );
  }

  void _paintMarker(Canvas canvas, Size size, RallyMarker marker) {
    final x = (marker.timeSec / duration).clamp(0.0, 1.0) * size.width;
    final isHovered = hoveredIndex == marker.index;

    canvas.drawLine(
      Offset(x, _trackY - _tickHalfHeight),
      Offset(x, _trackY + _tickHalfHeight),
      Paint()
        ..color = isHovered ? Colors.white : Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = isHovered ? 2 : 1.5
        ..strokeCap = StrokeCap.round,
    );

    if (!isHovered) return;

    final label = TextPainter(
      text: TextSpan(
        text: '${marker.scoreE1}-${marker.scoreE2}',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pill = Rect.fromCenter(
      center: Offset(x, _trackY - 20),
      width: label.width + 8,
      height: label.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pill, const Radius.circular(4)),
      Paint()..color = MH.ball,
    );
    label.paint(canvas, Offset(pill.left + 4, pill.top + 2));
  }

  @override
  bool shouldRepaint(_ScrubberPainter old) =>
      old.position != position ||
      old.duration != duration ||
      old.hoveredIndex != hoveredIndex ||
      old.markers.length != markers.length;
}
