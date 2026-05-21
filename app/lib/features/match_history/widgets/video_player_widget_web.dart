// Web-only: HtmlElementView + dart:html video element.
// Never compiled on non-web targets (conditional import in video_player_widget.dart).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({required this.videoUrl, super.key});

  final String videoUrl;

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  late final String _viewId;
  late final html.VideoElement _video;
  bool _playing = false;
  double _position = 0;
  double _duration = 0;
  final List<StreamSubscription<html.Event>> _subs = [];

  @override
  void initState() {
    super.initState();
    _viewId = 'meehawk-video-${widget.videoUrl.hashCode}';
    _video = html.VideoElement()
      ..src = widget.videoUrl
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = 'black';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _video);

    _subs
      ..add(_video.onTimeUpdate.listen((_) {
        if (mounted) setState(() => _position = _video.currentTime.toDouble());
      }))
      ..add(_video.onDurationChange.listen((_) {
        if (mounted) setState(() => _duration = _video.duration.toDouble());
      }))
      ..add(_video.onPlay.listen((_) {
        if (mounted) setState(() => _playing = true);
      }))
      ..add(_video.onPause.listen((_) {
        if (mounted) setState(() => _playing = false);
      }));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _video.pause();
    super.dispose();
  }

  void _seekToPointIndex(int index, List<PointRecord> history) {
    if (index >= history.length) return;
    for (final impact in history[index].impacts) {
      if (impact.isServerPosition && impact.videoTimeSec != null) {
        _video.currentTime = impact.videoTimeSec!;
        unawaited(
          _video.onSeeked.first.then((_) {
            if (mounted) unawaited(_video.play());
          }),
        );
        return;
      }
    }
  }

  String _formatTime(double secs) {
    final d = Duration(milliseconds: (secs * 1000).round());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MatchState>(matchProvider, (prev, next) {
      if (prev?.selectedPointIndex != next.selectedPointIndex &&
          next.selectedPointIndex != null) {
        _seekToPointIndex(next.selectedPointIndex!, next.history);
      }
    });

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ColoredBox(
        color: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: HtmlElementView(viewType: _viewId),
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MH.s2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: MH.ink,
            ),
            onPressed: () {
              if (_playing) {
                _video.pause();
              } else {
                unawaited(_video.play());
              }
            },
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: MH.ball,
                inactiveTrackColor: MH.rule,
                thumbColor: MH.ball,
              ),
              child: Slider(
                value: _duration > 0 ? _position.clamp(0, _duration) : 0,
                max: _duration > 0 ? _duration : 1,
                onChanged: (v) {
                  _video.currentTime = v;
                  setState(() => _position = v);
                },
              ),
            ),
          ),
          const SizedBox(width: MH.s2),
          Text(
            '${_formatTime(_position)} / ${_formatTime(_duration)}',
            style: MH.mono(size: 11, color: MH.inkSoft),
          ),
          const SizedBox(width: MH.s2),
        ],
      ),
    );
  }
}
