import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

/// Small badge showing an impact number at its tap location.
///
/// Shape encodes the impact type:
///   • circle  = normal contact
///   • rounded square = block (mur)
///   • solid fill = final position (ball stopped here)
class ImpactMarker extends StatelessWidget {
  const ImpactMarker({
    required this.index,
    required this.isOutside,
    this.isServerPosition = false,
    this.isBlock = false,
    this.isFinal = false,
    super.key,
  });

  final int index;
  final bool isOutside;
  final bool isServerPosition;
  final bool isBlock;
  final bool isFinal;

  @override
  Widget build(BuildContext context) {
    if (isServerPosition) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MH.ruleSoft,
          border: Border.all(color: MH.pencil, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          'S',
          style: MH.sans(
            size: 11,
            weight: FontWeight.w800,
            color: MH.pencil,
            height: 1,
          ),
        ),
      );
    }

    final accentColor = isOutside ? MH.bad : MH.ball;
    final lightBg = isOutside ? MH.themSoft : MH.ballSoft;

    // isFinal → solid fill so the eye reads "ball stopped here"
    final fillColor = isFinal ? accentColor : lightBg;
    final textColor = isFinal ? MH.paper : accentColor;

    // isBlock → rounded-square shape (wall / mur)
    final decoration = isBlock
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: fillColor,
            border: Border.all(color: accentColor, width: 2),
          )
        : BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(color: accentColor, width: 2),
          );

    return Container(
      width: 22,
      height: 22,
      decoration: decoration,
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: MH.sans(
          size: 11,
          weight: FontWeight.w800,
          color: textColor,
          height: 1,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
