// Web-only. Never compiled on other targets — see the conditional export in
// video_player_widget.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Playback state exposed to the UI, so the widget never touches a DOM node.
@immutable
class VideoPlayback {
  const VideoPlayback({
    this.position = 0,
    this.duration = 0,
    this.isPlaying = false,
  });

  final double position;
  final double duration;
  final bool isPlaying;

  VideoPlayback copyWith({double? position, double? duration, bool? isPlaying}) =>
      VideoPlayback(
        position: position ?? this.position,
        duration: duration ?? this.duration,
        isPlaying: isPlaying ?? this.isPlaying,
      );
}

/// Drives a video on the web, hiding which of the two very different backends
/// is in play:
///
/// - a local file → a real `<video>` element we can command directly;
/// - a YouTube URL → an `<iframe>` we can only reach through postMessage,
///   which is also the only way playback state comes back.
///
/// The widget registers [viewId] with [ui_web.platformViewRegistry] in the
/// constructor, so build a controller before the first `HtmlElementView`.
class WebVideoController extends ValueNotifier<VideoPlayback> {
  WebVideoController(this.videoUrl)
      : viewId = 'crabcoach-video-${videoUrl.hashCode}',
        isYouTube = _isYouTubeUrl(videoUrl),
        super(const VideoPlayback()) {
    if (isYouTube) {
      _attachYouTube();
    } else {
      _attachVideoElement();
    }
  }

  final String videoUrl;
  final String viewId;
  final bool isYouTube;

  web.HTMLVideoElement? _video;
  web.HTMLIFrameElement? _iframe;
  final List<StreamSubscription<void>> _subs = [];

  /// True while the user drags the scrubber — position updates from the
  /// element are ignored so the thumb does not fight the finger.
  bool _isScrubbing = false;

  static bool _isYouTubeUrl(String url) =>
      url.contains('youtube.com') || url.contains('youtu.be');

  /// Rewrites a YouTube watch/share URL into an embeddable one with the
  /// iframe JS API enabled, which is what makes postMessage control possible.
  static String toEmbedUrl(String url) {
    for (final pattern in [
      RegExp('[?&]v=([a-zA-Z0-9_-]+)'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)'),
    ]) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return 'https://www.youtube-nocookie.com/embed/'
            '${match.group(1)}?enablejsapi=1';
      }
    }
    return url.contains('?') ? '$url&enablejsapi=1' : '$url?enablejsapi=1';
  }

  // ── Setup ──────────────────────────────────────────────────────────────

  void _attachYouTube() {
    final iframe = web.HTMLIFrameElement()
      ..src = toEmbedUrl(videoUrl)
      ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; '
          'gyroscope; picture-in-picture'
      ..allowFullscreen = true;
    iframe.style
      ..width = '100%'
      ..height = '100%'
      ..border = 'none';
    _iframe = iframe;

    ui_web.platformViewRegistry.registerViewFactory(viewId, (_) => iframe);
    _subs.add(
      web.EventStreamProviders.messageEvent
          .forTarget(web.window)
          .listen(_onYouTubeMessage),
    );
  }

  void _attachVideoElement() {
    final element = web.HTMLVideoElement()..src = videoUrl;
    element.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..backgroundColor = 'black';
    _video = element;

    ui_web.platformViewRegistry.registerViewFactory(viewId, (_) => element);

    void on(web.EventStreamProvider<web.Event> event, VoidCallback handler) {
      _subs.add(event.forTarget(element).listen((_) => handler()));
    }

    on(web.EventStreamProviders.timeUpdateEvent, () {
      if (!_isScrubbing) value = value.copyWith(position: element.currentTime);
    });
    on(web.EventStreamProviders.durationChangeEvent, () {
      value = value.copyWith(duration: element.duration);
    });
    on(web.EventStreamProviders.playEvent, () {
      value = value.copyWith(isPlaying: true);
    });
    on(web.EventStreamProviders.pauseEvent, () {
      value = value.copyWith(isPlaying: false);
    });
  }

  // ── YouTube bridge ─────────────────────────────────────────────────────

  void _onYouTubeMessage(web.MessageEvent event) {
    final raw = event.data;
    // Other scripts on the page post messages too; ignore anything that is not
    // the JSON payload the YouTube iframe API sends.
    if (raw == null || !raw.isA<JSString>()) return;

    final Map<String, dynamic> data;
    try {
      data = jsonDecode((raw as JSString).toDart) as Map<String, dynamic>;
    } on Object {
      return;
    }

    switch (data['event']) {
      case 'infoDelivery':
        final info = data['info'] as Map<String, dynamic>?;
        if (info == null || _isScrubbing) return;
        final duration = (info['duration'] as num?)?.toDouble();
        final state = info['playerState'] as int?;
        value = value.copyWith(
          position: (info['currentTime'] as num?)?.toDouble(),
          duration: duration != null && duration > 0 ? duration : null,
          isPlaying: state == null ? null : state == _ytPlaying,
        );
      case 'onStateChange':
        final state = data['info'] as int?;
        if (state != null) {
          value = value.copyWith(isPlaying: state == _ytPlaying);
        }
    }
  }

  /// YouTube iframe API player state for "playing".
  static const _ytPlaying = 1;

  void _ytCommand(String func, List<Object?> args) {
    _iframe?.contentWindow?.postMessage(
      jsonEncode({'event': 'command', 'func': func, 'args': args}).toJS,
      '*'.toJS,
    );
  }

  // ── Commands ───────────────────────────────────────────────────────────

  void togglePlayPause() {
    if (isYouTube) {
      _ytCommand(value.isPlaying ? 'pauseVideo' : 'playVideo', const []);
      return;
    }
    final element = _video!;
    if (value.isPlaying) {
      element.pause();
    } else {
      unawaited(element.play().toDart);
    }
  }

  void seek(double seconds, {bool andPlay = false}) {
    if (isYouTube) {
      _ytCommand('seekTo', [seconds, true]);
      if (andPlay) _ytCommand('playVideo', const []);
      return;
    }
    final element = _video!..currentTime = seconds;
    value = value.copyWith(position: seconds);
    if (!andPlay) return;
    // Playing before the seek settles restarts from the old position.
    unawaited(
      web.EventStreamProviders.seekedEvent.forTarget(element).first.then((_) {
        unawaited(element.play().toDart);
      }),
    );
  }

  /// Preview a position without committing it — used while dragging.
  void previewPosition(double seconds) {
    _isScrubbing = true;
    value = value.copyWith(position: seconds);
  }

  void commitScrub(double seconds) {
    _isScrubbing = false;
    seek(seconds);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    _video?.pause();
    super.dispose();
  }
}
