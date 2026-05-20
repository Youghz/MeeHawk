import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class SetupFormatSection extends StatelessWidget {
  const SetupFormatSection({
    required this.setsToWin,
    required this.setPoints,
    required this.changeSideEvery,
    required this.onSetsToWinChanged,
    required this.onSetPointsChanged,
    required this.onChangeSideDecrement,
    required this.onChangeSideIncrement,
    super.key,
  });

  final int setsToWin;
  final int setPoints;
  final int changeSideEvery;
  final ValueChanged<int> onSetsToWinChanged;
  final ValueChanged<int> onSetPointsChanged;
  final VoidCallback onChangeSideDecrement;
  final VoidCallback onChangeSideIncrement;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FORMAT',
            style: MH.mono(weight: FontWeight.w600, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MH.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MH.rule, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sets à gagner',
                    style: MH.sans(size: 12, color: MH.inkSoft)),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2].map((n) {
                    final selected = n == setsToWin;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '$n',
                          style: MH.sans(
                            size: 12,
                            weight: FontWeight.w600,
                            color: selected ? MH.paper : MH.inkSoft,
                          ),
                        ),
                        selected: selected,
                        selectedColor: MH.pencil,
                        backgroundColor: MH.sand,
                        side: BorderSide(
                          color: selected ? MH.pencil : MH.rule,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        onSelected: (_) => onSetsToWinChanged(n),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text('Points par set',
                    style: MH.sans(size: 12, color: MH.inkSoft)),
                const SizedBox(height: 8),
                Row(
                  children: [15, 21, 25].map((n) {
                    final selected = n == setPoints;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '$n',
                          style: MH.sans(
                            size: 12,
                            weight: FontWeight.w600,
                            color: selected ? MH.paper : MH.inkSoft,
                          ),
                        ),
                        selected: selected,
                        selectedColor: MH.pencil,
                        backgroundColor: MH.sand,
                        side: BorderSide(
                          color: selected ? MH.pencil : MH.rule,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        onSelected: (_) => onSetPointsChanged(n),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Changer de côté tous les',
                        style: MH.sans(size: 12, color: MH.inkSoft),
                      ),
                    ),
                    _counter(),
                    const SizedBox(width: 8),
                    Text('pts', style: MH.sans(size: 12, color: MH.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _counter() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _counterBtn(Icons.remove, onChangeSideDecrement),
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                '$changeSideEvery',
                style: MH.sans(weight: FontWeight.w700),
              ),
            ),
          ),
          _counterBtn(Icons.add, onChangeSideIncrement),
        ],
      );

  Widget _counterBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MH.sand,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MH.rule),
          ),
          child: Icon(icon, size: 14, color: MH.ink),
        ),
      );
}
