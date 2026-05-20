import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              color: MH.ball,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: MH.mono(
              size: 11,
              weight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
}
