import 'package:app/core/theme.dart';
import 'package:app/domain/date_format.dart';
import 'package:app/domain/match_archive.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/features/match_history/screens/match_replay_screen.dart';
import 'package:flutter/material.dart';

class RecentMatchCard extends StatelessWidget {
  const RecentMatchCard({required this.archive, super.key});

  final MatchArchive archive;

  @override
  Widget build(BuildContext context) {
    final s = archive.state;
    final nameE1 = s.teams[TeamSide.e1]!.name;
    final nameE2 = s.teams[TeamSide.e2]!.name;
    final setsE1 = s.setsWonOf(TeamSide.e1);
    final setsE2 = s.setsWonOf(TeamSide.e2);

    return Material(
      color: MH.sand,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MatchReplayScreen(archive: archive),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$nameE1 vs $nameE2',
                      style: MH.sans(weight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatMatchDate(archive.startedAt),
                      style: MH.mono(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$setsE1 – $setsE2',
                style: MH.mono(size: 16, weight: FontWeight.w800, color: MH.ink),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 16, color: MH.pencil),
            ],
          ),
        ),
      ),
    );
  }
}
