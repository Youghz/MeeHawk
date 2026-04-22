import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

/// Small circular badge showing an impact number at its tap location.
class ImpactMarker extends StatelessWidget {
  const ImpactMarker({
    required this.index,
    required this.isOutside,
    super.key,
  });

  final int index;
  final bool isOutside;

  @override
  Widget build(BuildContext context) {
    final color = isOutside ? MH.bad : MH.ball;
    final bg = isOutside ? MH.themSoft : MH.ballSoft;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: MH.sans(
          size: 11,
          weight: FontWeight.w800,
          color: color,
          height: 1,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
