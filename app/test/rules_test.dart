import 'package:app/core/rules/annotation_rules.dart';
import 'package:app/core/rules/attack_inference.dart';
import 'package:app/core/rules/match_format.dart';
import 'package:app/core/rules/rally_analyzer.dart';
import 'package:app/core/rules/service_rotation.dart';
import 'package:app/core/rules/set_rules.dart';
import 'package:app/core/rules/team_side.dart';
import 'package:app/core/rules/touch_attribution.dart';
import 'package:flutter_test/flutter_test.dart';

class _Impact implements ImpactLike {
  const _Impact(
    this.teamSide, {
    this.isServerPosition = false,
    this.isBlock = false,
    this.playerId,
  });

  @override
  final TeamSide teamSide;
  @override
  final bool isServerPosition;
  @override
  final bool isBlock;
  @override
  final String? playerId;
}

void main() {
  group('SetRules.isSetWon', () {
    const f = MatchFormat.beachFivb;

    test('21 to 19 is a set win', () {
      expect(SetRules.isSetWon(21, 19, 1, f), isTrue);
    });
    test('21 to 20 is NOT a set win (no 2-point lead)', () {
      expect(SetRules.isSetWon(21, 20, 1, f), isFalse);
    });
    test('22 to 20 is a set win', () {
      expect(SetRules.isSetWon(22, 20, 1, f), isTrue);
    });
    test('30 to 29 is not a set win', () {
      expect(SetRules.isSetWon(30, 29, 1, f), isFalse);
    });
    test('deciding set target is 15', () {
      expect(SetRules.isSetWon(15, 13, 3, f), isTrue);
      expect(SetRules.isSetWon(14, 12, 3, f), isFalse);
      expect(SetRules.isSetWon(15, 14, 3, f), isFalse);
    });
  });

  group('SetRules.isMatchWon', () {
    const f = MatchFormat.beachFivb;

    test('2 sets wins the match', () {
      expect(SetRules.isMatchWon(2, 0, f), isTrue);
      expect(SetRules.isMatchWon(2, 1, f), isTrue);
      expect(SetRules.isMatchWon(1, 2, f), isTrue);
    });
    test('1 set is not enough', () {
      expect(SetRules.isMatchWon(1, 1, f), isFalse);
      expect(SetRules.isMatchWon(1, 0, f), isFalse);
    });
  });

  group('SetRules.shouldPromptSideChange', () {
    const f = MatchFormat.beachFivb;

    test('set 1: every 7 points', () {
      expect(
          SetRules.shouldPromptSideChange(
              totalPointsAfter: 7, setNumber: 1, format: f),
          isTrue);
      expect(
          SetRules.shouldPromptSideChange(
              totalPointsAfter: 14, setNumber: 1, format: f),
          isTrue);
      expect(
          SetRules.shouldPromptSideChange(
              totalPointsAfter: 8, setNumber: 1, format: f),
          isFalse);
    });
    test('set 3: every 5 points', () {
      expect(
          SetRules.shouldPromptSideChange(
              totalPointsAfter: 5, setNumber: 3, format: f),
          isTrue);
      expect(
          SetRules.shouldPromptSideChange(
              totalPointsAfter: 10, setNumber: 3, format: f),
          isTrue);
      expect(
          SetRules.shouldPromptSideChange(
              totalPointsAfter: 7, setNumber: 3, format: f),
          isFalse);
    });
    test('0 total never prompts', () {
      expect(
          SetRules.shouldPromptSideChange(
              totalPointsAfter: 0, setNumber: 1, format: f),
          isFalse);
    });
  });

  group('AttackInference.classify', () {
    test('short + same lateral → Amorti', () {
      expect(
          AttackInference.classify(
              fromX: 0.3, fromY: 0.3, toX: 0.6, toY: 0.3),
          'Amorti');
    });
    test('short + opposite lateral → Diagonale', () {
      expect(
          AttackInference.classify(
              fromX: 0.3, fromY: 0.3, toX: 0.6, toY: 0.7),
          'Diagonale');
    });
    test('deep + same lateral → Ligne', () {
      expect(
          AttackInference.classify(
              fromX: 0.3, fromY: 0.3, toX: 0.85, toY: 0.3),
          'Ligne');
    });
    test('deep + opposite lateral → Diagonale', () {
      expect(
          AttackInference.classify(
              fromX: 0.3, fromY: 0.3, toX: 0.85, toY: 0.7),
          'Diagonale');
    });
  });

  group('RallyAnalyzer.netCrossings', () {
    test('fewer than 2 impacts → 0', () {
      expect(RallyAnalyzer.netCrossings([]), 0);
      expect(RallyAnalyzer.netCrossings([const _Impact(TeamSide.e1)]), 0);
    });
    test('serve + receive + attack', () {
      final imps = [
        const _Impact(TeamSide.e2),
        const _Impact(TeamSide.e1),
        const _Impact(TeamSide.e1),
        const _Impact(TeamSide.e2),
      ];
      expect(RallyAnalyzer.netCrossings(imps), 2);
    });
    test('long rally', () {
      final imps = [
        const _Impact(TeamSide.e2),
        const _Impact(TeamSide.e1),
        const _Impact(TeamSide.e1),
        const _Impact(TeamSide.e2),
        const _Impact(TeamSide.e1),
        const _Impact(TeamSide.e2),
      ];
      expect(RallyAnalyzer.netCrossings(imps), 4);
    });
  });

  group('RallyAnalyzer.averageTouchesPerVisit', () {
    test('each side visited once with varying touches', () {
      final imps = [
        const _Impact(TeamSide.e2), // serve
        const _Impact(TeamSide.e1), // receive
        const _Impact(TeamSide.e1), // set
        const _Impact(TeamSide.e1), // attack
        const _Impact(TeamSide.e2), // dig
      ];
      final avg = RallyAnalyzer.averageTouchesPerVisit(imps);
      expect(avg[TeamSide.e1], 3);
      expect(avg[TeamSide.e2], 1);
    });
  });

  group('TouchAttribution.inferNextPlayer', () {
    const players = ['p1', 'p2'];

    test('first touch of visit → null (no prior same-side touch)', () {
      expect(
        TouchAttribution.inferNextPlayer(
          impacts: [
            const _Impact(TeamSide.e2, playerId: 'p3'),
          ],
          side: TeamSide.e1,
          playerIds: players,
        ),
        isNull,
      );
    });

    test('second touch on same side → teammate', () {
      expect(
        TouchAttribution.inferNextPlayer(
          impacts: [
            const _Impact(TeamSide.e2, playerId: 'p3'),
            const _Impact(TeamSide.e1, playerId: 'p1'),
          ],
          side: TeamSide.e1,
          playerIds: players,
        ),
        'p2',
      );
    });

    test('third touch on same side → back to first player', () {
      expect(
        TouchAttribution.inferNextPlayer(
          impacts: [
            const _Impact(TeamSide.e2, playerId: 'p3'),
            const _Impact(TeamSide.e1, playerId: 'p1'),
            const _Impact(TeamSide.e1, playerId: 'p2'),
          ],
          side: TeamSide.e1,
          playerIds: players,
        ),
        'p1',
      );
    });

    test('after a block → same player may touch again', () {
      expect(
        TouchAttribution.inferNextPlayer(
          impacts: [
            const _Impact(TeamSide.e2, playerId: 'p3'),
            const _Impact(TeamSide.e1, playerId: 'p1', isBlock: true),
          ],
          side: TeamSide.e1,
          playerIds: players,
        ),
        'p1',
      );
    });

    test('server-position impact is ignored when inferring', () {
      // srv-pos on e1 then a real e1 touch: still counts as first touch
      expect(
        TouchAttribution.inferNextPlayer(
          impacts: [
            const _Impact(TeamSide.e1, isServerPosition: true, playerId: 'p1'),
          ],
          side: TeamSide.e1,
          playerIds: players,
        ),
        isNull,
      );
    });
  });

  group('ServiceRotation.next', () {
    final players = {
      TeamSide.e1: ['p1', 'p2'],
      TeamSide.e2: ['p3', 'p4'],
    };

    test('server holds serve when their team wins', () {
      final res = ServiceRotation.next(
        currentServerId: 'p3',
        servingTeam: TeamSide.e2,
        winner: TeamSide.e2,
        playersByTeam: players,
        nextServerIndex: {TeamSide.e1: 0, TeamSide.e2: 0},
      );
      expect(res.serverId, 'p3');
    });

    test('side-out rotates to the next player of winning team', () {
      final res = ServiceRotation.next(
        currentServerId: 'p3',
        servingTeam: TeamSide.e2,
        winner: TeamSide.e1,
        playersByTeam: players,
        nextServerIndex: {TeamSide.e1: 0, TeamSide.e2: 0},
      );
      expect(res.serverId, 'p1');
      expect(res.nextIndex[TeamSide.e1], 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AnnotationRules — derived from FIVB rules 2021-2024
  // ─────────────────────────────────────────────────────────────────────────

  group('AnnotationRules — bloc (§14.3, §14.5, §14.6.1)', () {
    // §14.5 — contrer le service est interdit
    test('bloc sur service : invalide', () {
      expect(
        AnnotationRules.isBlockValid(
          opponentContactsThisPossession: 0,
          wasDirectFromService: true,
        ),
        isFalse,
      );
    });

    // §14.6.1 — toucher le ballon avant la frappe d'attaque est une faute
    test('bloc quand adversaire a 0 contact (avant toute attaque) : invalide', () {
      expect(
        AnnotationRules.isBlockValid(
          opponentContactsThisPossession: 0,
          wasDirectFromService: false,
        ),
        isFalse,
      );
    });

    // §14.3 — contrer dans l'espace adverse autorisé après frappe d'attaque
    test('bloc quand adversaire a eu 1 contact (réception) : valide', () {
      expect(
        AnnotationRules.isBlockValid(
          opponentContactsThisPossession: 1,
          wasDirectFromService: false,
        ),
        isTrue,
      );
    });

    test('bloc quand adversaire a eu 3 contacts (réception + passe + attaque) : valide', () {
      expect(
        AnnotationRules.isBlockValid(
          opponentContactsThisPossession: 3,
          wasDirectFromService: false,
        ),
        isTrue,
      );
    });
  });

  group('AnnotationRules — quatre touches (§9.1)', () {
    test('3 touches : pas de faute', () {
      expect(AnnotationRules.isFourTouchesFault(3), isFalse);
    });

    test('4 touches : faute', () {
      expect(AnnotationRules.isFourTouchesFault(4), isTrue);
    });

    test('5 touches : faute', () {
      expect(AnnotationRules.isFourTouchesFault(5), isTrue);
    });
  });

  group('AnnotationRules — touches restantes après bloc (§14.4.1)', () {
    // Le bloc compte comme 1re touche d'équipe ; il reste 2 touches.
    test('2 touches restantes après un bloc', () {
      expect(AnnotationRules.touchesRemainingAfterBlock(), 2);
    });

    test('bloc + 2 autres touches = 3 total, pas de faute', () {
      // 1 (bloc) + 2 (restantes) = 3 ≤ maxTeamTouches
      const blockTouch = 1;
      final remaining = AnnotationRules.touchesRemainingAfterBlock();
      expect(
        AnnotationRules.isFourTouchesFault(blockTouch + remaining),
        isFalse,
      );
    });

    test('bloc + 3 autres touches = 4 total, faute', () {
      const blockTouch = 1;
      expect(AnnotationRules.isFourTouchesFault(blockTouch + 3), isTrue);
    });
  });

  group('AnnotationRules — ace (§6.1.1.1)', () {
    test('0 contact côté réception = ace', () {
      expect(AnnotationRules.isAce(receivingTeamContacts: 0), isTrue);
    });

    test('1 contact côté réception = pas un ace', () {
      expect(AnnotationRules.isAce(receivingTeamContacts: 1), isFalse);
    });

    test('3 contacts côté réception = pas un ace', () {
      expect(AnnotationRules.isAce(receivingTeamContacts: 3), isFalse);
    });
  });

  group("AnnotationRules — types d'attaque interdits (§13.2.3)", () {
    // Le tip (main ouverte, doigts non rigides) est interdit en beach.
    test("tip est un type d'attaque interdit", () {
      expect(AnnotationRules.isAttackTypeForbidden('tip'), isTrue);
    });

    test('diagonale est autorisée', () {
      expect(AnnotationRules.isAttackTypeForbidden('diagonale'), isFalse);
    });

    test('longue ligne est autorisée', () {
      expect(AnnotationRules.isAttackTypeForbidden('longue ligne'), isFalse);
    });
  });

  group('AnnotationRules — constantes de format (§14.5)', () {
    test('contrer le service est interdit', () {
      expect(AnnotationRules.canBlockService, isFalse);
    });

    // §13.2.5 — spécifique beach, n'existe pas en indoor
    test('la passe haute doit être perpendiculaire aux épaules', () {
      expect(AnnotationRules.overhandSetMustBePerpendicular, isTrue);
    });
  });

  group('TeamSide', () {
    test('other toggles between e1 and e2', () {
      expect(TeamSide.e1.other, TeamSide.e2);
      expect(TeamSide.e2.other, TeamSide.e1);
    });
    test('fromKey roundtrips', () {
      expect(TeamSide.fromKey('e1'), TeamSide.e1);
      expect(TeamSide.fromKey('e2'), TeamSide.e2);
      expect(() => TeamSide.fromKey('e3'), throwsArgumentError);
    });
  });
}
