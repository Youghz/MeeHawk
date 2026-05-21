import 'package:app/features/match/domain/match_state.dart';

class MatchArchive {
  const MatchArchive({
    required this.id,
    required this.startedAt,
    required this.state,
    this.videoUrl,
  });

  final String id;
  final DateTime startedAt;
  final MatchState state;
  final String? videoUrl;

  MatchArchive copyWith({String? videoUrl}) => MatchArchive(
        id: id,
        startedAt: startedAt,
        state: state,
        videoUrl: videoUrl,
      );
}
