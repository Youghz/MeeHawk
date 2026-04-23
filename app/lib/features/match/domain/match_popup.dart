import 'dart:ui';

import 'package:app/core/rules/team_side.dart';
import 'package:app/features/match/domain/entities.dart';

/// Kinds of modal prompts the match screen can display.
enum PopupKind { fault, pickServer, outsideFault, pickPlayer, setEnd, matchEnd }

/// A modal popup request held in the match state. UI-adjacent but lives
/// in the domain layer because the scoring flow (e.g. first-server pick)
/// defers point commits on popup state.
class MatchPopup {
  const MatchPopup({
    required this.kind,
    required this.winner,
    this.playerId,
    this.tapPos,
    this.pendingAnnotations = const [],
    this.pendingImpact,
  });

  final PopupKind kind;
  final TeamSide winner;
  final String? playerId;
  final Offset? tapPos;
  final List<Annotation> pendingAnnotations;

  /// Pending ball impact waiting for player attribution (pickPlayer popup).
  final BallImpact? pendingImpact;
}
