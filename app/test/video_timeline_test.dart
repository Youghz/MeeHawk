import 'package:app/domain/match_state.dart';
import 'package:app/domain/rules/video_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

BallImpact _impact(double? t, {bool serverPos = false}) => BallImpact(
      x: 0.5,
      y: 0.5,
      isOutside: false,
      teamSide: TeamSide.e1,
      isServerPosition: serverPos,
      videoTimeSec: t,
    );

PointRecord _rally(List<BallImpact> impacts) => PointRecord(
      winner: TeamSide.e1,
      annotations: const [],
      scoreE1: 1,
      scoreE2: 0,
      setNumber: 1,
      serverId: 'p3',
      impacts: impacts,
    );

void main() {
  group('startOf', () {
    test('prefers the server-position marker', () {
      final rally = _rally([
        _impact(10, serverPos: true),
        _impact(12),
      ]);
      expect(VideoTimeline.startOf(rally), 10);
    });

    test('falls back to the first timestamped impact', () {
      final rally = _rally([_impact(null), _impact(12), _impact(14)]);
      expect(VideoTimeline.startOf(rally), 12);
    });

    test('is null for a rally scored without a video', () {
      expect(VideoTimeline.startOf(_rally([_impact(null)])), isNull);
    });
  });

  group('rallyIndexAt', () {
    final history = [
      _rally([_impact(10, serverPos: true), _impact(12)]),
      _rally([_impact(30, serverPos: true), _impact(33)]),
      _rally([_impact(50, serverPos: true), _impact(52)]),
    ];

    test('null before the first rally starts', () {
      expect(VideoTimeline.rallyIndexAt(history, 5), isNull);
    });

    test('finds the rally in progress', () {
      expect(VideoTimeline.rallyIndexAt(history, 31), 1);
    });

    test('keeps showing the last rally through the dead time after it', () {
      // 40s is between rally 1 ending and rally 2 starting.
      expect(VideoTimeline.rallyIndexAt(history, 40), 1);
    });

    test('exactly on a rally start selects that rally', () {
      expect(VideoTimeline.rallyIndexAt(history, 30), 1);
    });

    test('past the end stays on the last rally', () {
      expect(VideoTimeline.rallyIndexAt(history, 9999), 2);
    });

    test('null when the match carries no timestamps at all', () {
      final untimed = [
        _rally([_impact(null), _impact(null)]),
      ];
      expect(VideoTimeline.rallyIndexAt(untimed, 42), isNull);
    });

    test('skips untimestamped rallies rather than mis-selecting them', () {
      final mixed = [
        _rally([_impact(10, serverPos: true)]),
        _rally([_impact(null)]),
        _rally([_impact(50, serverPos: true)]),
      ];
      expect(VideoTimeline.rallyIndexAt(mixed, 30), 0);
      expect(VideoTimeline.rallyIndexAt(mixed, 60), 2);
    });
  });

  group('impactsUpTo', () {
    test('reveals touches one by one as the video plays', () {
      final rally = _rally([
        _impact(10, serverPos: true),
        _impact(11),
        _impact(13),
        _impact(15),
      ]);
      expect(VideoTimeline.impactsUpTo(rally, 9), isEmpty);
      expect(VideoTimeline.impactsUpTo(rally, 11).length, 2);
      expect(VideoTimeline.impactsUpTo(rally, 14).length, 3);
      expect(VideoTimeline.impactsUpTo(rally, 99).length, 4);
    });

    test('an untimestamped touch appears with the last known one', () {
      // The agent only timestamps the server marker unless it offered offsets.
      final rally = _rally([
        _impact(10, serverPos: true),
        _impact(null),
        _impact(null),
      ]);
      expect(VideoTimeline.impactsUpTo(rally, 9), isEmpty);
      expect(VideoTimeline.impactsUpTo(rally, 10).length, 3);
    });

    test('a rally with no timestamps is shown whole', () {
      // The human-scored corpus match is exactly this shape — it must still
      // replay, just without the progressive reveal.
      final rally = _rally([_impact(null), _impact(null), _impact(null)]);
      expect(VideoTimeline.impactsUpTo(rally, 0).length, 3);
      expect(VideoTimeline.impactsUpTo(rally, 999).length, 3);
    });
  });

  group('hasTimestamps', () {
    test('false for a match scored live', () {
      expect(VideoTimeline.hasTimestamps([_rally([_impact(null)])]), isFalse);
    });

    test('true as soon as one rally is anchored', () {
      expect(
        VideoTimeline.hasTimestamps([
          _rally([_impact(null)]),
          _rally([_impact(30, serverPos: true)]),
        ]),
        isTrue,
      );
    });

    test('false for an empty match', () {
      expect(VideoTimeline.hasTimestamps(const []), isFalse);
    });
  });
}
