import 'package:app/features/match/domain/match_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DragState {
  const DragState({
    required this.playerId,
    this.pos,
    this.armed = false,
  });

  final String playerId;
  final CourtPos? pos;
  final bool armed;

  DragState copyWith({CourtPos? pos, bool? armed}) => DragState(
        playerId: playerId,
        pos: pos ?? this.pos,
        armed: armed ?? this.armed,
      );
}

final dragPreviewProvider =
    NotifierProvider<DragPreviewNotifier, DragState?>(DragPreviewNotifier.new);

class DragPreviewNotifier extends Notifier<DragState?> {
  @override
  DragState? build() => null;

  void start(String playerId) => state = DragState(playerId: playerId);

  void move(CourtPos pos, {required bool armed}) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(pos: pos, armed: armed);
  }

  void clear() => state = null;
}
