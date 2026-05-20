import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class SetupServerPicker extends StatelessWidget {
  const SetupServerPicker({
    required this.labels,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });

  /// Maps player id ('p1'–'p4') to display label (name or fallback).
  final Map<String, String> labels;
  final String selectedId;
  final ValueChanged<String> onChanged;

  static const _rows = [
    ['p1', 'p2'],
    ['p3', 'p4'],
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premier serveur',
            style: MH.sans(
              size: 13,
              weight: FontWeight.w600,
              color: MH.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          for (int r = 0; r < _rows.length; r++) ...[
            Row(
              children: [
                for (int i = 0; i < _rows[r].length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _chip(_rows[r][i])),
                ],
              ],
            ),
            if (r < _rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      );

  Widget _chip(String id) {
    final selected = id == selectedId;
    final color = (id == 'p1' || id == 'p2') ? MH.them : MH.us;
    return GestureDetector(
      onTap: () => onChanged(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : MH.rule,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          labels[id] ?? id,
          style: MH.sans(
            size: 13,
            weight: FontWeight.w600,
            color: selected ? color : MH.inkSoft,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
