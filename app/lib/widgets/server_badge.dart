import 'package:flutter/material.dart';
import '../theme.dart';
import 'ball_icon.dart';

class ServerBadge extends StatelessWidget {
  final Color teamColor;
  final String playerName;
  const ServerBadge({
    super.key,
    required this.teamColor,
    required this.playerName,
  });

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
            const BallIcon(size: 13),
            const SizedBox(width: 6),
            Text('Service',
                style: MH.sans(
                  size: 11,
                  weight: FontWeight.w600,
                  color: MH.ball,
                )),
            Text(' · ',
                style: MH.sans(
                  size: 11,
                  weight: FontWeight.w600,
                  color: MH.ball,
                )),
            Text(playerName,
                style: MH.sans(
                  size: 11,
                  weight: FontWeight.w600,
                  color: teamColor,
                )),
          ],
        ),
      );
}
