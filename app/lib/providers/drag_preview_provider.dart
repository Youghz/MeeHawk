import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';

class DragState {
  final String playerId;
  final CourtPos? pos;
  final bool armed;
  const DragState({
    required this.playerId,
    this.pos,
    this.armed = false,
  });

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

  void move(CourtPos pos, bool armed) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(pos: pos, armed: armed);
  }

  void clear() => state = null;
}
