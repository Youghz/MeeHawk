import 'dart:convert';
import 'dart:io';

import 'package:app/data/match_codec.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/state/match_notifier_base.dart';
import 'package:app/state/match_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replays `parity/scenario.json` and locks the resulting state into
/// `parity/expected_state.json`.
///
/// The Python port (`annotator/tests/test_parity.py`) replays the exact same
/// scenario and asserts against the same golden file. That is what makes the
/// Dart↔Python parity rule enforceable instead of a matter of discipline.
///
/// Regenerate the golden after an intentional rule change:
///   UPDATE_PARITY_GOLDEN=1 flutter test test/parity_test.dart
/// then re-run the Python test — a failure there means the port did not follow.
void main() {
  final parityDir = Directory('${Directory.current.parent.path}/parity');
  final scenarioFile = File('${parityDir.path}/scenario.json');
  final goldenFile = File('${parityDir.path}/expected_state.json');

  test('scenario replay matches the shared golden state', () {
    final scenario =
        jsonDecode(scenarioFile.readAsStringSync()) as Map<String, dynamic>;
    final actions = (scenario['actions'] as List).cast<Map<String, dynamic>>();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(matchProvider.notifier);

    for (final action in actions) {
      _apply(notifier, container, action);
    }

    final produced = MatchCodec.toJson(container.read(matchProvider))
      // startedAt is DateTime.now() on both sides and can never match.
      ..remove('startedAt');
    final encoded = const JsonEncoder.withIndent('  ').convert(produced);

    if (Platform.environment['UPDATE_PARITY_GOLDEN'] == '1') {
      goldenFile.writeAsStringSync('$encoded\n');
      // Regenerating is an explicit, interactive action — the operator needs
      // to see which file was rewritten.
      // ignore: avoid_print
      print('Golden regenerated → ${goldenFile.path}');
      return;
    }

    expect(
      goldenFile.existsSync(),
      isTrue,
      reason: 'Missing golden. Run with UPDATE_PARITY_GOLDEN=1 to create it.',
    );
    expect(
      jsonDecode(encoded),
      jsonDecode(goldenFile.readAsStringSync()),
      reason: 'Scenario replay drifted from the golden state.',
    );
  });
}

/// Executes one scenario action against [notifier].
///
/// Two interactive behaviours are resolved the way the Python agent resolves
/// them, so the comparison covers game rules rather than interaction style —
/// see parity/README.md.
void _apply(
  MatchNotifierBase notifier,
  ProviderContainer container,
  Map<String, dynamic> action,
) {
  // Comment entries carry no `op`.
  final op = action['op'] as String?;
  if (op == null) return;

  switch (op) {
    case 'start_match':
      notifier.startMatch(
        teamE1Name: action['teamE1Name'] as String,
        teamE2Name: action['teamE2Name'] as String,
        p1: action['p1'] as String,
        p2: action['p2'] as String,
        p3: action['p3'] as String,
        p4: action['p4'] as String,
        initialServerId: action['initialServerId'] as String,
      );
    case 'impact':
      notifier.addBallImpact(
        BallImpact(
          x: (action['x'] as num).toDouble(),
          y: (action['y'] as num).toDouble(),
          teamSide: TeamSide.fromKey(action['teamSide'] as String),
          isOutside: action['isOutside'] as bool? ?? false,
          isServerPosition: action['isServerPosition'] as bool? ?? false,
          isBlock: action['isBlock'] as bool? ?? false,
          playerId: action['playerId'] as String?,
        ),
      );
      _settle(notifier, container);
    case 'point':
      notifier.addPoint(winner: TeamSide.fromKey(action['winner'] as String));
      _settle(notifier, container);
    case 'repeat_points':
      final winner = TeamSide.fromKey(action['winner'] as String);
      for (var i = 0; i < (action['count'] as int); i++) {
        notifier.addPoint(winner: winner);
        _settle(notifier, container);
      }
    case 'undo_impact':
      notifier.undoLastImpact();
    case 'undo_point':
      notifier.undoPoint();
    case 'clear_rally':
      notifier.clearRally();
    default:
      fail('Unknown scenario op: $op');
  }
}

/// Resolves the popups the live UI would show, matching the agent's rules.
///
/// - First-server pick → the player the agent auto-assigns (`nextServerIndex`).
/// - Set end → start the next set immediately.
void _settle(MatchNotifierBase notifier, ProviderContainer container) {
  for (var guard = 0; guard < 4; guard++) {
    final state = container.read(matchProvider);
    switch (state.popup) {
      case final PickServerPopup popup:
        final players = state.teams[popup.winner]!.players;
        final index = state.nextServerIndex[popup.winner]!;
        notifier.pickFirstServer(players[index % players.length].id);
      case SetEndPopup():
        notifier.startNextSet();
      case _:
        return;
    }
  }
  fail('Popups did not settle — possible loop in the scoring state machine.');
}
