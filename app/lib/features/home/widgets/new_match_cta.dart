import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class NewMatchCta extends StatelessWidget {
  const NewMatchCta({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: MH.sand,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: MH.ball.withValues(alpha: 0.10),
          highlightColor: MH.ball.withValues(alpha: 0.06),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: MH.ball.withValues(alpha: 0.40),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: MH.ball,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NOUVELLE PARTIE',
                        style: MH.sans(
                          size: 17,
                          weight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Annoter un match en direct',
                        style: MH.sans(size: 13, color: MH.pencil),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: MH.ball,
                ),
              ],
            ),
          ),
        ),
      );
}
