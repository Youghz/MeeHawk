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
  final _ctrl = ScrollController();
  int _lastLength = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _maybeAutoscroll(int length) {
    if (length == _lastLength) return;
    _lastLength = length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients) {
        _ctrl.animateTo(
          _ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _teamLabel(state.teams['e1']!.name, MH.them),
                const SizedBox(height: 3),
                _teamLabel(state.teams['e2']!.name, MH.us),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(state, 'e1', MH.them),
                  const SizedBox(height: 3),
                  _row(state, 'e2', MH.us),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamLabel(String name, Color color) => SizedBox(
        height: 16,
        child: Text(
          name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: MH.sans(
            size: 9,
            weight: FontWeight.w700,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _row(MatchState state, String tk, Color color) {
    const cellW = 20.0;
    const cellGap = 2.0;
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          for (int i = 0; i < state.history.length; i++) ...[
            if (i > 0) const SizedBox(width: cellGap),
            _cell(state, i, tk, color, cellW),
          ],
        ],
      ),
    );
  }

  Widget _cell(MatchState state, int i, String tk, Color color, double w) {
    final p = state.history[i];
    final active = state.selectedPointIndex == i;
    final isMine = p.winner == tk;
    final teamScore = p.scoreOf(tk);
    return GestureDetector(
      onTap: () => ref.read(matchProvider.notifier).selectPoint(i),
      child: Container(
        width: w,
        height: 16,
        decoration: BoxDecoration(
          color: isMine ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: isMine ? null : Border.all(color: MH.rule, width: 1),
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
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              )
            : null,
      ),
    );
  }
}
