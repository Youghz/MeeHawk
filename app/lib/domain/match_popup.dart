import 'dart:ui';

import 'package:app/domain/entities.dart';


import 'package:app/domain/rules/team_side.dart';

/// A modal popup request held in the match state. UI-adjacent but lives
/// in the domain layer because the scoring flow (e.g. first-server pick)
/// defers point commits on popup state.
///
/// Sealed so that switch expressions in callers are exhaustively checked by
/// the compiler — new popup kinds are impossible to forget.
sealed class MatchPopup {
  const MatchPopup({required this.winner});
  final TeamSide winner;
}

final class FaultPopup extends MatchPopup {
  const FaultPopup({
    required super.winner,
    required this.playerId,
    required this.tapPos,
  });
  final String playerId;
  final Offset tapPos;
}

final class PickServerPopup extends MatchPopup {
  const PickServerPopup({
    required super.winner,
    this.pendingAnnotations = const [],
  });
  final List<Annotation> pendingAnnotations;
}

final class PickPlayerPopup extends MatchPopup {
  const PickPlayerPopup({
    required super.winner,
    required this.tapPos,
    required this.pendingImpact,
  });
  final Offset tapPos;
  final BallImpact pendingImpact;
}

final class SetEndPopup extends MatchPopup {
  const SetEndPopup({required super.winner});
}

final class MatchEndPopup extends MatchPopup {
  const MatchEndPopup({required super.winner});
}
