import 'package:app/domain/match_state.dart';
import 'package:app/domain/rules/point_resolution.dart';
import 'package:app/domain/rules/possession.dart';
import 'package:flutter_test/flutter_test.dart';

/// Impacts as they are recorded during a rally. Coordinates are irrelevant to
/// these rules, so every helper uses the same dummy position.
BallImpact _touch(
  TeamSide side, {
  String? player,
  bool block = false,
  bool serverPos = false,
}) =>
    BallImpact(
      x: 0.5,
      y: 0.5,
      isOutside: false,
      teamSide: side,
      playerId: player,
      isBlock: block,
      isServerPosition: serverPos,
    );

void main() {
  group('Possession.startsNewVisit', () {
    test('true when the rally has no contact yet', () {
      expect(Possession.startsNewVisit(const [], TeamSide.e1), isTrue);
    });

    test('true when only a server-position marker was recorded', () {
      final impacts = [_touch(TeamSide.e2, serverPos: true, player: 'p3')];
      expect(Possession.startsNewVisit(impacts, TeamSide.e1), isTrue);
      expect(Possession.startsNewVisit(impacts, TeamSide.e2), isTrue);
    });

    test('true when the ball just crossed the net', () {
      final impacts = [_touch(TeamSide.e2, player: 'p3')];
      expect(Possession.startsNewVisit(impacts, TeamSide.e1), isTrue);
    });

    test('false mid-visit — the next player is inferable by alternation', () {
      final impacts = [
        _touch(TeamSide.e2, player: 'p3'),
        _touch(TeamSide.e1, player: 'p1'),
      ];
      expect(Possession.startsNewVisit(impacts, TeamSide.e1), isFalse);
    });

    test('true right after a block — the blocker may play again', () {
      final impacts = [
        _touch(TeamSide.e2, player: 'p3'),
        _touch(TeamSide.e1, player: 'p1', block: true),
      ];
      expect(Possession.startsNewVisit(impacts, TeamSide.e1), isTrue);
    });
  });

  group('Possession.visitIndexAt', () {
    test('counts net crossings, ignoring the server marker', () {
      final impacts = [
        _touch(TeamSide.e2, serverPos: true, player: 'p3'), // 0
        _touch(TeamSide.e2, player: 'p3'), // serve       → 0
        _touch(TeamSide.e1, player: 'p1'), // reception   → 1
        _touch(TeamSide.e1, player: 'p2'), // set         → 1
        _touch(TeamSide.e2, player: 'p4'), // dig         → 2
      ];
      expect(
        [for (var i = 0; i < impacts.length; i++) Possession.visitIndexAt(impacts, i)],
        [0, 0, 1, 1, 2],
      );
    });

    test('rejects an out-of-range index', () {
      expect(
        () => Possession.visitIndexAt([_touch(TeamSide.e1)], 5),
        throwsRangeError,
      );
    });
  });

  group('Possession.displayIndexAt', () {
    test('server marker is 0 so the serve still reads as contact 1', () {
      final impacts = [
        _touch(TeamSide.e2, serverPos: true, player: 'p3'),
        _touch(TeamSide.e2, player: 'p3'),
        _touch(TeamSide.e1, player: 'p1'),
      ];
      expect(
        [for (var i = 0; i < impacts.length; i++) Possession.displayIndexAt(impacts, i)],
        [0, 1, 2],
      );
    });

    test('without a server marker contacts are numbered from 1', () {
      final impacts = [
        _touch(TeamSide.e2, player: 'p3'),
        _touch(TeamSide.e1, player: 'p1'),
      ];
      expect(
        [for (var i = 0; i < impacts.length; i++) Possession.displayIndexAt(impacts, i)],
        [1, 2],
      );
    });
  });

  group('PointResolution.outOfBounds', () {
    test('no prior contact is a service fault — the server loses', () {
      final outcome = PointResolution.outOfBounds(
        impacts: const [],
        servingTeam: TeamSide.e2,
        servingPlayerId: 'p3',
      );
      expect(outcome.winner, TeamSide.e1);
      expect(outcome.faulterId, 'p3');
      expect(outcome.isServiceFault, isTrue);
    });

    test('a lone server marker is still a service fault', () {
      final outcome = PointResolution.outOfBounds(
        impacts: [_touch(TeamSide.e2, serverPos: true, player: 'p3')],
        servingTeam: TeamSide.e2,
        servingPlayerId: 'p3',
      );
      expect(outcome.winner, TeamSide.e1);
      expect(outcome.isServiceFault, isTrue);
    });

    test('charges the last real contact, not the landing side', () {
      // e1 attacks and sends the ball out beyond e2's court.
      final outcome = PointResolution.outOfBounds(
        impacts: [
          _touch(TeamSide.e2, serverPos: true, player: 'p3'),
          _touch(TeamSide.e2, player: 'p3'),
          _touch(TeamSide.e1, player: 'p1'),
          _touch(TeamSide.e1, player: 'p2'),
        ],
        servingTeam: TeamSide.e2,
        servingPlayerId: 'p3',
      );
      expect(outcome.winner, TeamSide.e2);
      expect(outcome.faulterId, 'p2');
      expect(outcome.isServiceFault, isFalse);
    });

    test('a serve landing out is charged to the server', () {
      final outcome = PointResolution.outOfBounds(
        impacts: [
          _touch(TeamSide.e2, serverPos: true, player: 'p3'),
          _touch(TeamSide.e2, player: 'p3'),
        ],
        servingTeam: TeamSide.e2,
        servingPlayerId: 'p3',
      );
      expect(outcome.winner, TeamSide.e1);
      expect(outcome.faulterId, 'p3');
      expect(outcome.isServiceFault, isFalse);
    });
  });

  group('PointResolution.landedIn', () {
    test('the side that let the ball land loses the point', () {
      expect(
        PointResolution.landedIn(landingSide: TeamSide.e1).winner,
        TeamSide.e2,
      );
      expect(
        PointResolution.landedIn(landingSide: TeamSide.e2).winner,
        TeamSide.e1,
      );
    });
  });
}
