import 'dart:async';

import 'package:app/core/rules/touch_attribution.dart';
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

const kCourtMargin = 28.0;
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
    if (impact.teamSide != touchSide) return true;
    // Same side: show picker again only after a block (can be the same player).
    return impact.isBlock;
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

/// Returns the playerId of whoever last touched the ball (any side), or null.
String? _lastPlayerWhoTouched(MatchState state) {
  for (var i = state.rallyImpacts.length - 1; i >= 0; i--) {
    final imp = state.rallyImpacts[i];
    if (!imp.isServerPosition) return imp.playerId;
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

class _CourtState extends ConsumerState<Court>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_pulseCtrl.repeat(reverse: true));
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Offset? _swipeDragStart;

  // Manual double-tap detection to avoid Flutter's 300ms single-tap delay.
  DateTime? _lastTapTime;
  Offset? _lastTapPos;
  bool _tapHandled = false; // true = onTapDown added an impact this tap

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

    final leftPlayers = state.teams[leftTeam]!.players;
    final rightPlayers = state.teams[rightTeam]!.players;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final outerW = constraints.maxWidth.clamp(0.0, _maxOuterW);
        final innerW = (outerW - kCourtMargin * 2).clamp(80.0, double.infinity);
        final innerH = innerW / 2;
        final outerH = innerH + kCourtMargin * 2;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player labels above court: J1 for each team
            SizedBox(
              height: 20,
              child: Row(
                children: [
                  const SizedBox(width: kCourtMargin),
                  Expanded(
                    child: Center(
                      child: Text(
                        leftPlayers.isNotEmpty ? leftPlayers[0].name : '',
                        style: MH.sans(
                          size: 13,
                          weight: FontWeight.w700,
                          color: leftColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        rightPlayers.isNotEmpty ? rightPlayers[0].name : '',
                        style: MH.sans(
                          size: 13,
                          weight: FontWeight.w700,
                          color: rightColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: kCourtMargin),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                width: outerW,
                height: outerH,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: MH.ruleSoft,
                  borderRadius: BorderRadius.circular(8),
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
                    child: SizedBox(
                      width: innerW,
                      height: innerH,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) =>
                            _onInnerTapDown(d.localPosition, outerW, outerH, innerH),
                        onTapCancel: _onInnerTapCancel,
                        onLongPressStart: (d) => _onInsideLongPress(
                            d.localPosition, outerW, outerH, innerW, state),
                        onVerticalDragStart: (d) {
                          _swipeDragStart = d.localPosition;
                        },
                        onVerticalDragEnd: (d) => _onInsideSwipe(
                            d.velocity, outerW, outerH),
                        onVerticalDragCancel: () {
                          _swipeDragStart = null;
                        },
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
                  ),
                  if (!isReplay)
                    ...['p1', 'p2', 'p3', 'p4'].map(
                      (id) => PlayerDot(
                        key: ValueKey('dot-$id'),
                        playerId: id,
                        outerHeight: outerH,
                        courtWidth: innerW,
                        courtHeight: innerH,
                      ),
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
                    Builder(
                      builder: (ctx) {
                        final imp = impactsToShow[i];
                        final isLastImpact = i == impactsToShow.length - 1;
                        final pName = (!imp.isServerPosition && imp.playerId != null)
                            ? (isLastImpact && !imp.isOutside && isReplay
                                ? null
                                : state.playerById(imp.playerId!)?.name)
                            : null;
                        final topOff = pName != null ? 22.0 : 11.0;
                        return Positioned(
                          left: imp.x * outerW - 11,
                          top: imp.y * outerH - topOff,
                          child: IgnorePointer(
                            child: ImpactMarker(
                              index: _impactIndex(impactsToShow, i),
                              isOutside: imp.isOutside,
                              isServerPosition: imp.isServerPosition,
                              isBlock: imp.isBlock,
                              isFinal: isReplay &&
                                  i == impactsToShow.length - 1 &&
                                  !imp.isServerPosition,
                              visitIndex: _visitIndex(impactsToShow, i),
                              playerName: pName,
                            ),
                          ),
                        );
                      },
                    ),
                  if (!isReplay &&
                      state.history.isEmpty &&
                      state.rallyImpacts.isEmpty)
                    _TapAffordance(
                      animation: _pulseAnim,
                      servingIsLeft: state.leftTeam ==
                          state.teamOfPlayer(state.servingPlayerId),
                      outerW: outerW,
                      outerH: outerH,
                      margin: kCourtMargin,
                    ),
                  if (state.popup is FaultPopup)
                    const Positioned.fill(child: FaultOverlay()),
                  if (state.popup is PickServerPopup)
                    const Positioned.fill(child: PickServerOverlay()),
                  if (state.popup is PickPlayerPopup)
                    const Positioned.fill(child: PlayerPickerOverlay()),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            // Player labels below court: J2 for each team
            SizedBox(
              height: 20,
              child: Row(
                children: [
                  const SizedBox(width: kCourtMargin),
                  Expanded(
                    child: Center(
                      child: Text(
                        leftPlayers.length > 1 ? leftPlayers[1].name : '',
                        style: MH.sans(
                          size: 13,
                          weight: FontWeight.w700,
                          color: leftColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        rightPlayers.length > 1 ? rightPlayers[1].name : '',
                        style: MH.sans(
                          size: 13,
                          weight: FontWeight.w700,
                          color: rightColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: kCourtMargin),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  static const _doubleTapMaxMs = 320;
  static const _doubleTapMaxDist = 55.0;

  /// Fires immediately on finger-down (no 300ms Flutter disambiguation delay).
  /// Handles both single tap and manual double-tap detection.
  void _onInnerTapDown(Offset p, double outerW, double outerH, double innerH) {
    if (_maybeDismissReplay()) return;
    final now = DateTime.now();
    final last = _lastTapTime;
    final lastPos = _lastTapPos;

    final isDoubleTap = last != null &&
        lastPos != null &&
        now.difference(last).inMilliseconds < _doubleTapMaxMs &&
        (p - lastPos).distance < _doubleTapMaxDist;

    if (isDoubleTap) {
      // Cancel first tap's impact, register block instead.
      if (_tapHandled) {
        final s = ref.read(matchProvider);
        if (s.popup is PickPlayerPopup) {
          ref.read(matchProvider.notifier).dismissPopup();
        } else {
          ref.read(matchProvider.notifier).undoLastImpact();
        }
        _tapHandled = false;
      }
      _lastTapTime = null;
      _lastTapPos = null;
      _handleBlock(p, outerW, outerH, innerH);
    } else {
      _lastTapTime = now;
      _lastTapPos = p;
      _tapHandled = true;
      _handleSingleTap(p, outerW, outerH);
    }
  }

  /// Called when the tap is cancelled (drag or long-press wins the arena).
  void _onInnerTapCancel() {
    if (_tapHandled) {
      final s = ref.read(matchProvider);
      if (s.popup is PickPlayerPopup) {
        ref.read(matchProvider.notifier).dismissPopup();
      } else {
        ref.read(matchProvider.notifier).undoLastImpact();
      }
      _tapHandled = false;
    }
    _lastTapTime = null;
    _lastTapPos = null;
  }

  void _handleSingleTap(Offset p, double outerW, double outerH) {
    final nx = (p.dx + kCourtMargin) / outerW;
    final ny = (p.dy + kCourtMargin) / outerH;
    _handleTouch(
      nx, ny,
      isOutside: false,
      isBlock: false,
      screenPos: Offset(p.dx + kCourtMargin, p.dy + kCourtMargin),
    );
  }

  /// Block annotation. Vertical position determines player:
  /// top half = J1 (index 0), bottom half = J2 (index 1).
  void _handleBlock(Offset p, double outerW, double outerH, double innerH) {
    final nx = (p.dx + kCourtMargin) / outerW;
    final ny = (p.dy + kCourtMargin) / outerH;
    final state = ref.read(matchProvider);
    final teamSide = nx < 0.5 ? state.leftTeam : state.rightTeam;
    final players = state.teams[teamSide]!.players;
    final playerIdx = p.dy < innerH / 2 ? 0 : 1;
    final playerId = players[playerIdx.clamp(0, players.length - 1)].id;
    ref.read(matchProvider.notifier).addTouchWithPlayer(
          BallImpact(
            x: nx,
            y: ny,
            isOutside: false,
            teamSide: teamSide,
            playerId: playerId,
            isBlock: true,
          ),
        );
  }

  /// Vertical swipe inside: impact at drag-start position, player determined
  /// by direction — swipe up = players[0] (J1), swipe down = players[1] (J2).
  void _onInsideSwipe(Velocity velocity, double outerW, double outerH) {
    if (_maybeDismissReplay()) return;
    final start = _swipeDragStart;
    _swipeDragStart = null;
    if (start == null) return;
    if (velocity.pixelsPerSecond.dy.abs() < 100) return;

    final nx = (start.dx + kCourtMargin) / outerW;
    final ny = (start.dy + kCourtMargin) / outerH;
    final state = ref.read(matchProvider);
    final teamSide = nx < 0.5 ? state.leftTeam : state.rightTeam;
    final players = state.teams[teamSide]!.players;
    final playerIdx = velocity.pixelsPerSecond.dy < 0 ? 0 : 1;
    final playerId = players[playerIdx.clamp(0, players.length - 1)].id;

    ref.read(matchProvider.notifier).addTouchWithPlayer(
          BallImpact(
            x: nx,
            y: ny,
            isOutside: false,
            teamSide: teamSide,
            playerId: playerId,
          ),
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
    // If addBallImpact already resolved the point internally (4th-touch
    // auto-fault), rallyImpacts will be empty — skip the second addPoint.
    if (ref.read(matchProvider).rallyImpacts.isEmpty) return;
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
      // Outside tap = ball out of bounds → ends the rally immediately.
      _handleOutBall(p, xNorm, yNorm, outerW, state);
    }
  }

  /// Long-press outside: same semantics as tap — ball out, rally ends.
  void _onOutsideLongPress(
    Offset p,
    double outerW,
    double outerH,
    MatchState state,
  ) {
    if (_maybeDismissReplay()) return;
    final xNorm = p.dx / outerW;
    final yNorm = p.dy / outerH;
    _handleOutBall(p, xNorm, yNorm, outerW, state);
  }

  /// Records an out-of-bounds ball impact and awards the point to the
  /// opponent of whoever last sent the ball.
  void _handleOutBall(
    Offset p,
    double xNorm,
    double yNorm,
    double outerW,
    MatchState state,
  ) {
    final landingSide = xNorm < 0.5 ? state.leftTeam : state.rightTeam;
    // Attribute the out impact to whoever last touched the ball (the faulter),
    // not to the last player on the landing side.
    final playerId = _lastPlayerWhoTouched(state);
    ref.read(matchProvider.notifier).addBallImpact(
          BallImpact(
            x: xNorm,
            y: yNorm,
            isOutside: true,
            teamSide: landingSide,
            playerId: playerId,
          ),
        );

    final s = ref.read(matchProvider);
    final impacts = s.rallyImpacts;

    // Find the last real contact before the out impact (index length-2 and back).
    // That player sent the ball out → their team loses.
    BallImpact? lastContact;
    for (var i = impacts.length - 2; i >= 0; i--) {
      if (!impacts[i].isServerPosition) {
        lastContact = impacts[i];
        break;
      }
    }

    final TeamSide winner;
    final String faulterName;
    if (lastContact != null) {
      winner = lastContact.teamSide.other;
      faulterName = s.playerById(lastContact.playerId ?? '')?.name ?? '—';
    } else {
      // No real contact yet = service fault. Server always loses the point
      // regardless of which side the ball lands on.
      final serverTeam = s.teamOfPlayer(s.servingPlayerId)!;
      winner = serverTeam.other;
      faulterName = s.playerById(s.servingPlayerId)?.name ?? '—';
    }

    ref.read(matchProvider.notifier).addPoint(
          winner: winner,
          annotations: [
            Annotation(
              type: 'fault',
              text: 'Dehors · $faulterName',
              team: winner.other,
            ),
          ],
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
            PickPlayerPopup(
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
      final playerIds =
          state.teams[teamSide]!.players.map((p) => p.id).toList();
      final playerId = TouchAttribution.inferNextPlayer(
            impacts: state.rallyImpacts,
            side: teamSide,
            playerIds: playerIds,
          ) ??
          _lastPlayerOnSide(state, teamSide);
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

  /// Returns how many net crossings occurred before impact [i].
  /// Server-position impacts inherit the index of the next real contact.
  int _visitIndex(List<BallImpact> impacts, int i) {
    var vi = 0;
    TeamSide? lastSide;
    for (var j = 0; j <= i; j++) {
      final imp = impacts[j];
      if (imp.isServerPosition) continue;
      if (lastSide != null && imp.teamSide != lastSide) vi++;
      lastSide = imp.teamSide;
    }
    return vi;
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

// ---------------------------------------------------------------------------
// First-touch affordance overlay
// ---------------------------------------------------------------------------

class _TapAffordance extends StatelessWidget {
  const _TapAffordance({
    required this.animation,
    required this.servingIsLeft,
    required this.outerW,
    required this.outerH,
    required this.margin,
  });

  final Animation<double> animation;
  final bool servingIsLeft;
  final double outerW;
  final double outerH;
  final double margin;

  @override
  Widget build(BuildContext context) {
    // Highlight the opponent's half (where the serve should land).
    final opponentLeft = !servingIsLeft;
    final halfLeft = opponentLeft ? margin : outerW / 2;
    final halfWidth = outerW / 2 - margin;

    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => Positioned(
        left: halfLeft,
        top: margin,
        width: halfWidth,
        height: outerH - margin * 2,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: MH.ball.withValues(
                alpha: 0.04 + animation.value * 0.08,
              ),
              border: Border.all(
                color: MH.ball.withValues(
                  alpha: 0.15 + animation.value * 0.25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
