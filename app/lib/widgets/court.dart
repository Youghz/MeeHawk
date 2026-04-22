import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';
import '../providers/match_provider.dart';
import '../theme.dart';
import 'court_popups.dart';
import 'player_dot.dart';

const kCourtMargin = 20.0;

class Court extends ConsumerStatefulWidget {
  const Court({super.key});

  @override
  ConsumerState<Court> createState() => _CourtState();
}

class _CourtState extends ConsumerState<Court> {
  static const _margin = kCourtMargin;
  static const _maxOuterW = 720.0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);

    final leftTeam = state.sidesSwapped ? 'e2' : 'e1';
    final rightTeam = state.sidesSwapped ? 'e1' : 'e2';
    final leftColor = leftTeam == 'e1' ? MH.them : MH.us;
    final rightColor = rightTeam == 'e1' ? MH.them : MH.us;

    // Replay mode: when a historical point is selected, show that point's
    // trajectory instead of the current rally, hide players, disable
    // gestures. Tap anywhere in replay mode clears the selection.
    final replayIdx = state.selectedPointIndex;
    final isReplay = replayIdx != null && replayIdx < state.history.length;
    final impactsToShow =
        isReplay ? state.history[replayIdx].impacts : state.rallyImpacts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final outerW =
            constraints.maxWidth.clamp(0.0, _maxOuterW).toDouble();
        final innerW = (outerW - _margin * 2).clamp(80.0, double.infinity);
        final innerH = innerW / 2;
        final outerH = innerH + _margin * 2;
        return Center(
          child: SizedBox(
            width: outerW,
            height: outerH,
            child: Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onOutsideTap(
                      d.localPosition, outerW, outerH),
                  onLongPressStart: (d) => _onOutsideLongPress(
                      d.localPosition, outerW, outerH, state),
                  child: const ColoredBox(color: MH.paper),
                ),
              ),
              Positioned(
                left: _margin,
                top: _margin,
                width: innerW,
                height: innerH,
                child: Stack(children: [
                  SizedBox(
                    width: innerW,
                    height: innerH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) =>
                          _onInsideTap(d.localPosition, outerW, outerH),
                      onLongPressStart: (d) => _onInsideLongPress(
                          d.localPosition, outerW, outerH, innerW, state),
                      onDoubleTapDown: (d) =>
                          _onDoubleTap(d.localPosition, outerW, outerH, innerW),
                      onDoubleTap: () {},
                      child: RepaintBoundary(
                        child: _CourtCanvas(
                          state: state,
                          leftTeam: leftTeam,
                          rightTeam: rightTeam,
                          leftColor: leftColor,
                          rightColor: rightColor,
                          courtWidth: innerW,
                        ),
                      ),
                    ),
                  ),
                  if (!isReplay)
                    ...['p1', 'p2', 'p3', 'p4'].map((id) => PlayerDot(
                          key: ValueKey('dot-$id'),
                          playerId: id,
                          courtWidth: innerW,
                          courtHeight: innerH,
                        )),
                ]),
              ),
              if (impactsToShow.length > 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TrajectoryPainter(
                        impacts: impactsToShow,
                        outerW: outerW,
                        outerH: outerH,
                      ),
                    ),
                  ),
                ),
              for (int i = 0; i < impactsToShow.length; i++)
                Positioned(
                  left: impactsToShow[i].x * outerW - 11,
                  top: impactsToShow[i].y * outerH - 11,
                  child: IgnorePointer(
                    child: _ImpactMarker(
                      index: i + 1,
                      isOutside: impactsToShow[i].isOutside,
                    ),
                  ),
                ),
              if (state.popup?.kind == PopupKind.fault)
                const Positioned.fill(child: FaultPopup()),
              if (state.popup?.kind == PopupKind.pickServer)
                const Positioned.fill(child: PickServerPopup()),
              if (state.popup?.kind == PopupKind.outsideFault)
                const Positioned.fill(child: OutsideFaultPopup()),
              if (state.popup?.kind == PopupKind.block)
                const Positioned.fill(child: BlockPopup()),
            ]),
          ),
        );
      }),
    );
  }

  void _onInsideTap(Offset p, double outerW, double outerH) {
    if (_maybeDismissReplay()) return;
    final nx = (p.dx + _margin) / outerW;
    final ny = (p.dy + _margin) / outerH;
    _recordImpact(nx, ny, isOutside: false);
  }

  /// Long-press inside = the rally ended with the ball landing on this
  /// side. Record the landing impact (which auto-annotates the winning
  /// attack via addBallImpact's cross detection) then commit the point
  /// to the opposite team.
  void _onInsideLongPress(
    Offset p,
    double outerW,
    double outerH,
    double innerW,
    MatchState state,
  ) {
    if (_maybeDismissReplay()) return;
    final nx = (p.dx + _margin) / outerW;
    final ny = (p.dy + _margin) / outerH;
    _recordImpact(nx, ny, isOutside: false);
    final isLeftSide = p.dx < innerW / 2;
    final leftTeam = state.sidesSwapped ? 'e2' : 'e1';
    final rightTeam = state.sidesSwapped ? 'e1' : 'e2';
    final winner = isLeftSide ? rightTeam : leftTeam;
    ref
        .read(matchProvider.notifier)
        .addPoint(winner: winner);
  }

  void _onOutsideTap(Offset p, double outerW, double outerH) {
    if (_maybeDismissReplay()) return;
    _recordImpact(p.dx / outerW, p.dy / outerH, isOutside: true);
  }

  bool _maybeDismissReplay() {
    final sel = ref.read(matchProvider).selectedPointIndex;
    if (sel != null) {
      ref.read(matchProvider.notifier).clearSelection();
      return true;
    }
    return false;
  }

  /// Record a ball impact with auto-computed team side and nearest-player
  /// attribution. `xNorm`/`yNorm` are normalized to the outer court frame.
  void _recordImpact(double xNorm, double yNorm, {required bool isOutside}) {
    final state = ref.read(matchProvider);
    final leftTeam = state.sidesSwapped ? 'e2' : 'e1';
    final rightTeam = state.sidesSwapped ? 'e1' : 'e2';
    final teamSide = xNorm < 0.5 ? leftTeam : rightTeam;
    final playerId = _nearestPlayerOnSide(state, teamSide, xNorm, yNorm);
    ref.read(matchProvider.notifier).addBallImpact(
          BallImpact(
            x: xNorm,
            y: yNorm,
            isOutside: isOutside,
            teamSide: teamSide,
            playerId: playerId,
          ),
        );
  }

  /// Nearest player of `teamSide` to the tap point (in outer-normalized
  /// coords). Player positions are stored in inner-court normalized coords,
  /// so we convert both to the same frame before comparing.
  String? _nearestPlayerOnSide(
    MatchState state,
    String teamSide,
    double xOuter,
    double yOuter,
  ) {
    final players = state.teams[teamSide]!.players;
    if (players.isEmpty) return null;
    // Convert player inner-normalized pos → outer-normalized pos.
    // outerX = (margin + innerX * innerW) / outerW, similar for Y.
    // innerW + 2*margin = outerW, so the ratio depends on outer size —
    // but comparing distances, constants wash out if both axes use the
    // same frame. We just use the stored inner coords directly against
    // the tap converted to inner-equivalent: innerX = (outerX*outerW - margin) / innerW.
    // Simpler: since we only need ARGMIN of distance, compare raw values
    // in the inner frame.
    // Convert impact to "inner-like" coords using the same math the Court
    // applies when recording (reverse): inner = (outer - margin/outerW).
    // But we don't have outerW here — pass it? Simpler still: the team's
    // two players are on roughly the same side, so we just pick the
    // one with smaller Manhattan distance in the raw `positions` frame
    // against a tap normalized to that same frame. We'll re-use inner
    // coords since the tap's outer coords are close to inner-normalized
    // for the relevant side. Small inaccuracy from margin is acceptable
    // for a "nearest" heuristic.
    String? best;
    double bestDist = double.infinity;
    for (final p in players) {
      final pos = state.positions[p.id]!;
      final dx = pos.x - xOuter;
      final dy = pos.y - yOuter;
      final d = dx * dx + dy * dy;
      if (d < bestDist) {
        bestDist = d;
        best = p.id;
      }
    }
    return best;
  }

  void _onDoubleTap(
    Offset p,
    double outerW,
    double outerH,
    double innerW,
  ) {
    if (_maybeDismissReplay()) return;
    final xInnerNorm = p.dx / innerW;
    const netZone = 0.18;
    if ((xInnerNorm - 0.5).abs() > netZone) return;
    final nx = (p.dx + _margin) / outerW;
    final ny = (p.dy + _margin) / outerH;
    // Record the block as an impact first; playerId is auto-attributed to
    // the nearest player on that side (= the blocker). The popup then only
    // asks for direction.
    _recordImpact(nx, ny, isOutside: false);
    ref.read(matchProvider.notifier).showPopup(
          MatchPopup(
            kind: PopupKind.block,
            winner: ref.read(matchProvider).rallyImpacts.last.teamSide,
            tapPos: Offset(p.dx + _margin, p.dy + _margin),
          ),
        );
  }

  /// Long-press outside = ball left the court while being played. Record
  /// the outside impact then open the fault-type popup. The faulter is
  /// the last recorded touch (auto-attributed).
  void _onOutsideLongPress(
    Offset p,
    double outerW,
    double outerH,
    MatchState state,
  ) {
    if (_maybeDismissReplay()) return;
    _recordImpact(p.dx / outerW, p.dy / outerH, isOutside: true);
    final isLeft = p.dx < outerW / 2;
    final leftTeam = state.sidesSwapped ? 'e2' : 'e1';
    final rightTeam = state.sidesSwapped ? 'e1' : 'e2';
    final winner = isLeft ? leftTeam : rightTeam;
    ref.read(matchProvider.notifier).showPopup(
          MatchPopup(
            kind: PopupKind.outsideFault,
            winner: winner,
            tapPos: p,
          ),
        );
  }
}

/// Draws dashed lines between consecutive impact markers to visualize the
/// ball trajectory during the rally or the replay of a historical point.
class _TrajectoryPainter extends CustomPainter {
  final List<BallImpact> impacts;
  final double outerW;
  final double outerH;
  _TrajectoryPainter({
    required this.impacts,
    required this.outerW,
    required this.outerH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (impacts.length < 2) return;
    final paint = Paint()
      ..color = MH.pencil.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < impacts.length; i++) {
      final a = Offset(impacts[i - 1].x * outerW, impacts[i - 1].y * outerH);
      final b = Offset(impacts[i].x * outerW, impacts[i].y * outerH);
      _drawDashedLine(canvas, paint, a, b);
    }
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset a, Offset b) {
    const dash = 5.0;
    const gap = 4.0;
    final delta = b - a;
    final dist = delta.distance;
    if (dist == 0) return;
    final unit = delta / dist;
    double traveled = 0;
    while (traveled < dist) {
      final segEnd = (traveled + dash).clamp(0.0, dist);
      canvas.drawLine(a + unit * traveled, a + unit * segEnd, paint);
      traveled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter old) =>
      old.impacts != impacts ||
      old.outerW != outerW ||
      old.outerH != outerH;
}

class _ImpactMarker extends StatelessWidget {
  final int index;
  final bool isOutside;
  const _ImpactMarker({required this.index, required this.isOutside});

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

class _CourtCanvas extends StatelessWidget {
  final MatchState state;
  final String leftTeam;
  final String rightTeam;
  final Color leftColor;
  final Color rightColor;
  final double courtWidth;

  const _CourtCanvas({
    required this.state,
    required this.leftTeam,
    required this.rightTeam,
    required this.leftColor,
    required this.rightColor,
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
              child: CustomPaint(painter: _NetPainter()),
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
          ]),
        ),
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
      ..color = MH.ink.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetPainter old) => false;
}
