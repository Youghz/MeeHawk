import 'package:app/core/widgets/court/court.dart';
import 'package:app/core/widgets/court/impact_marker.dart';
import 'package:app/domain/match_state.dart';
import 'package:app/state/match_provider.dart';
import 'package:app/state/replay_notifier.dart';
import 'package:app/state/video_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wiring test for the progressive reveal: the pure rule is covered by
/// video_timeline_test.dart, this checks the court actually honours the
/// published video position.
void main() {
  BallImpact impact(double t, {bool serverPos = false}) => BallImpact(
        x: 0.3,
        y: 0.5,
        isOutside: false,
        teamSide: TeamSide.e1,
        playerId: 'p1',
        isServerPosition: serverPos,
        videoTimeSec: t,
      );

  PointRecord rally(List<BallImpact> impacts) => PointRecord(
        winner: TeamSide.e1,
        annotations: const [],
        scoreE1: 1,
        scoreE2: 0,
        setNumber: 1,
        serverId: 'p3',
        impacts: impacts,
      );

  final annotated = initialMatchState().copyWith(
    started: true,
    history: [
      rally([
        impact(10, serverPos: true),
        impact(11),
        impact(13),
        impact(15),
      ]),
    ],
  );

  Future<void> pumpCourt(
    WidgetTester tester,
    MatchState state, {
    double? videoPosition,
  }) async {
    final container = ProviderContainer(
      overrides: [matchProvider.overrideWith(() => ReplayNotifier(state))],
    );
    addTearDown(container.dispose);
    if (videoPosition != null) {
      container.read(videoPositionProvider.notifier).moveTo(videoPosition);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: Court())),
        ),
      ),
    );
    await tester.pump();
  }

  int markers(WidgetTester tester) =>
      tester.widgetList(find.byType(ImpactMarker)).length;

  testWidgets('no video position shows nothing outside a selected rally',
      (tester) async {
    await pumpCourt(tester, annotated);
    expect(markers(tester), 0);
  });

  testWidgets('scrubbing reveals the rally touch by touch', (tester) async {
    await pumpCourt(tester, annotated, videoPosition: 9);
    expect(markers(tester), 0, reason: 'avant le début du rallye');

    await pumpCourt(tester, annotated, videoPosition: 11);
    expect(markers(tester), 2, reason: 'position de service + service');

    await pumpCourt(tester, annotated, videoPosition: 14);
    expect(markers(tester), 3);

    await pumpCourt(tester, annotated, videoPosition: 60);
    expect(markers(tester), 4, reason: 'rallye entier une fois dépassé');
  });

  testWidgets('a match scored without video is unaffected', (tester) async {
    // The human-annotated corpus match has no timestamps at all; a stale video
    // position from another screen must not make its impacts appear or vanish.
    final untimed = initialMatchState().copyWith(
      started: true,
      history: [
        rally([
          const BallImpact(
            x: 0.3, y: 0.5, isOutside: false, teamSide: TeamSide.e1,
          ),
          const BallImpact(
            x: 0.6, y: 0.5, isOutside: false, teamSide: TeamSide.e2,
          ),
        ]),
      ],
    );
    await pumpCourt(tester, untimed, videoPosition: 42);
    expect(markers(tester), 0, reason: 'aucun horodatage : rien à révéler');
  });
}
