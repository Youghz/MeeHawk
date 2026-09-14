import 'package:app/domain/entities.dart';

/// Maps a position in the match video onto what has happened by then.
///
/// Every impact recorded while watching a video carries a [BallImpact.videoTimeSec].
/// These rules turn that into a progressive reveal: at second T the court shows
/// the rally being played, with only the touches that have already happened.
///
/// Matches scored live carry no timestamps at all. Nothing here invents one —
/// the rules degrade to "show the whole rally", so an older match still replays,
/// just without the progressive reveal.
class VideoTimeline {
  const VideoTimeline._();

  /// When [rally] starts in the video, or null if it was scored without one.
  ///
  /// Prefers the server-position marker: it is the rally's own boundary, and the
  /// only impact the annotation agent timestamps unconditionally.
  static double? startOf(PointRecord rally) {
    double? firstAny;
    for (final impact in rally.impacts) {
      final t = impact.videoTimeSec;
      if (t == null) continue;
      if (impact.isServerPosition) return t;
      firstAny ??= t;
    }
    return firstAny;
  }

  /// Index in [history] of the rally being played at [seconds], or null when no
  /// rally has started yet — or when the match carries no timestamps at all.
  ///
  /// A rally runs until the next one starts, so scrubbing into the dead time
  /// between two points keeps showing the one that just finished.
  static int? rallyIndexAt(List<PointRecord> history, double seconds) {
    int? current;
    for (var i = 0; i < history.length; i++) {
      final start = startOf(history[i]);
      if (start == null) continue;
      if (start > seconds) break;
      current = i;
    }
    return current;
  }

  /// The touches of [rally] that have already happened at [seconds].
  ///
  /// An impact with no timestamp inherits the last known one before it, so it
  /// appears alongside its neighbour instead of never showing up. A rally with
  /// no timestamps at all is returned whole — there is nothing to reveal against.
  static List<BallImpact> impactsUpTo(PointRecord rally, double seconds) {
    if (rally.impacts.every((i) => i.videoTimeSec == null)) return rally.impacts;

    final visible = <BallImpact>[];
    double? lastKnown;
    for (final impact in rally.impacts) {
      lastKnown = impact.videoTimeSec ?? lastKnown;
      // A leading untimestamped impact has nothing to inherit; show it rather
      // than hide the start of the rally.
      if (lastKnown == null || lastKnown <= seconds) {
        visible.add(impact);
      } else {
        break;
      }
    }
    return visible;
  }

  /// True when [history] carries enough timing to drive a progressive reveal.
  static bool hasTimestamps(List<PointRecord> history) =>
      history.any((rally) => startOf(rally) != null);
}
