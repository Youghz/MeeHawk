// Web-only: an HtmlElementView wrapping a native <video> or a YouTube <iframe>.
// Never compiled on non-web targets — see the conditional export in
// video_player_widget.dart.
//
// Platform work lives in web_video_controller.dart, the scrub bar in
// video_scrubber.dart. This file only wires them to the match state.
import 'package:app/core/theme.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/features/match_history/widgets/video_scrubber.dart';
import 'package:app/features/match_history/widgets/web_video_controller.dart';
import 'package:app/state/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// mm:ss, the only format a match video ever needs.
String _formatTime(double seconds) {
  final d = Duration(milliseconds: (seconds * 1000).round());
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({required this.videoUrl, super.key});

  final String videoUrl;

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  late final WebVideoController _controller;
  int? _hoveredMarkerIndex;

  static const _maxHeight = 320.0;

  @override
  void initState() {
    super.initState();
    _controller = WebVideoController(widget.videoUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Jump to the rally at [index], if it carries a video timestamp.
  void _seekToRally(int index, List<PointRecord> history) {
    if (index >= history.length) return;
    for (final impact in history[index].impacts) {
      if (impact.isServerPosition && impact.videoTimeSec != null) {
        _controller.seek(impact.videoTimeSec!, andPlay: true);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(matchProvider.select((s) => s.history));

    // Selecting a point on the timeline drives the video, not the reverse.
    ref.listen<int?>(
      matchProvider.select((s) => s.selectedPointIndex),
      (previous, next) {
        if (next != null && next != previous) _seekToRally(next, history);
      },
    );

    final markers = buildRallyMarkers(history);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _maxHeight),
      child: ColoredBox(
        color: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: HtmlElementView(viewType: _controller.viewId),
              ),
            ),
            ValueListenableBuilder<VideoPlayback>(
              valueListenable: _controller,
              builder: (_, playback, _) => _Controls(
                playback: playback,
                markers: markers,
                hoveredMarkerIndex: _hoveredMarkerIndex,
                onTogglePlay: _controller.togglePlayPause,
                onScrubStart: _controller.previewPosition,
                onScrubUpdate: _controller.previewPosition,
                onScrubEnd: _controller.commitScrub,
                onSeek: _controller.seek,
                onMarkerTap: (index) =>
                    ref.read(matchProvider.notifier).selectPoint(index),
                onHoverMarker: (index) {
                  if (index == _hoveredMarkerIndex) return;
                  setState(() => _hoveredMarkerIndex = index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.playback,
    required this.markers,
    required this.hoveredMarkerIndex,
    required this.onTogglePlay,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    required this.onSeek,
    required this.onMarkerTap,
    required this.onHoverMarker,
  });

  final VideoPlayback playback;
  final List<RallyMarker> markers;
  final int? hoveredMarkerIndex;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onMarkerTap;
  final ValueChanged<int?> onHoverMarker;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, MH.s2, 0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                playback.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: MH.ink,
              ),
              onPressed: onTogglePlay,
            ),
            Expanded(
              child: VideoScrubber(
                position: playback.position,
                duration: playback.duration,
                markers: markers,
                hoveredIndex: hoveredMarkerIndex,
                onScrubStart: onScrubStart,
                onScrubUpdate: onScrubUpdate,
                onScrubEnd: onScrubEnd,
                onSeek: onSeek,
                onMarkerTap: onMarkerTap,
                onHoverMarker: onHoverMarker,
              ),
            ),
            const SizedBox(width: MH.s2),
            Text(
              '${_formatTime(playback.position)}'
              ' / ${_formatTime(playback.duration)}',
              style: MH.mono(size: 11, color: MH.inkSoft),
            ),
            const SizedBox(width: MH.s2),
          ],
        ),
      );
}
