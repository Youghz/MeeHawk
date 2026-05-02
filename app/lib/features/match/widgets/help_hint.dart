import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class HelpPanel extends StatelessWidget {
  const HelpPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MH.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GESTES',
            style: MH.sans(
              size: 11,
              weight: FontWeight.w700,
              color: MH.paper,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          _line('Appui', 'terrain adverse → réception'),
          _line('Appui prolongé', 'terrain adverse → attaque (point)'),
          _line('Appui prolongé', 'joueur → faute (point adverse)'),
          _line('Appui prolongé + glisse', 'joueur → repositionner'),
          _line('Appui', 'timeline → replay du point'),
        ],
      ),
    );
  }

  Widget _line(String verb, String rest) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: RichText(
          text: TextSpan(
            style: MH.sans(size: 11, color: MH.paper, height: 1.4),
            children: [
              const TextSpan(text: '· '),
              TextSpan(
                text: verb,
                style: MH.sans(
                  size: 11,
                  weight: FontWeight.w700,
                  color: MH.paper,
                ),
              ),
              TextSpan(text: ' $rest'),
            ],
          ),
        ),
      );
}
