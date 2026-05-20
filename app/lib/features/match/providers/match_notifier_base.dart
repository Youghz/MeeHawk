import 'package:app/features/match/domain/match_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract base shared by the live-match notifier and the replay notifier.
/// All mutation methods default to no-ops here so that replay is safe by
/// construction: new methods are no-ops unless explicitly overridden.
abstract class MatchNotifierBase extends Notifier<MatchState> {
  // ── Selection — meaningful in both live and replay contexts ──────────────

  void selectPoint(int index);
  void clearSelection();

  /// Show the final score of [setNumber]. Live match ignores this; replay
  /// overrides it to scroll the scoreboard without selecting a point.
  void viewSet(int setNumber) {}

  // ── Mutations — no-op by default (replay-safe) ───────────────────────────
  // MatchNotifier overrides every method below with a real implementation.

  void startMatch({
    required String teamE1Name,
    required String teamE2Name,
    required String p1,
    required String p2,
    required String p3,
    required String p4,
    required String initialServerId,
    MatchFormat format = MatchFormat.beachFivb,
  }) {}
  void addPoint({
    required TeamSide winner,
    List<Annotation> annotations = const [],
  }) {}
  void pickFirstServer(String playerId) {}
  void startNextSet() {}
  void addRallyAnnotation(Annotation a) {}
  void addTouchWithPlayer(BallImpact impact) {}
  void confirmPlayerPick(String playerId) {}
  void addBallImpact(BallImpact impact) {}
  void undoLastImpact() {}
  void undoPoint() {}
  void clearRally() {}
  void setNotes(String notes) {}
  void swapSides() {}
  void swapTeammates(String playerId) {}
  void dismissChangeSideForever() {}
  void closeChangeSidePrompt() {}
  void renamePlayer(String playerId, String name) {}
  void renameTeam(TeamSide teamKey, String name) {}
  void toggleTeamTracking(TeamSide teamSide) {}
  void showPopup(MatchPopup popup) {}
  void dismissPopup() {}
  void resumeMatch(MatchState savedState) {}
  void resetMatch() {}
}
