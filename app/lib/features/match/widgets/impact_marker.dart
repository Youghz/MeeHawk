import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

/// Small badge showing an impact number at its tap location.
///
/// Shape encodes the impact type:
///   • circle       = normal contact
///   • rounded sq   = block
///   • cross (✕)    = final ball position (rally over)
///
/// Color alternates by [visitIndex] (how many net crossings happened so far)
/// to visually separate each team's possession.
class ImpactMarker extends StatelessWidget {
  const ImpactMarker({
    required this.index,
    required this.isOutside,
    this.isServerPosition = false,
    this.isBlock = false,
    this.isFinal = false,
    this.visitIndex = 0,
    this.playerName,
    super.key,
  });

  final int index;
  final bool isOutside;
  final bool isServerPosition;
  final bool isBlock;
  final bool isFinal;
  final int visitIndex;

  /// Player name shown above the marker in replay mode.
  final String? playerName;

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

    // Fault / outside always red regardless of visit.
    final accentColor =
        isOutside ? MH.bad : (visitIndex.isEven ? MH.ball : MH.inkSoft);
    final lightBg =
        isOutside ? MH.badSoft : (visitIndex.isEven ? MH.ballSoft : MH.ruleSoft);

    final Widget marker;

    // Final impact → filled circle with ✕ (no number).
    if (isFinal) {
      marker = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
        alignment: Alignment.center,
        child: const Icon(Icons.close_rounded, size: 14, color: MH.paper),
      );
    } else {
      final decoration = isBlock
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: lightBg,
              border: Border.all(color: accentColor, width: 2),
            )
          : BoxDecoration(
              shape: BoxShape.circle,
              color: lightBg,
              border: Border.all(color: accentColor, width: 2),
            );

      marker = Container(
        width: 22,
        height: 22,
        decoration: decoration,
        alignment: Alignment.center,
        child: Text(
          '$index',
          style: MH.sans(
            size: 11,
            weight: FontWeight.w800,
            color: accentColor,
            height: 1,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      );
    }

    if (playerName == null) return marker;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playerName!,
          style: MH.sans(
            size: 8,
            weight: FontWeight.w700,
            color: accentColor,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        marker,
      ],
    );
  }
}
