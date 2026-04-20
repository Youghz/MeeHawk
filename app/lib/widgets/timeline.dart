import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_state.dart';
import '../providers/match_provider.dart';
import '../theme.dart';

class Timeline extends ConsumerStatefulWidget {
  const Timeline({super.key});

  @override
  ConsumerState<Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<Timeline> {
  final _e1Ctrl = ScrollController();
  final _e2Ctrl = ScrollController();
  int _lastLength = 0;

  @override
  void dispose() {
    _e1Ctrl.dispose();
    _e2Ctrl.dispose();
    super.dispose();
  }

  void _maybeAutoscroll(int length) {
    if (length == _lastLength) return;
    _lastLength = length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in [_e1Ctrl, _e2Ctrl]) {
        if (c.hasClients) {
          c.animateTo(
            c.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);
    _maybeAutoscroll(state.history.length);

    if (state.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Center(
          child: Text(
            'Aucun point marqué — tap terrain adverse (service) ou long-press (attaque/faute)',
            textAlign: TextAlign.center,
            style: MH.sans(
              size: 10,
              color: MH.pencil,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Column(
        children: [
          _row(state, 'e1', 'E1', MH.them, _e1Ctrl),
          const SizedBox(height: 3),
          _row(state, 'e2', 'E2', MH.us, _e2Ctrl),
        ],
      ),
    );
  }

  Widget _row(MatchState state, String tk, String label, Color color,
      ScrollController ctrl) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(label,
              style: MH.sans(
                size: 9,
                weight: FontWeight.w700,
                color: color,
                letterSpacing: 0.4,
              )),
        ),
        Expanded(
          child: SizedBox(
            height: 16,
            child: ListView.separated(
              controller: ctrl,
              scrollDirection: Axis.horizontal,
              itemCount: state.history.length,
              separatorBuilder: (_, i) => const SizedBox(width: 2),
              itemBuilder: (_, i) {
                final p = state.history[i];
                final active = state.selectedPointIndex == i;
                final isMine = p.winner == tk;
                final teamScore = p.scoreOf(tk);
                return GestureDetector(
                  onTap: () =>
                      ref.read(matchProvider.notifier).selectPoint(i),
                  child: Container(
                    width: 20,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isMine ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                      border: isMine
                          ? null
                          : Border.all(color: MH.rule, width: 1),
                    ),
                    foregroundDecoration: active
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: MH.ink, width: 1.5),
                          )
                        : null,
                    alignment: Alignment.center,
                    child: isMine
                        ? Text(
                            '$teamScore',
                            style: MH.sans(
                              size: 9,
                              weight: FontWeight.w700,
                              color: MH.paper,
                            ).copyWith(fontFeatures: const [
                              FontFeature.tabularFigures()
                            ]),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
