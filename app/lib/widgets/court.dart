import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';
import '../providers/match_provider.dart';
import '../theme.dart';
import 'ball_icon.dart';
import 'court_popups.dart';
import 'player_dot.dart';

const courtHeight = 300.0;

class Court extends ConsumerStatefulWidget {
  const Court({super.key});

  @override
  ConsumerState<Court> createState() => _CourtState();
}

class _CourtState extends ConsumerState<Court> {
  Offset? _serveMarker;
  int _lastHistoryLength = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);
    if (state.history.length != _lastHistoryLength) {
      _lastHistoryLength = state.history.length;
      _serveMarker = null;
    }

    final leftTeam = state.sidesSwapped ? 'e2' : 'e1';
    final rightTeam = state.sidesSwapped ? 'e1' : 'e2';
    final leftColor = leftTeam == 'e1' ? MH.them : MH.us;
    final rightColor = rightTeam == 'e1' ? MH.them : MH.us;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        return Stack(children: [
          SizedBox(
            height: courtHeight,
            width: w,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) =>
                  setState(() => _serveMarker = details.localPosition),
              onLongPressStart: (details) =>
                  _openAttackPopup(details.localPosition, w, state),
              child: _CourtCanvas(
                state: state,
                leftTeam: leftTeam,
                rightTeam: rightTeam,
                leftColor: leftColor,
                rightColor: rightColor,
                serveMarker: _serveMarker,
                courtWidth: w,
              ),
            ),
          ),
          ...['p1', 'p2', 'p3', 'p4'].map((id) => PlayerDot(
                key: ValueKey('dot-$id'),
                playerId: id,
                courtWidth: w,
                courtHeight: courtHeight,
              )),
          if (state.popup?.kind == PopupKind.attack) const AttackPopup(),
          if (state.popup?.kind == PopupKind.fault) const FaultPopup(),
        ]);
      }),
    );
  }

  void _openAttackPopup(Offset p, double w, MatchState state) {
    final isLeftSide = p.dx < w / 2;
    final leftTeam = state.sidesSwapped ? 'e2' : 'e1';
    final rightTeam = state.sidesSwapped ? 'e1' : 'e2';
    final winner = isLeftSide ? rightTeam : leftTeam;
    ref.read(matchProvider.notifier).showPopup(
          MatchPopup(kind: PopupKind.attack, winner: winner),
        );
  }
}

class _CourtCanvas extends StatelessWidget {
  final MatchState state;
  final String leftTeam;
  final String rightTeam;
  final Color leftColor;
  final Color rightColor;
  final Offset? serveMarker;
  final double courtWidth;

  const _CourtCanvas({
    required this.state,
    required this.leftTeam,
    required this.rightTeam,
    required this.leftColor,
    required this.rightColor,
    required this.serveMarker,
    required this.courtWidth,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: MH.sand,
            border: Border.all(color: MH.ink, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(painter: _SandTexturePainter()),
            ),
            Positioned(
              left: 6,
              right: 6,
              top: 6,
              bottom: 6,
              child: CustomPaint(painter: _DashedInnerPainter()),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: courtWidth / 2 - 1.5,
              width: 3,
              child: Container(color: MH.ink),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: courtWidth / 2 - 7,
              width: 14,
              child: Opacity(
                opacity: 0.45,
                child: CustomPaint(painter: _NetPainter()),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IgnorePointer(
                child: Text(
                  state.teams[leftTeam]!.name.toUpperCase(),
                  style: MH.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: leftColor,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: IgnorePointer(
                child: Text(
                  state.teams[rightTeam]!.name.toUpperCase(),
                  style: MH.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: rightColor,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            if (serveMarker != null)
              Positioned(
                left: serveMarker!.dx - 18,
                top: serveMarker!.dy - 18,
                child: const IgnorePointer(child: _PulsingServeMarker()),
              ),
          ]),
        ),
      );
}

class _PulsingServeMarker extends StatefulWidget {
  const _PulsingServeMarker();

  @override
  State<_PulsingServeMarker> createState() => _PulsingServeMarkerState();
}

class _PulsingServeMarkerState extends State<_PulsingServeMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final scale = 1.0 + _ctrl.value * 0.15;
          final opacity = 0.9 - _ctrl.value * 0.35;
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MH.ballSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: MH.ball, width: 2.5),
                ),
                child: const Center(child: BallIcon(size: 16)),
              ),
            ),
          );
        },
      );
}

class _SandTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MH.pencil.withValues(alpha: 0.25);
    for (double y = 0; y < size.height; y += 8) {
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawCircle(Offset(x + 2, y + 2), 0.6, paint);
        canvas.drawCircle(Offset(x + 6, y + 5), 0.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SandTexturePainter old) => false;
}

class _DashedInnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MH.inkSoft.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashW = 4.0, gap = 4.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        final seg = m.extractPath(d, d + dashW);
        canvas.drawPath(seg, paint);
        d += dashW + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedInnerPainter old) => false;
}

class _NetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MH.ink
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetPainter old) => false;
}
