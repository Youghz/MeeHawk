import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) => Text(
        'CRABCOACH',
        style: MH.sans(
          size: 36,
          weight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      );
}
