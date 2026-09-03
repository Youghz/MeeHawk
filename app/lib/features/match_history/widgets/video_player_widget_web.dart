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

// ── Data ───────────────────────────────────────────────────────────────────

typedef _Marker = ({double timeSec, int scoreE1, int scoreE2, int index});

List<_Marker> _buildMarkers(List<PointRecord> history) {
  final out = <_Marker>[];
  for (var i = 0; i < history.length; i++) {
    for (final impact in history[i].impacts) {
      if (impact.isServerPosition && impact.videoTimeSec != null) {
        out.add((
          timeSec: impact.videoTimeSec!,
          scoreE1: i == 0 ? 0 : history[i - 1].scoreE1,
          scoreE2: i == 0 ? 0 : history[i - 1].scoreE2,
          index: i,
        ));
        break;
      }
    }
  }
  return out;
}

// ── Painter ────────────────────────────────────────────────────────────────

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.position,
    required this.duration,
    required this.markers,
    required this.hoveredIndex,
  });

  final double position;
  final double duration;
  final List<_Marker> markers;
  final int? hoveredIndex;

  static const _trackY = 30.0;
  static const _trackH = 3.0;
  static const _thumbR = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Inactive track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, _trackY - _trackH / 2, size.width, _trackH),
        const Radius.circular(_trackH / 2),
      ),
      Paint()..color = MH.rule,
    );

    if (duration <= 0) return;
    final fraction = (position / duration).clamp(0.0, 1.0);

    // Active track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, _trackY - _trackH / 2, fraction * size.width, _trackH),
        const Radius.circular(_trackH / 2),
      ),
      Paint()..color = MH.ball,
    );

    // Markers
    for (final m in markers) {
      final x = (m.timeSec / duration).clamp(0.0, 1.0) * size.width;
      final isHovered = hoveredIndex == m.index;

      final tickPaint = Paint()
        ..color = isHovered ? Colors.white : Colors.white.withOpacity(0.55)
        ..strokeWidth = isHovered ? 2 : 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, _trackY - 7),
        Offset(x, _trackY + 7),
        tickPaint,
      );

      if (isHovered) {
        final label = '${m.scoreE1}-${m.scoreE2}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Background pill
        final rect = Rect.fromCenter(
          center: Offset(x, _trackY - 20),
          width: tp.width + 8,
          height: tp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = MH.ball,
        );
        tp.paint(canvas, Offset(rect.left + 4, rect.top + 2));
      }
    }

    // Thumb
    canvas.drawCircle(
      Offset(fraction * size.width, _trackY),
      _thumbR,
      Paint()..color = MH.ball,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.position != position ||
      old.duration != duration ||
      old.hoveredIndex != hoveredIndex;
}

// ── Widget ─────────────────────────────────────────────────────────────────

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
  bool _isDragging = false;
  int? _hoveredMarkerIndex;
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
      _subs.add(html.window.onMessage.listen(_onYouTubeMessage));
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
          if (!_isDragging && mounted) {
            setState(() => _position = v.currentTime.toDouble());
          }
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
        if (info != null && mounted && !_isDragging) {
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
        _doSeek(impact.videoTimeSec!, andPlay: true);
        return;
      }
    }
  }

  void _doSeek(double secs, {bool andPlay = false}) {
    if (_isYt) {
      _ytCommand('seekTo', [secs, true]);
      if (andPlay) _ytCommand('playVideo', []);
    } else {
      final v = _video!
        ..currentTime = secs;
      setState(() => _position = secs);
      if (andPlay) {
        unawaited(v.onSeeked.first.then((_) {
          if (mounted) unawaited(v.play());
        }));
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

  double _posFromLocalX(double x, double trackWidth) =>
      (x / trackWidth * _duration).clamp(0.0, _duration);

  int? _markerNearX(double x, double trackWidth, List<_Marker> markers) {
    if (_duration <= 0) return null;
    const hitRadius = 8.0;
    for (final m in markers) {
      final mx = (m.timeSec / _duration) * trackWidth;
      if ((x - mx).abs() <= hitRadius) return m.index;
    }
    return null;
  }

  String _formatTime(double secs) {
    final d = Duration(milliseconds: (secs * 1000).round());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchProvider);

    ref.listen<MatchState>(matchProvider, (prev, next) {
      if (prev?.selectedPointIndex != next.selectedPointIndex &&
          next.selectedPointIndex != null) {
        _seekToPointIndex(next.selectedPointIndex!, next.history);
      }
    });

    final markers = _buildMarkers(matchState.history);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
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
            _buildControls(markers),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(List<_Marker> markers) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, MH.s2, 0),
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
            child: _VideoTrack(
              position: _position,
              duration: _duration,
              markers: markers,
              hoveredIndex: _hoveredMarkerIndex,
              onSeekStart: (x, w) {
                setState(() {
                  _isDragging = true;
                  _position = _posFromLocalX(x, w);
                });
              },
              onSeekUpdate: (x, w) {
                setState(() => _position = _posFromLocalX(x, w));
              },
              onSeekEnd: (x, w) {
                final secs = _posFromLocalX(x, w);
                setState(() => _isDragging = false);
                _doSeek(secs);
              },
              onTap: (x, w) {
                final nearMarker = _markerNearX(x, w, markers);
                if (nearMarker != null) {
                  ref.read(matchProvider.notifier).selectPoint(nearMarker);
                } else {
                  _doSeek(_posFromLocalX(x, w));
                }
              },
              onHover: (x, w) {
                final idx = _markerNearX(x, w, markers);
                if (idx != _hoveredMarkerIndex) {
                  setState(() => _hoveredMarkerIndex = idx);
                }
              },
              onHoverExit: () {
                if (_hoveredMarkerIndex != null) {
                  setState(() => _hoveredMarkerIndex = null);
                }
              },
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

// ── Track widget ───────────────────────────────────────────────────────────

class _VideoTrack extends StatelessWidget {
  const _VideoTrack({
    required this.position,
    required this.duration,
    required this.markers,
    required this.hoveredIndex,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onTap,
    required this.onHover,
    required this.onHoverExit,
  });

  final double position;
  final double duration;
  final List<_Marker> markers;
  final int? hoveredIndex;
  final void Function(double x, double w) onSeekStart;
  final void Function(double x, double w) onSeekUpdate;
  final void Function(double x, double w) onSeekEnd;
  final void Function(double x, double w) onTap;
  final void Function(double x, double w) onHover;
  final VoidCallback onHoverExit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (e) => onHover(e.localPosition.dx, w),
          onExit: (_) => onHoverExit(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => onTap(d.localPosition.dx, w),
            onHorizontalDragStart: (d) => onSeekStart(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => onSeekUpdate(d.localPosition.dx, w),
            onHorizontalDragEnd: (d) =>
                onSeekEnd(d.localPosition.dx, w),
            child: SizedBox(
              height: 44,
              child: CustomPaint(
                painter: _TrackPainter(
                  position: position,
                  duration: duration,
                  markers: markers,
                  hoveredIndex: hoveredIndex,
                ),
                size: Size(w, 44),
              ),
            ),
          ),
        );
      },
    );
  }
}
