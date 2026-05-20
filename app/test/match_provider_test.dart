// Behavior tests for volleyball scoring rules and annotation logic.
//
// These tests document expected behavior as an executable spec. They drive
// the MatchNotifier directly (no UI) so they are fast and deterministic.

import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_notifier_base.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MatchNotifierBase notifier(ProviderContainer c) => c.read(matchProvider.notifier);
MatchState state(ProviderContainer c) => c.read(matchProvider);

ProviderContainer newMatch({String firstServer = 'p3'}) {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  notifier(c).startMatch(
    teamE1Name: 'E1',
    teamE2Name: 'E2',
    p1: 'A', p2: 'B', p3: 'C', p4: 'D',
    initialServerId: firstServer,
  );
  return c;
}

BallImpact impact(double x, double y,
        {required TeamSide side, bool out = false, String? playerId}) =>
    BallImpact(x: x, y: y, isOutside: out, teamSide: side, playerId: playerId);

/// Award `count` points to `winner`, resolving pickFirstServer popups by
/// defaulting to the first player of the winning team. Use for quickly
/// building up a set state.
void awardPoints(ProviderContainer c, TeamSide winner, int count) {
  for (var i = 0; i < count; i++) {
    notifier(c).addPoint(winner: winner);
    if (state(c).popup is PickServerPopup) {
      final team = state(c).teams[winner]!;
      notifier(c).pickFirstServer(team.players.first.id);
    }
  }
}

void main() {
  group('Service rotation', () {
    test('same player keeps serving while his team wins', () {
      final c = newMatch();
      expect(state(c).servingPlayerId, 'p3');
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).servingPlayerId, 'p3');
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).servingPlayerId, 'p3');
    });

    test('first side-out triggers pickServer popup, not a committed point', () {
      final c = newMatch();
      notifier(c).addPoint(winner: TeamSide.e1);
      expect(state(c).popup, isA<PickServerPopup>());
      expect(state(c).popup?.winner, TeamSide.e1);
      expect(state(c).history, isEmpty);
      expect(state(c).scoreE1, 0);
    });

    test('pickFirstServer commits the pending point and sets server', () {
      final c = newMatch();
      notifier(c).addPoint(winner: TeamSide.e1);
      notifier(c).pickFirstServer('p2');
      expect(state(c).popup, isNull);
      expect(state(c).history.length, 1);
      expect(state(c).servingPlayerId, 'p2');
      expect(state(c).scoreE1, 1);
    });

    test('2nd side-out back to a team alternates to the other player', () {
      final c = newMatch();
      notifier(c).addPoint(winner: TeamSide.e1);
      notifier(c).pickFirstServer('p1');
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).servingPlayerId, 'p4');
      notifier(c).addPoint(winner: TeamSide.e1);
      expect(state(c).servingPlayerId, 'p2');
      notifier(c).addPoint(winner: TeamSide.e1);
      expect(state(c).servingPlayerId, 'p2');
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).servingPlayerId, 'p3');
    });

    test('pickFirstServer ignored when no popup is open', () {
      final c = newMatch();
      notifier(c).pickFirstServer('p1');
      expect(state(c).history, isEmpty);
    });
  });

  group('Score tracking', () {
    test('addPoint increments the right team score', () {
      final c = newMatch();
      notifier(c).addPoint(winner: TeamSide.e2);
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).scoreE2, 2);
      expect(state(c).scoreE1, 0);
    });

    test('history records per-set score and serverId', () {
      final c = newMatch();
      notifier(c).addPoint(winner: TeamSide.e2);
      final p = state(c).history.last;
      expect(p.scoreE2, 1);
      expect(p.serverId, 'p3');
      expect(p.setNumber, 1);
    });
  });

  group('Undo', () {
    test('undo removes last point', () {
      final c = newMatch();
      notifier(c).addPoint(winner: TeamSide.e2);
      notifier(c).addPoint(winner: TeamSide.e2);
      notifier(c).undoPoint();
      expect(state(c).scoreE2, 1);
      expect(state(c).history.length, 1);
    });

    test('undo reconstructs the correct server after side-outs', () {
      final c = newMatch();
      notifier(c).addPoint(winner: TeamSide.e1);
      notifier(c).pickFirstServer('p1');
      notifier(c).addPoint(winner: TeamSide.e2);
      notifier(c).addPoint(winner: TeamSide.e1);
      expect(state(c).servingPlayerId, 'p2');
      notifier(c).undoPoint();
      expect(state(c).servingPlayerId, 'p4');
      notifier(c).undoPoint();
      expect(state(c).servingPlayerId, 'p1');
    });

    test('undo on empty history is a no-op', () {
      final c = newMatch();
      notifier(c).undoPoint();
      expect(state(c).history, isEmpty);
    });

    test('undo after a won set restores set state', () {
      final c = newMatch();
      awardPoints(c, TeamSide.e2, 20);
      awardPoints(c, TeamSide.e1, 1);
      // e1 must pick first server before committing the point.
      if (state(c).popup is PickServerPopup) {
        notifier(c).pickFirstServer('p1');
      }
      expect(state(c).scoreE1, 1);
      expect(state(c).scoreE2, 20);
      // Two more for e2 → 21, set over.
      awardPoints(c, TeamSide.e2, 1);
      expect(state(c).popup, isA<SetEndPopup>());
      notifier(c).undoPoint();
      expect(state(c).popup, isNull);
      expect(state(c).scoreE2, 20);
      expect(state(c).sets, isEmpty);
      expect(state(c).setNumber, 1);
    });
  });

  group('Rally impacts & auto-annotation', () {
    test('first cross-net impact is annotated as Service', () {
      final c = newMatch();
      notifier(c)
          .addBallImpact(impact(0.75, 0.5, side: TeamSide.e2, playerId: 'p3'));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      final annots = state(c).rallyAnnotations;
      expect(annots.length, 1);
      expect(annots.first.type, 'service');
      expect(annots.first.text, contains('Service'));
    });

    test('subsequent cross-net impact is annotated as Attaque', () {
      final c = newMatch();
      notifier(c)
          .addBallImpact(impact(0.75, 0.5, side: TeamSide.e2, playerId: 'p3'));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c)
          .addBallImpact(impact(0.30, 0.5, side: TeamSide.e1, playerId: 'p1'));
      notifier(c).addBallImpact(impact(0.70, 0.5, side: TeamSide.e2));
      final annots = state(c).rallyAnnotations;
      expect(annots.length, 2);
      expect(annots.last.type, 'attack');
      expect(annots.last.text, contains('Attaque'));
    });

    test('same-side consecutive impacts are not annotated', () {
      final c = newMatch();
      notifier(c)
          .addBallImpact(impact(0.25, 0.3, side: TeamSide.e1, playerId: 'p1'));
      notifier(c)
          .addBallImpact(impact(0.25, 0.5, side: TeamSide.e1, playerId: 'p2'));
      notifier(c)
          .addBallImpact(impact(0.25, 0.7, side: TeamSide.e1, playerId: 'p1'));
      expect(state(c).rallyAnnotations, isEmpty);
    });

    test('impacts cleared on point commit', () {
      final c = newMatch();
      notifier(c).addBallImpact(impact(0.75, 0.5, side: TeamSide.e2));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      expect(state(c).rallyImpacts.length, 2);
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).rallyImpacts, isEmpty);
      expect(state(c).rallyAnnotations, isEmpty);
    });

    test('netCrossings counts net crossings (not touches)', () {
      final c = newMatch();
      notifier(c).addBallImpact(impact(0.75, 0.5, side: TeamSide.e2)); // serve
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1)); // +1
      notifier(c).addBallImpact(impact(0.20, 0.4, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.30, 0.5, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.70, 0.5, side: TeamSide.e2)); // +2
      notifier(c).addBallImpact(impact(0.30, 0.5, side: TeamSide.e1)); // +3
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).history.last.netCrossings, 3);
    });

    test('rallyImpacts preserved in point record', () {
      final c = newMatch();
      notifier(c).addBallImpact(impact(0.75, 0.5, side: TeamSide.e2));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).history.last.impacts.length, 2);
    });
  });

  group('Change-side prompt', () {
    test('regular set: every 7 total points', () {
      final c = newMatch();
      for (var i = 0; i < 6; i++) {
        notifier(c).addPoint(winner: TeamSide.e2);
      }
      expect(state(c).changeSidePromptOpen, isFalse);
      notifier(c).addPoint(winner: TeamSide.e2);
      expect(state(c).changeSidePromptOpen, isTrue);
    });

    test('deciding set 3: every 5 total points', () {
      final c = newMatch();
      // Win set 1 for e2 (21-0).
      awardPoints(c, TeamSide.e2, 21);
      expect(state(c).popup, isA<SetEndPopup>());
      notifier(c).startNextSet();
      // Win set 2 for e1 (21-0).
      awardPoints(c, TeamSide.e1, 21);
      notifier(c).startNextSet();
      expect(state(c).setNumber, 3);
      // In set 3, prompt at total = 5.
      awardPoints(c, TeamSide.e2, 4);
      expect(state(c).changeSidePromptOpen, isFalse);
      awardPoints(c, TeamSide.e2, 1);
      expect(state(c).changeSidePromptOpen, isTrue);
    });

    test('dismissChangeSideForever prevents future prompts within set', () {
      final c = newMatch();
      for (var i = 0; i < 7; i++) {
        notifier(c).addPoint(winner: TeamSide.e2);
      }
      expect(state(c).changeSidePromptOpen, isTrue);
      notifier(c).dismissChangeSideForever();
      for (var i = 0; i < 7; i++) {
        notifier(c).addPoint(winner: TeamSide.e2);
      }
      expect(state(c).changeSidePromptOpen, isFalse);
    });
  });

  group('Set / match end', () {
    test('set is won at 21 with 2-point lead', () {
      final c = newMatch();
      awardPoints(c, TeamSide.e2, 20);
      awardPoints(c, TeamSide.e1, 20);
      if (state(c).popup is PickServerPopup) {
        notifier(c).pickFirstServer('p1');
      }
      expect(state(c).scoreE1, 20);
      expect(state(c).scoreE2, 20);
      notifier(c).addPoint(winner: TeamSide.e1);
      // 21-20 — not enough gap yet.
      expect(state(c).popup, isNull);
      expect(state(c).scoreE1, 21);
      notifier(c).addPoint(winner: TeamSide.e2);
      // 21-21 — still no.
      expect(state(c).popup, isNull);
      notifier(c).addPoint(winner: TeamSide.e1);
      notifier(c).addPoint(winner: TeamSide.e1);
      // 23-21 → set over.
      expect(state(c).popup, isA<SetEndPopup>());
      expect(state(c).sets.length, 1);
      expect(state(c).sets.first.winner, TeamSide.e1);
    });

    test('startNextSet resets points, bumps set number, auto-swaps sides', () {
      final c = newMatch();
      awardPoints(c, TeamSide.e2, 21);
      final swappedBefore = state(c).sidesSwapped;
      notifier(c).startNextSet();
      expect(state(c).popup, isNull);
      expect(state(c).setNumber, 2);
      expect(state(c).scoreE1, 0);
      expect(state(c).scoreE2, 0);
      expect(state(c).sidesSwapped, !swappedBefore);
    });

    test('match ends at 2 sets to 0 and disables scoring', () {
      final c = newMatch();
      awardPoints(c, TeamSide.e2, 21);
      notifier(c).startNextSet();
      awardPoints(c, TeamSide.e2, 21);
      expect(state(c).popup, isA<MatchEndPopup>());
      expect(state(c).matchOver, isTrue);
      // Further addPoint is a no-op.
      notifier(c).addPoint(winner: TeamSide.e1);
      expect(state(c).scoreE1, 0);
    });

    test('deciding set played to 15', () {
      final c = newMatch();
      awardPoints(c, TeamSide.e2, 21);
      notifier(c).startNextSet();
      awardPoints(c, TeamSide.e1, 21);
      notifier(c).startNextSet();
      expect(state(c).setNumber, 3);
      awardPoints(c, TeamSide.e2, 14);
      expect(state(c).popup, isNull);
      awardPoints(c, TeamSide.e2, 1);
      expect(state(c).popup, isA<MatchEndPopup>());
      expect(state(c).sets.last.scoreE2, 15);
    });
  });

  group('Three-touch rule', () {
    test('three consecutive same-side touches are allowed', () {
      final c = newMatch();
      notifier(c).addBallImpact(impact(0.25, 0.3, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.7, side: TeamSide.e1));
      expect(state(c).rallyImpacts.length, 3);
    });

    test('fourth consecutive same-side touch auto-faults to opponent', () {
      // e2 serves first → firstServerIndex[e2] already set → point commits directly.
      final c = newMatch();
      notifier(c).addBallImpact(impact(0.25, 0.3, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.7, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.6, side: TeamSide.e1));
      // Point committed: rally cleared, e2 scores.
      expect(state(c).rallyImpacts, isEmpty);
      expect(state(c).scoreE2, 1);
      expect(state(c).history.last.winner, TeamSide.e2);
      expect(state(c).history.last.annotations.any((a) => a.type == 'fault'), isTrue);
    });

    test('switching sides resets the consecutive count for each team', () {
      final c = newMatch();
      // e1: 3 touches (max)
      notifier(c).addBallImpact(impact(0.25, 0.3, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.7, side: TeamSide.e1));
      // crosses to e2: counter resets for e2
      notifier(c).addBallImpact(impact(0.75, 0.3, side: TeamSide.e2));
      notifier(c).addBallImpact(impact(0.75, 0.5, side: TeamSide.e2));
      notifier(c).addBallImpact(impact(0.75, 0.7, side: TeamSide.e2));
      expect(state(c).rallyImpacts.length, 6);
      // 4th e2 touch auto-faults; e1 gains serve for the first time →
      // pickServer popup defers the commit (rally not yet cleared).
      notifier(c).addBallImpact(impact(0.75, 0.6, side: TeamSide.e2));
      expect(state(c).popup, isA<PickServerPopup>());
      expect(state(c).popup?.winner, TeamSide.e1);
    });

    test('server-position marker does not count toward the 3-touch limit', () {
      final c = newMatch();
      // isServerPosition = true → exempt from the rule
      notifier(c).addBallImpact(const BallImpact(
        x: 0.05, y: 0.5, isOutside: true,
        teamSide: TeamSide.e2, isServerPosition: true,
      ));
      // 3 real touches on e2 are still allowed after the server marker
      notifier(c).addBallImpact(impact(0.75, 0.5, side: TeamSide.e2));
      notifier(c).addBallImpact(impact(0.75, 0.4, side: TeamSide.e2));
      notifier(c).addBallImpact(impact(0.75, 0.6, side: TeamSide.e2));
      expect(state(c).rallyImpacts.length, 4);
      // 4th real e2 touch auto-faults; e1 gains serve for first time →
      // pickServer popup defers the commit.
      notifier(c).addBallImpact(impact(0.75, 0.55, side: TeamSide.e2));
      expect(state(c).popup, isA<PickServerPopup>());
      expect(state(c).popup?.winner, TeamSide.e1);
    });
  });

  group('Swap sides / teammates / rename', () {
    test('swapSides mirrors x and toggles sidesSwapped', () {
      final c = newMatch();
      final before = state(c).positions['p1']!;
      notifier(c).swapSides();
      final after = state(c).positions['p1']!;
      expect(after.x, closeTo(1 - before.x, 1e-9));
      expect(after.y, before.y);
      expect(state(c).sidesSwapped, isTrue);
    });

    test('swapTeammates swaps two teammates positions', () {
      final c = newMatch();
      final p1Before = state(c).positions['p1']!;
      final p2Before = state(c).positions['p2']!;
      notifier(c).swapTeammates('p1');
      expect(state(c).positions['p1']!.x, p2Before.x);
      expect(state(c).positions['p2']!.x, p1Before.x);
    });

    test('renamePlayer updates the player', () {
      final c = newMatch();
      notifier(c).renamePlayer('p1', 'Zoé');
      expect(state(c).playerById('p1')!.name, 'Zoé');
    });

    test('renameTeam updates the team', () {
      final c = newMatch();
      notifier(c).renameTeam(TeamSide.e1, 'Rouges');
      expect(state(c).teams[TeamSide.e1]!.name, 'Rouges');
    });
  });

  group('Scénarios de service (A)', () {
    test('A1: service ace — 1 net crossing, service annotation', () {
      final c = newMatch();
      notifier(c)
          .addBallImpact(impact(0.75, 0.5, side: TeamSide.e2, playerId: 'p3'));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c).addPoint(winner: TeamSide.e2);
      final pt = state(c).history.last;
      expect(pt.netCrossings, 1);
      expect(pt.annotations.any((a) => a.type == 'service'), isTrue);
    });

    test('A2: service fault — ball stays server-side, 0 net crossings', () {
      final c = newMatch();
      notifier(c).addBallImpact(
          impact(0.75, 0.5, side: TeamSide.e2, out: true, playerId: 'p3'));
      // awardPoints resolves the pickServer popup for e1's first win
      awardPoints(c, TeamSide.e1, 1);
      expect(state(c).history.last.netCrossings, 0);
    });

    test('A3: ball out after attack — 2 net crossings, attack annotation', () {
      final c = newMatch();
      notifier(c)
          .addBallImpact(impact(0.75, 0.5, side: TeamSide.e2, playerId: 'p3'));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.4, side: TeamSide.e1));
      notifier(c).addBallImpact(
          impact(0.75, 0.5, side: TeamSide.e2, out: true));
      awardPoints(c, TeamSide.e1, 1);
      final pt = state(c).history.last;
      expect(pt.netCrossings, 2);
      expect(pt.annotations.any((a) => a.type == 'attack'), isTrue);
    });
  });

  group('Bloc (B)', () {
    test('B1: block + same player retouch = 2 touches, no fault', () {
      final c = newMatch();
      notifier(c).addTouchWithPlayer(const BallImpact(
        x: 0.25,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        isBlock: true,
        playerId: 'p1',
      ));
      notifier(c)
          .addBallImpact(impact(0.25, 0.4, side: TeamSide.e1, playerId: 'p1'));
      expect(state(c).rallyImpacts.length, 2);
      expect(state(c).scoreE2, 0);
    });

    test('B2: block + 2 more touches = 3 total, still legal', () {
      final c = newMatch();
      notifier(c).addTouchWithPlayer(const BallImpact(
        x: 0.25,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        isBlock: true,
        playerId: 'p1',
      ));
      notifier(c)
          .addBallImpact(impact(0.25, 0.4, side: TeamSide.e1, playerId: 'p2'));
      notifier(c)
          .addBallImpact(impact(0.25, 0.3, side: TeamSide.e1, playerId: 'p1'));
      expect(state(c).rallyImpacts.length, 3);
      expect(state(c).scoreE2, 0);
    });

    test('B3: block + 3 more touches = 4 total → auto-fault, point to e2', () {
      final c = newMatch();
      notifier(c).addTouchWithPlayer(const BallImpact(
        x: 0.25,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        isBlock: true,
        playerId: 'p1',
      ));
      notifier(c)
          .addBallImpact(impact(0.25, 0.4, side: TeamSide.e1, playerId: 'p2'));
      notifier(c)
          .addBallImpact(impact(0.25, 0.3, side: TeamSide.e1, playerId: 'p1'));
      notifier(c)
          .addBallImpact(impact(0.25, 0.6, side: TeamSide.e1, playerId: 'p2'));
      expect(state(c).rallyImpacts, isEmpty);
      expect(state(c).scoreE2, 1);
      expect(
        state(c).history.last.annotations.any((a) => a.type == 'fault'),
        isTrue,
      );
    });

    test('B4: addTouchWithPlayer(isBlock:true) creates a block annotation', () {
      final c = newMatch();
      notifier(c).addTouchWithPlayer(const BallImpact(
        x: 0.25,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        isBlock: true,
        playerId: 'p1',
      ));
      expect(
        state(c).rallyAnnotations.any((a) => a.type == 'block'),
        isTrue,
      );
    });

    test('B5: provider accepts block as first impact, no contextual validation',
        () {
      final c = newMatch();
      notifier(c).addTouchWithPlayer(const BallImpact(
        x: 0.25,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        isBlock: true,
        playerId: 'p1',
      ));
      expect(state(c).rallyImpacts.length, 1);
      expect(state(c).scoreE2, 0);
    });
  });

  group('undoLastImpact (C)', () {
    test('C1: removes last impact, prior impacts intact', () {
      final c = newMatch();
      notifier(c).addBallImpact(impact(0.75, 0.5, side: TeamSide.e2));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c).undoLastImpact();
      expect(state(c).rallyImpacts.length, 1);
      expect(state(c).rallyImpacts.first.teamSide, TeamSide.e2);
    });

    test('C2: undo after net crossing removes the crossing annotation', () {
      final c = newMatch();
      notifier(c)
          .addBallImpact(impact(0.75, 0.5, side: TeamSide.e2, playerId: 'p3'));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      expect(state(c).rallyAnnotations.length, 1);
      notifier(c).undoLastImpact();
      expect(state(c).rallyAnnotations, isEmpty);
    });

    test('C3: undo block removes impact and block annotation', () {
      final c = newMatch();
      notifier(c).addTouchWithPlayer(const BallImpact(
        x: 0.25,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        isBlock: true,
        playerId: 'p1',
      ));
      expect(state(c).rallyAnnotations.any((a) => a.type == 'block'), isTrue);
      notifier(c).undoLastImpact();
      expect(state(c).rallyImpacts, isEmpty);
      expect(state(c).rallyAnnotations, isEmpty);
    });

    test('C4: no impacts → undoLastImpact is a silent no-op', () {
      final c = newMatch();
      notifier(c).undoLastImpact();
      expect(state(c).rallyImpacts, isEmpty);
      expect(state(c).scoreE1, 0);
      expect(state(c).scoreE2, 0);
    });

    test('C5: double undo on 3 impacts leaves 1 impact, annotations consistent',
        () {
      final c = newMatch();
      notifier(c)
          .addBallImpact(impact(0.75, 0.5, side: TeamSide.e2, playerId: 'p3'));
      notifier(c).addBallImpact(
          impact(0.25, 0.5, side: TeamSide.e1)); // crossing → service annot
      notifier(c).addBallImpact(
          impact(0.25, 0.4, side: TeamSide.e1)); // same side, no annotation
      expect(state(c).rallyImpacts.length, 3);
      expect(state(c).rallyAnnotations.length, 1);
      notifier(c).undoLastImpact(); // remove 3rd (same-side) — no annotation removed
      expect(state(c).rallyImpacts.length, 2);
      expect(state(c).rallyAnnotations.length, 1);
      notifier(c).undoLastImpact(); // remove 2nd (crossing) — removes service annotation
      expect(state(c).rallyImpacts.length, 1);
      expect(state(c).rallyAnnotations, isEmpty);
    });
  });

  group('Combinaisons (D)', () {
    test('D1: full rally with block mid-sequence — no fault, block annotation',
        () {
      final c = newMatch();
      notifier(c)
          .addBallImpact(impact(0.75, 0.5, side: TeamSide.e2, playerId: 'p3'));
      notifier(c).addTouchWithPlayer(const BallImpact(
        x: 0.25,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        isBlock: true,
        playerId: 'p1',
      ));
      notifier(c)
          .addBallImpact(impact(0.25, 0.4, side: TeamSide.e1, playerId: 'p2'));
      notifier(c)
          .addBallImpact(impact(0.25, 0.3, side: TeamSide.e1, playerId: 'p1'));
      notifier(c).addBallImpact(impact(0.75, 0.5, side: TeamSide.e2));
      expect(state(c).rallyImpacts.length, 5);
      expect(
          state(c).rallyAnnotations.any((a) => a.type == 'block'), isTrue);
      expect(state(c).scoreE2, 0);
    });

    test('D2: custom setsToWin=1 — match ends after 1 set', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(matchProvider.notifier).startMatch(
            teamE1Name: 'E1',
            teamE2Name: 'E2',
            p1: 'A',
            p2: 'B',
            p3: 'C',
            p4: 'D',
            initialServerId: 'p3',
            format: const MatchFormat(setsToWin: 1),
          );
      awardPoints(c, TeamSide.e2, 21);
      expect(state(c).popup, isA<MatchEndPopup>());
      expect(state(c).matchOver, isTrue);
    });

    test('D3: auto-fault at 19-20 triggers set end at 19-21', () {
      final c = newMatch();
      awardPoints(c, TeamSide.e2, 20);
      awardPoints(c, TeamSide.e1, 19);
      expect(state(c).scoreE1, 19);
      expect(state(c).scoreE2, 20);
      notifier(c).addBallImpact(impact(0.25, 0.3, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.7, side: TeamSide.e1));
      notifier(c).addBallImpact(impact(0.25, 0.6, side: TeamSide.e1));
      expect(state(c).popup, isA<SetEndPopup>());
      expect(state(c).sets.last.scoreE2, 21);
      expect(state(c).sets.last.winner, TeamSide.e2);
    });

    test('D4: service annotation text includes the server player name', () {
      final c = newMatch(); // p3 = 'C' is the initial server
      notifier(c)
          .addBallImpact(impact(0.75, 0.5, side: TeamSide.e2, playerId: 'p3'));
      notifier(c).addBallImpact(impact(0.25, 0.5, side: TeamSide.e1));
      final serviceAnnot =
          state(c).rallyAnnotations.firstWhere((a) => a.type == 'service');
      expect(serviceAnnot.text, contains('C'));
    });
  });
}
