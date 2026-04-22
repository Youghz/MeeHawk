import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match/widgets/court_canvas.dart';
import 'package:app/features/match/widgets/court_popups.dart';
import 'package:app/features/match/widgets/impact_marker.dart';
import 'package:app/features/match/widgets/player_dot.dart';
import 'package:app/features/match/widgets/trajectory_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kCourtMargin = 20.0;
const _maxOuterW = 720.0;

/// Net-zone threshold (as a fraction of inner court width, measured from
/// center) within which a double-tap counts as a block.
const _blockNetZone = 0.18;

class Court extends ConsumerStatefulWidget {
  const Court({super.key});

  @override
  ConsumerState<Court> createState() => _CourtState();
}

class _CourtState extends ConsumerState<Court> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);
    final leftTeam = state.leftTeam;
    final rightTeam = state.rightTeam;
    final leftColor = leftTeam == TeamSide.e1 ? MH.them : MH.us;
    final rightColor = rightTeam == TeamSide.e1 ? MH.them : MH.us;

    final replayIdx = state.selectedPointIndex;
    final isReplay = replayIdx != null && replayIdx < state.history.length;
    final impactsToShow =
        isReplay ? state.history[replayIdx].impacts : state.rallyImpacts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final outerW =
            constraints.maxWidth.clamp(0.0, _maxOuterW);
        final innerW =
            (outerW - kCourtMargin * 2).clamp(80.0, double.infinity);
        final innerH = innerW / 2;
        final outerH = innerH + kCourtMargin * 2;
        return Center(
          child: SizedBox(
            width: outerW,
            height: outerH,
            child: Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) =>
                      _onOutsideTap(d.localPosition, outerW, outerH),
                  onLongPressStart: (d) => _onOutsideLongPress(
                      d.localPosition, outerW, outerH, state),
                  child: const ColoredBox(color: MH.paper),
                ),
              ),
              Positioned(
                left: kCourtMargin,
                top: kCourtMargin,
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
                      onDoubleTapDown: (d) => _onDoubleTap(
                          d.localPosition, outerW, outerH, innerW),
                      onDoubleTap: () {},
                      child: RepaintBoundary(
                        child: CourtCanvas(
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
                      painter: TrajectoryPainter(
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
                    child: ImpactMarker(
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

  // ---------------------------------------------------------------------
  // Gestures
  // ---------------------------------------------------------------------

  void _onInsideTap(Offset p, double outerW, double outerH) {
    if (_maybeDismissReplay()) return;
    final nx = (p.dx + kCourtMargin) / outerW;
    final ny = (p.dy + kCourtMargin) / outerH;
    _recordImpact(nx, ny, isOutside: false);
  }

  /// Long-press inside = the rally ended with the ball landing on this
  /// side. Record the landing impact (auto-annotates the winning attack
  /// via addBallImpact's cross detection), then award the point to the
  /// opposite team.
  void _onInsideLongPress(
    Offset p,
    double outerW,
    double outerH,
    double innerW,
    MatchState state,
  ) {
    if (_maybeDismissReplay()) return;
    final nx = (p.dx + kCourtMargin) / outerW;
    final ny = (p.dy + kCourtMargin) / outerH;
    _recordImpact(nx, ny, isOutside: false);
    final landSide = p.dx < innerW / 2 ? state.leftTeam : state.rightTeam;
    ref.read(matchProvider.notifier).addPoint(winner: landSide.other);
  }

  void _onOutsideTap(Offset p, double outerW, double outerH) {
    if (_maybeDismissReplay()) return;
    _recordImpact(p.dx / outerW, p.dy / outerH, isOutside: true);
  }

  /// Long-press outside = ball left the court while being played. The
  /// faulting team is the one that touched the ball last, so the winner
  /// is the OTHER team. Falls back to tap position only if there was no
  /// previous touch to attribute.
  void _onOutsideLongPress(
    Offset p,
    double outerW,
    double outerH,
    MatchState state,
  ) {
    if (_maybeDismissReplay()) return;
    _recordImpact(p.dx / outerW, p.dy / outerH, isOutside: true);
    final impacts = ref.read(matchProvider).rallyImpacts;
    // Faulter is the last touch BEFORE the out — the one we just recorded
    // is the ball going out, whose side is assigned by landing position.
    // Look one further back.
    TeamSide winner;
    if (impacts.length >= 2) {
      winner = impacts[impacts.length - 2].teamSide.other;
    } else {
      // No prior touch recorded — fall back to side of the out.
      final isLeft = p.dx < outerW / 2;
      final landSide = isLeft ? state.leftTeam : state.rightTeam;
      winner = landSide;
    }
    ref.read(matchProvider.notifier).showPopup(
          MatchPopup(
            kind: PopupKind.outsideFault,
            winner: winner,
            tapPos: p,
          ),
        );
  }

  void _onDoubleTap(
    Offset p,
    double outerW,
    double outerH,
    double innerW,
  ) {
    if (_maybeDismissReplay()) return;
    final xInnerNorm = p.dx / innerW;
    if ((xInnerNorm - 0.5).abs() > _blockNetZone) return;
    final nx = (p.dx + kCourtMargin) / outerW;
    final ny = (p.dy + kCourtMargin) / outerH;
    _recordImpact(nx, ny, isOutside: false);
    ref.read(matchProvider.notifier).showPopup(
          MatchPopup(
            kind: PopupKind.block,
            winner: ref.read(matchProvider).rallyImpacts.last.teamSide,
            tapPos: Offset(p.dx + kCourtMargin, p.dy + kCourtMargin),
          ),
        );
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

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
    final teamSide = xNorm < 0.5 ? state.leftTeam : state.rightTeam;
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

  /// Nearest player of `teamSide` to the tap. Player positions are stored
  /// in inner-court normalized coords; the tap is in outer-normalized
  /// coords. For an argmin distance, the small margin offset is uniform
  /// across candidates and doesn't change the ranking.
  String? _nearestPlayerOnSide(
    MatchState state,
    TeamSide teamSide,
    double xOuter,
    double yOuter,
  ) {
    final players = state.teams[teamSide]!.players;
    if (players.isEmpty) return null;
    String? best;
    var bestDist = double.infinity;
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
}
