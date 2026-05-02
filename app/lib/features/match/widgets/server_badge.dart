import 'package:app/core/theme.dart';
import 'package:app/core/widgets/ball_icon.dart';
import 'package:flutter/material.dart';

class ServerBadge extends StatelessWidget {
  const ServerBadge({
    required this.teamColor,
    required this.playerName,
    super.key,
  });

  final Color teamColor;
  final String playerName;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: MH.ballSoft,
          border: Border.all(color: MH.ball, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BallIcon(size: 15),
            const SizedBox(width: 6),
            Text('Service',
                style: MH.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: MH.ball,
                )),
            Text(' · ',
                style: MH.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: MH.ball,
                )),
            Text(playerName,
                style: MH.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: teamColor,
                )),
          ],
        ),
      );
}
