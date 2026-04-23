import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';

/// Read-only wrapper around [MatchNotifier] for viewing archived matches.
/// All write operations are no-ops. [selectPoint] syncs the displayed score
/// with the selected point; [clearSelection] restores the final match state.
class ReplayNotifier extends MatchNotifier {
  ReplayNotifier(this._initial);
  final MatchState _initial;

  @override
  MatchState build() => _initial;

  @override
  void startMatch({
    required String teamE1Name,
    required String teamE2Name,
    required String p1,
    required String p2,
    required String p3,
    required String p4,
    required String initialServerId,
  }) {}

  @override
  void addPoint({
    required TeamSide winner,
    List<Annotation> annotations = const [],
  }) {}

  @override
  void pickFirstServer(String playerId) {}

  @override
  void startNextSet() {}

  @override
  void addRallyAnnotation(Annotation a) {}

  @override
  void addTouchWithPlayer(BallImpact impact) {}

  @override
  void confirmPlayerPick(String playerId) {}

  @override
  void addBallImpact(BallImpact impact) {}

  @override
  void undoLastImpact() {}

  @override
  void undoPoint() {}

  @override
  void clearRally() {}

  @override
  void setNotes(String notes) {}

  @override
  void swapSides() {}

  @override
  void swapTeammates(String playerId) {}

  @override
  void dismissChangeSideForever() {}

  @override
  void closeChangeSidePrompt() {}

  @override
  void renamePlayer(String playerId, String name) {}

  @override
  void renameTeam(TeamSide teamKey, String name) {}

  @override
  void selectPoint(int index) {
    final p = state.history[index];
    state = state.copyWith(
      selectedPointIndex: index,
      scoreE1: p.scoreE1,
      scoreE2: p.scoreE2,
      setNumber: p.setNumber,
    );
  }

  @override
  void clearSelection() => state = _initial;

  @override
  void toggleTeamTracking(TeamSide teamSide) {}

  @override
  void showPopup(MatchPopup popup) {}

  @override
  void dismissPopup() {}
}
