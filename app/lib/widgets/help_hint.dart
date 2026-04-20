import 'package:flutter/material.dart';
import '../theme.dart';

class HelpHint extends StatefulWidget {
  const HelpHint({super.key});

  @override
  State<HelpHint> createState() => _HelpHintState();
}

class _HelpHintState extends State<HelpHint> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Positioned(
        top: 8,
        right: 8,
        child: GestureDetector(
          onTap: () => setState(() => _open = true),
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: MH.ink,
              shape: BoxShape.circle,
            ),
            child: Text('?',
                style: MH.sans(
                  size: 12,
                  weight: FontWeight.w700,
                  color: MH.paper,
                )),
          ),
        ),
      );
    }
    return Positioned(
      top: 50,
      left: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MH.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('GESTES',
                    style: MH.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: MH.paper,
                      letterSpacing: 0.5,
                    )),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _open = false),
                  child: Text('×',
                      style: MH.sans(
                        size: 16,
                        color: MH.paper.withValues(alpha: 0.6),
                      )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _line('Appui', 'terrain adverse → réception'),
            _line('Appui prolongé', 'terrain adverse → attaque (point)'),
            _line('Appui prolongé', 'joueur → faute (point adverse)'),
            _line('Appui prolongé + glisse', 'joueur → repositionner'),
            _line('Appui', 'timeline → replay du point'),
          ],
        ),
      ),
    );
  }

  Widget _line(String verb, String rest) => Padding(
        padding: const EdgeInsets.only(top: 2),
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
