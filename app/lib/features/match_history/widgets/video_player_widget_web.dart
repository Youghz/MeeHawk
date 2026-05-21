// Web-only: HtmlElementView + dart:html video/iframe element.
// Never compiled on non-web targets (conditional import in video_player_widget.dart).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
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
  late final bool _isYt;
  html.VideoElement? _video;
  html.IFrameElement? _iframe;
  bool _playing = false;
  double _position = 0;
  double _duration = 0;
  final List<StreamSubscription<dynamic>> _subs = [];

  static bool _isYouTube(String url) =>
      url.contains('youtube.com') || url.contains('youtu.be');

  static String _toEmbedUrl(String url) {
    final watchMatch = RegExp('[?&]v=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (watchMatch != null) {
      return 'https://www.youtube-nocookie.com/embed/${watchMatch.group(1)}?enablejsapi=1';
    }
    final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (shortMatch != null) {
      return 'https://www.youtube-nocookie.com/embed/${shortMatch.group(1)}?enablejsapi=1';
    }
    // Already an embed URL — just ensure enablejsapi is present
    return url.contains('?') ? '$url&enablejsapi=1' : '$url?enablejsapi=1';
  }

  @override
  void initState() {
    super.initState();
    _viewId = 'meehawk-video-${widget.videoUrl.hashCode}';
    _isYt = _isYouTube(widget.videoUrl);

    if (_isYt) {
      _iframe = html.IFrameElement()
        ..src = _toEmbedUrl(widget.videoUrl)
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
        ..allowFullscreen = true;
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _iframe!);
      _subs
          .add(html.window.onMessage.listen(_onYouTubeMessage));
    } else {
      _video = html.VideoElement()
        ..src = widget.videoUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = 'black';
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _video!);
      final v = _video!;
      _subs
        ..add(v.onTimeUpdate.listen((_) {
          if (mounted) setState(() => _position = v.currentTime.toDouble());
        }))
        ..add(v.onDurationChange.listen((_) {
          if (mounted) setState(() => _duration = v.duration.toDouble());
        }))
        ..add(v.onPlay.listen((_) {
          if (mounted) setState(() => _playing = true);
        }))
        ..add(v.onPause.listen((_) {
          if (mounted) setState(() => _playing = false);
        }));
    }
  }

  void _onYouTubeMessage(html.MessageEvent event) {
    try {
      final data = jsonDecode(event.data.toString()) as Map<String, dynamic>;
      if (data['event'] == 'infoDelivery') {
        final info = data['info'] as Map<String, dynamic>?;
        if (info != null && mounted) {
          setState(() {
            final t = (info['currentTime'] as num?)?.toDouble();
            final d = (info['duration'] as num?)?.toDouble();
            final s = info['playerState'] as int?;
            if (t != null) _position = t;
            if (d != null && d > 0) _duration = d;
            if (s != null) _playing = s == 1;
          });
        }
      } else if (data['event'] == 'onStateChange') {
        final s = data['info'] as int?;
        if (mounted && s != null) setState(() => _playing = s == 1);
      }
    } on Object catch (_) {}
  }

  void _ytCommand(String func, List<dynamic> args) {
    _iframe?.contentWindow?.postMessage(
      jsonEncode({'event': 'command', 'func': func, 'args': args}),
      '*',
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _video?.pause();
    super.dispose();
  }

  void _seekToPointIndex(int index, List<PointRecord> history) {
    if (index >= history.length) return;
    for (final impact in history[index].impacts) {
      if (impact.isServerPosition && impact.videoTimeSec != null) {
        final secs = impact.videoTimeSec!;
        if (_isYt) {
          _ytCommand('seekTo', [secs, true]);
          _ytCommand('playVideo', []);
        } else {
          final v = _video!;
          unawaited(
            (v..currentTime = secs).onSeeked.first.then((_) {
              if (mounted) unawaited(v.play());
            }),
          );
        }
        return;
      }
    }
  }

  void _togglePlayPause() {
    if (_isYt) {
      _ytCommand(_playing ? 'pauseVideo' : 'playVideo', []);
    } else {
      final v = _video!;
      if (_playing) {
        v.pause();
      } else {
        unawaited(v.play());
      }
    }
  }

  void _onSliderChanged(double value) {
    if (_isYt) {
      _ytCommand('seekTo', [value, true]);
    } else {
      _video!.currentTime = value;
      setState(() => _position = value);
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
            onPressed: _togglePlayPause,
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
                onChanged: _onSliderChanged,
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
