import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_notifier_base.dart';

/// Read-only notifier for viewing archived matches. Inherits replay-safe
/// no-ops from [MatchNotifierBase] for all mutations. Only meaningful
/// operations are implemented: [selectPoint], [clearSelection], [viewSet].
class ReplayNotifier extends MatchNotifierBase {
  ReplayNotifier(this._initial);
  final MatchState _initial;

  @override
  MatchState build() => _initial;

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
  void viewSet(int setNumber) {
    final record = _initial.sets.firstWhere(
      (s) => s.setNumber == setNumber,
      orElse: () => _initial.sets.last,
    );
    state = state.copyWith(
      scoreE1: record.scoreE1,
      scoreE2: record.scoreE2,
      setNumber: setNumber,
      selectedPointIndex: null,
    );
  }
}
