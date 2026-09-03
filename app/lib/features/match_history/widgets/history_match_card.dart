import 'package:app/core/theme.dart';
import 'package:app/domain/date_format.dart';
import 'package:app/domain/match_archive.dart';
import 'package:app/domain/match_name.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/features/match_history/screens/match_replay_screen.dart';
import 'package:flutter/material.dart';

class HistoryMatchCard extends StatelessWidget {
  const HistoryMatchCard({required this.archive, super.key});
  final MatchArchive archive;

  @override
  Widget build(BuildContext context) {
    final state = archive.state;
    final e1 = state.teams[TeamSide.e1]!;
    final e2 = state.teams[TeamSide.e2]!;
    final setsE1 = state.setsWonOf(TeamSide.e1);
    final setsE2 = state.setsWonOf(TeamSide.e2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: MH.paper,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MatchReplayScreen(archive: archive),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: MH.rule, width: 1.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            matchCodeName(archive.id),
                            style: MH.sans(
                              size: 13,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatMatchDate(archive.startedAt),
                            style: MH.mono(),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'REPLAY',
                      style: MH.sans(
                        size: 9,
                        weight: FontWeight.w700,
                        color: MH.ball,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.play_circle_outline,
                        size: 14, color: MH.ball),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _TeamBlock(team: e1, side: TeamSide.e1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$setsE1 – $setsE2',
                            style: MH.mono(
                              size: 22,
                              weight: FontWeight.w800,
                              color: MH.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _setScores(state),
                            style: MH.mono(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _TeamBlock(
                        team: e2,
                        side: TeamSide.e2,
                        rightAlign: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${state.history.length} échanges',
                      style: MH.mono(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _setScores(MatchState s) =>
      s.sets.map((r) => '${r.scoreE1}–${r.scoreE2}').join('  ·  ');
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.team,
    required this.side,
    this.rightAlign = false,
  });
  final Team team;
  final TeamSide side;
  final bool rightAlign;

  @override
  Widget build(BuildContext context) {
    final color = side == TeamSide.e1 ? MH.them : MH.us;
    final playerNames = team.players.map((p) => p.name).join(' · ');
    return Row(
      mainAxisAlignment:
          rightAlign ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: rightAlign
          ? [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      team.name,
                      textAlign: TextAlign.end,
                      style: MH.sans(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playerNames,
                      textAlign: TextAlign.end,
                      style: MH.sans(size: 11, color: MH.pencil),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 4, height: 36, color: color),
            ]
          : [
              Container(width: 4, height: 36, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: MH.sans(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playerNames,
                      style: MH.sans(size: 11, color: MH.pencil),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
    );
  }
}
