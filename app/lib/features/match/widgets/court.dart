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

const kCourtMargin = 36.0;
const _maxOuterW = 720.0;

// ---------------------------------------------------------------------------
// Pure helpers (no Flutter dependency)
// ---------------------------------------------------------------------------

/// True when this is the first ball contact on [touchSide] in the current
/// "visit" — i.e. the ball just crossed from the other side, or no real
/// touch has been recorded yet (server-position impacts are skipped).
bool _shouldShowPlayerPicker(MatchState state, TeamSide touchSide) {
  for (var i = state.rallyImpacts.length - 1; i >= 0; i--) {
    final impact = state.rallyImpacts[i];
    if (impact.isServerPosition) continue;
    return impact.teamSide != touchSide;
  }
  return true;
}

/// Returns the playerId of the last non-server impact on [side], or null.
String? _lastPlayerOnSide(MatchState state, TeamSide side) {
  for (var i = state.rallyImpacts.length - 1; i >= 0; i--) {
    final impact = state.rallyImpacts[i];
    if (!impact.isServerPosition && impact.teamSide == side) {
      return impact.playerId;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

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
        final outerW = constraints.maxWidth.clamp(0.0, _maxOuterW);
        final innerW = (outerW - kCourtMargin * 2).clamp(80.0, double.infinity);
        final innerH = innerW / 2;
        final outerH = innerH + kCourtMargin * 2;
        return Center(
          child: Container(
            width: outerW,
            height: outerH,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: MH.ruleSoft,
              borderRadius: BorderRadius.circular(8),
              // Solid outer ring that frames the band zone.
              boxShadow: const [
                BoxShadow(color: MH.rule, spreadRadius: 1.5),
              ],
            ),
            child: Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) =>
                      _onOutsideTap(d.localPosition, outerW, outerH),
                  onLongPressStart: (d) => _onOutsideLongPress(
                      d.localPosition, outerW, outerH, state),
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
                      onDoubleTapDown: (d) =>
                          _onDoubleTap(d.localPosition, outerW, outerH),
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
                      index: _impactIndex(impactsToShow, i),
                      isOutside: impactsToShow[i].isOutside,
                      isServerPosition: impactsToShow[i].isServerPosition,
                      isBlock: impactsToShow[i].isBlock,
                      isFinal: isReplay &&
                          i == impactsToShow.length - 1 &&
                          !impactsToShow[i].isServerPosition,
                    ),
                  ),
                ),
              if (state.popup?.kind == PopupKind.fault)
                const Positioned.fill(child: FaultPopup()),
              if (state.popup?.kind == PopupKind.pickServer)
                const Positioned.fill(child: PickServerPopup()),
              if (state.popup?.kind == PopupKind.outsideFault)
                const Positioned.fill(child: OutsideFaultPopup()),
              if (state.popup?.kind == PopupKind.pickPlayer)
                const Positioned.fill(child: PlayerPickerPopup()),
            ]),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  /// Single tap inside: normal ball touch.
  void _onInsideTap(Offset p, double outerW, double outerH) {
    if (_maybeDismissReplay()) return;
    final nx = (p.dx + kCourtMargin) / outerW;
    final ny = (p.dy + kCourtMargin) / outerH;
    _handleTouch(
      nx, ny,
      isOutside: false,
      isBlock: false,
      screenPos: Offset(p.dx + kCourtMargin, p.dy + kCourtMargin),
    );
  }

  /// Double-tap inside: block.
  void _onDoubleTap(Offset p, double outerW, double outerH) {
    if (_maybeDismissReplay()) return;
    final nx = (p.dx + kCourtMargin) / outerW;
    final ny = (p.dy + kCourtMargin) / outerH;
    _handleTouch(
      nx, ny,
      isOutside: false,
      isBlock: true,
      screenPos: Offset(p.dx + kCourtMargin, p.dy + kCourtMargin),
    );
  }

  /// Long-press inside = rally ended with ball landing on this side.
  /// Auto-attributes to the last known player; no picker (speed matters).
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
    final teamSide = nx < 0.5 ? state.leftTeam : state.rightTeam;
    final playerId = _lastPlayerOnSide(state, teamSide);
    ref.read(matchProvider.notifier).addBallImpact(
          BallImpact(
            x: nx,
            y: ny,
            isOutside: false,
            teamSide: teamSide,
            playerId: playerId,
          ),
        );
    final landSide = p.dx < innerW / 2 ? state.leftTeam : state.rightTeam;
    ref.read(matchProvider.notifier).addPoint(winner: landSide.other);
  }

  void _onOutsideTap(Offset p, double outerW, double outerH) {
    if (_maybeDismissReplay()) return;
    final state = ref.read(matchProvider);
    final xNorm = p.dx / outerW;
    final yNorm = p.dy / outerH;
    if (_isServerZone(p, outerW, outerH, state)) {
      // Server position — always attributed to the current server, no picker.
      ref.read(matchProvider.notifier).addTouchWithPlayer(
            BallImpact(
              x: xNorm,
              y: yNorm,
              isOutside: true,
              teamSide: xNorm < 0.5 ? state.leftTeam : state.rightTeam,
              playerId: state.servingPlayerId,
              isServerPosition: true,
            ),
          );
    } else {
      _handleTouch(xNorm, yNorm, isOutside: true, isBlock: false, screenPos: p);
    }
  }

  /// Long-press outside = out ball. Auto-attributes then shows fault picker.
  void _onOutsideLongPress(
    Offset p,
    double outerW,
    double outerH,
    MatchState state,
  ) {
    if (_maybeDismissReplay()) return;
    final xNorm = p.dx / outerW;
    final yNorm = p.dy / outerH;
    final teamSide = xNorm < 0.5 ? state.leftTeam : state.rightTeam;
    final playerId = _lastPlayerOnSide(state, teamSide);
    ref.read(matchProvider.notifier).addBallImpact(
          BallImpact(
            x: xNorm,
            y: yNorm,
            isOutside: true,
            teamSide: teamSide,
            playerId: playerId,
          ),
        );
    final impacts = ref.read(matchProvider).rallyImpacts;
    TeamSide winner;
    if (impacts.length >= 2) {
      winner = impacts[impacts.length - 2].teamSide.other;
    } else {
      final landSide = p.dx < outerW / 2 ? state.leftTeam : state.rightTeam;
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

  // ---------------------------------------------------------------------------
  // Core touch dispatcher
  // ---------------------------------------------------------------------------

  /// Central entry point for all court touches. Shows the player-picker bubble
  /// on the first touch of each "visit" to a side; auto-attributes otherwise.
  void _handleTouch(
    double xNorm,
    double yNorm, {
    required bool isOutside,
    required bool isBlock,
    required Offset screenPos,
  }) {
    final state = ref.read(matchProvider);
    final teamSide = xNorm < 0.5 ? state.leftTeam : state.rightTeam;

    final isTracked = state.trackedTeams.contains(teamSide);
    if (isTracked && _shouldShowPlayerPicker(state, teamSide)) {
      ref.read(matchProvider.notifier).showPopup(
            MatchPopup(
              kind: PopupKind.pickPlayer,
              winner: teamSide,
              tapPos: screenPos,
              pendingImpact: BallImpact(
                x: xNorm,
                y: yNorm,
                isOutside: isOutside,
                teamSide: teamSide,
                isBlock: isBlock,
              ),
            ),
          );
    } else {
      final playerId = _lastPlayerOnSide(state, teamSide);
      ref.read(matchProvider.notifier).addTouchWithPlayer(
            BallImpact(
              x: xNorm,
              y: yNorm,
              isOutside: isOutside,
              teamSide: teamSide,
              playerId: playerId,
              isBlock: isBlock,
            ),
          );
    }
  }

  // ---------------------------------------------------------------------------
  // Pure helpers
  // ---------------------------------------------------------------------------

  bool _isServerZone(
    Offset p,
    double outerW,
    double outerH,
    MatchState state,
  ) {
    if (state.rallyImpacts.isNotEmpty) return false;
    final inYRange = p.dy >= kCourtMargin && p.dy <= outerH - kCourtMargin;
    if (!inYRange) return false;
    final serverTeam = state.teamOfPlayer(state.servingPlayerId);
    if (serverTeam == null) return false;
    final serverIsLeft = state.leftTeam == serverTeam;
    return serverIsLeft ? p.dx < kCourtMargin : p.dx > outerW - kCourtMargin;
  }

  int _impactIndex(List<BallImpact> impacts, int i) {
    final hasServerPos = impacts.isNotEmpty && impacts.first.isServerPosition;
    if (hasServerPos && i == 0) return 0;
    return hasServerPos ? i : i + 1;
  }

  bool _maybeDismissReplay() {
    final sel = ref.read(matchProvider).selectedPointIndex;
    if (sel != null) {
      ref.read(matchProvider.notifier).clearSelection();
      return true;
    }
    return false;
  }
}
