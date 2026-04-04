import 'package:flutter/material.dart';
import '../theme.dart';

class ServeZonePicker extends StatelessWidget {
  final String? selectedZone;
  final ValueChanged<String> onZoneSelected;

  const ServeZonePicker({super.key, this.selectedZone, required this.onZoneSelected});

  // 6 zones: top row (far side) = TL, TC, TR; bottom row (near side) = BL, BC, BR
  static const _zones = [
    ['TL', 'TC', 'TR'],
    ['BL', 'BC', 'BR'],
  ];

  static const _labels = {
    'TL': 'G', 'TC': 'C', 'TR': 'D',
    'BL': 'G', 'BC': 'C', 'BR': 'D',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ZONE SERVICE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              // Far side label
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('Fond', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              ),
              for (int row = 0; row < 2; row++)
                Row(
                  children: [
                    for (int col = 0; col < 3; col++)
                      Expanded(child: _zoneButton(_zones[row][col])),
                  ],
                ),
              // Net
              Container(
                height: 2,
                color: AppColors.textMuted.withValues(alpha: 0.3),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('Filet', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zoneButton(String zone) {
    final isSelected = selectedZone == zone;
    return GestureDetector(
      onTap: () => onZoneSelected(zone),
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surfaceLight,
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            _labels[zone]!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
