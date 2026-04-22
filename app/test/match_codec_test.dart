import 'dart:convert';

import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/persistence/match_codec.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('codec roundtrips a non-trivial match state', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(matchProvider.notifier)
      ..startMatch(
        teamE1Name: 'Rouges',
        teamE2Name: 'Verts',
        p1: 'Ana', p2: 'Sara', p3: 'Léa', p4: 'Marie',
        initialServerId: 'p3',
      )
      ..addBallImpact(const BallImpact(
        x: 0.75,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e2,
        playerId: 'p3',
      ))
      ..addBallImpact(const BallImpact(
        x: 0.25,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        playerId: 'p1',
      ))
      ..addPoint(winner: TeamSide.e2)
      ..addPoint(winner: TeamSide.e2)
      ..setNotes('vent nord');
    final original = c.read(matchProvider);

    final json = jsonEncode(MatchCodec.toJson(original));
    final restored = MatchCodec.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );

    expect(restored.teams[TeamSide.e1]!.name, 'Rouges');
    expect(restored.teams[TeamSide.e2]!.name, 'Verts');
    expect(restored.scoreE2, original.scoreE2);
    expect(restored.scoreE1, original.scoreE1);
    expect(restored.servingPlayerId, original.servingPlayerId);
    expect(restored.history.length, original.history.length);
    expect(restored.history.first.winner, TeamSide.e2);
    expect(restored.history.first.impacts.length, 2);
    expect(restored.history.first.impacts.first.teamSide, TeamSide.e2);
    expect(restored.notes, 'vent nord');
    expect(restored.setNumber, 1);
  });

  test('codec roundtrips a completed set', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final notifier = c.read(matchProvider.notifier)
      ..startMatch(
        teamE1Name: 'A',
        teamE2Name: 'B',
        p1: 'a', p2: 'b', p3: 'c', p4: 'd',
        initialServerId: 'p3',
      );
    for (var i = 0; i < 21; i++) {
      notifier.addPoint(winner: TeamSide.e2);
    }
    notifier.startNextSet();
    final original = c.read(matchProvider);

    final restored = MatchCodec.fromJson(MatchCodec.toJson(original));
    expect(restored.sets.length, 1);
    expect(restored.sets.first.winner, TeamSide.e2);
    expect(restored.sets.first.scoreE2, 21);
    expect(restored.setNumber, 2);
    expect(restored.scoreE1, 0);
    expect(restored.scoreE2, 0);
    expect(restored.sidesSwapped, original.sidesSwapped);
  });
}
