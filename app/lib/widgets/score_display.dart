import 'package:flutter/material.dart';
import '../theme.dart';

class ScoreDisplay extends StatelessWidget {
  final String teamUsName;
  final String teamThemName;
  final String playerA;
  final String playerB;
  final String opponentA;
  final String opponentB;
  final int scoreUs;
  final int scoreThem;
  final int setNumber;
  final String servingTeam;
  final String? servingPlayer;
  final VoidCallback onUndo;
  final VoidCallback onNextSet;
  final VoidCallback onToggleServing;
  final ValueChanged<String> onTeamUsNameChanged;
  final ValueChanged<String> onTeamThemNameChanged;

  const ScoreDisplay({
    super.key,
    required this.teamUsName,
    required this.teamThemName,
    required this.playerA,
    required this.playerB,
    required this.opponentA,
    required this.opponentB,
    required this.scoreUs,
    required this.scoreThem,
    required this.setNumber,
    required this.servingTeam,
    required this.servingPlayer,
    required this.onUndo,
    required this.onNextSet,
    required this.onToggleServing,
    required this.onTeamUsNameChanged,
    required this.onTeamThemNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Left team — fixed width
          SizedBox(
            width: 160,
            child: _teamBlock(
              context: context,
              teamName: teamUsName,
              score: scoreUs,
              color: AppColors.green,
              isServing: servingTeam == 'us',
              serverName: servingTeam == 'us' ? servingPlayer : null,
              onTeamNameChanged: onTeamUsNameChanged,
            ),
          ),
          // Center dash
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('—', style: TextStyle(fontSize: 20, color: AppColors.textMuted)),
          ),
          // Right team — fixed width
          SizedBox(
            width: 160,
            child: _teamBlock(
              context: context,
              teamName: teamThemName,
              score: scoreThem,
              color: AppColors.red,
              isServing: servingTeam == 'them',
              serverName: servingTeam == 'them' ? servingPlayer : null,
              onTeamNameChanged: onTeamThemNameChanged,
            ),
          ),
          const Spacer(),
          // Controls
          GestureDetector(
            onTap: onToggleServing,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_horiz, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Serv', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Set $setNumber',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, size: 18),
            tooltip: 'Next set',
            color: AppColors.textSecondary,
            onPressed: onNextSet,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            tooltip: 'Undo',
            color: AppColors.textSecondary,
            onPressed: onUndo,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _teamBlock({
    required BuildContext context,
    required String teamName,
    required int score,
    required Color color,
    required bool isServing,
    required String? serverName,
    required ValueChanged<String> onTeamNameChanged,
  }) {
    return Row(
      children: [
        // Info column — fixed content, same height always
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ball — always takes space, visible only when serving
              Icon(
                Icons.sports_volleyball,
                size: 16,
                color: isServing ? AppColors.orange : Colors.transparent,
              ),
              const SizedBox(height: 2),
              // Team name — always visible, editable
              GestureDetector(
                onTap: () => _editName(context, teamName, onTeamNameChanged),
                child: Text(teamName,
                    style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 2),
              // Badge — fixed height, content changes
              SizedBox(
                height: 14,
                child: isServing
                    ? Text(
                        serverName != null ? 'SERVICE $serverName' : 'SERVICE',
                        style: const TextStyle(fontSize: 8, color: AppColors.orange, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      )
                    : const Text(
                        'RECEPTION',
                        style: TextStyle(fontSize: 8, color: AppColors.accent, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Score — fixed position
        Text('$score',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  void _editName(BuildContext context, String current, ValueChanged<String> onChanged) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Modifier', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          onSubmitted: (v) { if (v.trim().isNotEmpty) onChanged(v.trim()); Navigator.of(ctx).pop(); },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          TextButton(onPressed: () { final v = controller.text.trim(); if (v.isNotEmpty) onChanged(v); Navigator.of(ctx).pop(); }, child: const Text('OK')),
        ],
      ),
    );
  }
}
