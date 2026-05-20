import 'package:app/core/theme.dart';
import 'package:app/core/widgets/court_constants.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Corner-bracket player marker positioned in the outer court band zone.
///
/// Each player appears as an L-shaped bracket at the corner of the court
/// corresponding to their team side (left/right) and their relative position
/// within the team (top/bottom compared to their teammate).
class PlayerDot extends ConsumerWidget {
  const PlayerDot({
    required this.playerId,
    required this.outerHeight,
    required this.courtWidth,
    required this.courtHeight,
    super.key,
  });

  final String playerId;
  final double outerHeight;
  final double courtWidth;
  final double courtHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamKey =
        ref.watch(matchProvider.select((s) => s.teamOfPlayer(playerId)!));
    final pos =
        ref.watch(matchProvider.select((s) => s.positions[playerId]!));
    final isServer =
        ref.watch(matchProvider.select((s) => s.servingPlayerId == playerId));
    final mateId = ref.watch(matchProvider.select((s) {
      final team = s.teams[teamKey]!;
      return team.players.firstWhere((p) => p.id != playerId).id;
    }));
    final matePos =
        ref.watch(matchProvider.select((s) => s.positions[mateId]!));
    final isLeft =
        ref.watch(matchProvider.select((s) => s.leftTeam == teamKey));

    final color = teamKey == TeamSide.e1 ? MH.them : MH.us;
    final isTop = pos.y <= matePos.y;
    final topVal = isTop ? 0.0 : (outerHeight - kCourtMargin);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      left: isLeft ? 0.0 : null,
      right: isLeft ? null : 0.0,
      top: topVal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(ref, pos, teamKey),
        child: _CornerMarker(
          isLeft: isLeft,
          isTop: isTop,
          color: color,
          isServer: isServer,
        ),
      ),
    );
  }

  void _onTap(WidgetRef ref, CourtPos pos, TeamSide teamKey) {
    final opposing = teamKey.other;
    final anchor = Offset(
      kCourtMargin + pos.x * courtWidth,
      kCourtMargin + pos.y * courtHeight,
    );
    ref.read(matchProvider.notifier).showPopup(
          FaultPopup(
            winner: opposing,
            playerId: playerId,
            tapPos: anchor,
          ),
        );
  }
}

class _CornerMarker extends StatelessWidget {
  const _CornerMarker({
    required this.isLeft,
    required this.isTop,
    required this.color,
    required this.isServer,
  });

  final bool isLeft;
  final bool isTop;
  final Color color;
  final bool isServer;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: kCourtMargin,
        child: CustomPaint(
          painter: _BracketPainter(
            isLeft: isLeft,
            isTop: isTop,
            color: color,
            isServer: isServer,
          ),
        ),
      );
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.isLeft,
    required this.isTop,
    required this.color,
    required this.isServer,
  });

  final bool isLeft;
  final bool isTop;
  final Color color;
  final bool isServer;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    // Inset slightly from the outer container rounded corners.
    const inset = 5.0;
    final cx = isLeft ? inset : size.width - inset;
    final cy = isTop ? inset : size.height - inset;

    // Arm endpoints reach the court boundary edge of the band zone.
    final hEnd = isLeft ? size.width : 0.0;
    final vEnd = isTop ? size.height : 0.0;

    canvas
      ..drawLine(Offset(cx, cy), Offset(hEnd, cy), paint)
      ..drawLine(Offset(cx, cy), Offset(cx, vEnd), paint);

    // Serving player: small filled dot at the bracket corner.
    if (isServer) {
      canvas.drawCircle(
        Offset(cx, cy),
        4.5,
        Paint()..color = MH.ball,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.isLeft != isLeft ||
      old.isTop != isTop ||
      old.color != color ||
      old.isServer != isServer;
}
