import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class SetupTeamSection extends StatelessWidget {
  const SetupTeamSection({
    required this.color,
    required this.teamCtrl,
    required this.pACtrl,
    required this.pBCtrl,
    required this.onChanged,
    super.key,
  });

  final Color color;
  final TextEditingController teamCtrl;
  final TextEditingController pACtrl;
  final TextEditingController pBCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MH.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    teamCtrl,
                    style: MH.sans(
                      size: 15,
                      weight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(pACtrl, hint: 'Joueur 1')),
              const SizedBox(width: 10),
              Expanded(child: _field(pBCtrl, hint: 'Joueur 2')),
            ]),
          ],
        ),
      );

  Widget _field(TextEditingController c, {TextStyle? style, String? hint}) =>
      TextField(
        controller: c,
        style: style ?? MH.sans(),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: MH.sans(size: 13, color: MH.pencil),
          isDense: true,
          filled: true,
          fillColor: MH.sand,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: MH.rule),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: MH.rule),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: MH.ink, width: 1.5),
          ),
        ),
      );
}
