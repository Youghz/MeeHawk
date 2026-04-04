import 'package:flutter/material.dart';
import '../theme.dart';

class ActionButtons extends StatelessWidget {
  final String playerA;
  final String playerB;
  final String? selectedReceiver;
  final String? selectedAttack;
  final String? selectedBlock;
  final ValueChanged<String> onReceiverSelected;
  final ValueChanged<String> onAttackSelected;
  final ValueChanged<String> onBlockSelected;
  final ValueChanged<String> onScore;

  const ActionButtons({
    super.key,
    required this.playerA,
    required this.playerB,
    this.selectedReceiver,
    this.selectedAttack,
    this.selectedBlock,
    required this.onReceiverSelected,
    required this.onAttackSelected,
    required this.onBlockSelected,
    required this.onScore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reception
        _sectionLabel('RECEPTION'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _toggleButton(playerA, 'player_a', selectedReceiver, onReceiverSelected, AppColors.accent)),
          const SizedBox(width: 8),
          Expanded(child: _toggleButton(playerB, 'player_b', selectedReceiver, onReceiverSelected, AppColors.purple)),
        ]),
        const SizedBox(height: 20),

        // Attack
        _sectionLabel('ATTAQUE GAGNANTE'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _toggleButton('Cut', 'cut', selectedAttack, onAttackSelected, AppColors.orange)),
          const SizedBox(width: 8),
          Expanded(child: _toggleButton('Line', 'line', selectedAttack, onAttackSelected, AppColors.orange)),
        ]),
        const SizedBox(height: 20),

        // Block
        _sectionLabel('BLOC'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _toggleButton('Diag', 'diag', selectedBlock, onBlockSelected, AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: _toggleButton('Line', 'line', selectedBlock, onBlockSelected, AppColors.textSecondary)),
        ]),
        const SizedBox(height: 28),

        // Score buttons
        _sectionLabel('RESULTAT'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _scoreButton('Point NOUS', 'us', AppColors.green)),
          const SizedBox(width: 8),
          Expanded(child: _scoreButton('Point EUX', 'them', AppColors.red)),
        ]),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600));
  }

  Widget _toggleButton(
    String label,
    String value,
    String? selected,
    ValueChanged<String> onTap,
    Color activeColor,
  ) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : AppColors.surfaceLight,
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? activeColor : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreButton(String label, String result, Color color) {
    return GestureDetector(
      onTap: () => onScore(result),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
