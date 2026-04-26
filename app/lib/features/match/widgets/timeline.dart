import 'dart:async';

import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Timeline extends ConsumerStatefulWidget {
  const Timeline({super.key});

  @override
  ConsumerState<Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<Timeline> {
  final _ctrl = ScrollController();
  int _selectedSet = 1;
  int _lastSetPtsLength = 0;
  int? _lastScrolledSet;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleScroll(int length, int set) {
    if (set != _lastScrolledSet) {
      _lastScrolledSet = set;
      _lastSetPtsLength = length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) _ctrl.jumpTo(0);
      });
      return;
    }
    if (length == _lastSetPtsLength) return;
    _lastSetPtsLength = length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients) {
        unawaited(_ctrl.animateTo(
          _ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref
      // Follow live set transitions.
      ..listen(matchProvider.select((s) => s.setNumber), (prev, next) {
        if (prev != null && next > prev) {
          setState(() => _selectedSet = next);
        }
      })
      // Sync set picker when a point is selected or selection is cleared.
      ..listen(matchProvider.select((s) => s.selectedPointIndex), (_, next) {
        final h = ref.read(matchProvider).history;
        final int targetSet;
        if (next == null) {
          targetSet = ref.read(matchProvider).setNumber;
        } else if (next < h.length) {
          targetSet = h[next].setNumber;
        } else {
          return;
        }
        if (_selectedSet != targetSet) setState(() => _selectedSet = targetSet);
      });

    final history = ref.watch(matchProvider.select((s) => s.history));
    final selected =
        ref.watch(matchProvider.select((s) => s.selectedPointIndex));
    final teamE1Name =
        ref.watch(matchProvider.select((s) => s.teams[TeamSide.e1]!.name));
    final teamE2Name =
        ref.watch(matchProvider.select((s) => s.teams[TeamSide.e2]!.name));

    if (history.isEmpty) {
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

    const maxSets = 3; // beach FIVB best-of-3
    final playedSets = history.map((p) => p.setNumber).toSet();
    final effectiveSet =
        playedSets.contains(_selectedSet) ? _selectedSet : playedSets.last;

    final setPts = <PointRecord>[];
    final globalIndices = <int>[];
    for (var i = 0; i < history.length; i++) {
      if (history[i].setNumber == effectiveSet) {
        setPts.add(history[i]);
        globalIndices.add(i);
      }
    }

    _handleScroll(setPts.length, effectiveSet);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SetPicker(
            allSets: List.generate(maxSets, (i) => i + 1),
            playedSets: playedSets,
            selected: effectiveSet,
            onSelect: (s) {
              if (!playedSets.contains(s)) return;
              setState(() => _selectedSet = s);
              final firstIdx =
                  history.indexWhere((p) => p.setNumber == s);
              if (firstIdx >= 0) {
                ref.read(matchProvider.notifier).selectPoint(firstIdx);
              } else {
                ref.read(matchProvider.notifier).viewSet(s);
              }
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _teamLabel(teamE1Name, MH.them),
                    const SizedBox(height: 3),
                    _teamLabel(teamE2Name, MH.us),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  child: _columns(setPts, globalIndices, selected),
                ),
              ),
            ],
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

  // Renders all points as a row of columns, each column spanning both teams.
  // The selection border wraps the entire column (E1 + gap + E2).
  Widget _columns(
    List<PointRecord> setPts,
    List<int> globalIndices,
    int? selected,
  ) {
    const colGap = 2.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < setPts.length; i++) ...[
          if (i > 0) const SizedBox(width: colGap),
          _column(setPts, globalIndices, i, selected),
        ],
      ],
    );
  }

  static const _cellW = 20.0;
  static const _cellH = 16.0;

  Widget _column(
    List<PointRecord> setPts,
    List<int> globalIndices,
    int i,
    int? selected,
  ) {
    final globalIdx = globalIndices[i];
    final isSelected = selected == globalIdx;
    final p = setPts[i];
    return GestureDetector(
      onTap: () =>
          ref.read(matchProvider.notifier).selectPoint(globalIdx),
      child: Container(
        width: _cellW,
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: MH.ink, width: 1.5),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cellContent(p, TeamSide.e1, MH.them),
            const SizedBox(height: 3),
            _cellContent(p, TeamSide.e2, MH.us),
          ],
        ),
      ),
    );
  }

  Widget _cellContent(PointRecord p, TeamSide tk, Color color) {
    final isMine = p.winner == tk;
    return Container(
      width: _cellW,
      height: _cellH,
      decoration: BoxDecoration(
        color: isMine ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: isMine ? null : Border.all(color: MH.rule),
      ),
      alignment: Alignment.center,
      child: isMine
          ? Text(
              '${p.scoreOf(tk)}',
              style: MH.sans(
                size: 9,
                weight: FontWeight.w700,
                color: MH.paper,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set picker chips
// ─────────────────────────────────────────────────────────────────────────────

class _SetPicker extends StatelessWidget {
  const _SetPicker({
    required this.allSets,
    required this.playedSets,
    required this.selected,
    required this.onSelect,
  });
  final List<int> allSets;
  final Set<int> playedSets;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final s in allSets)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: GestureDetector(
                onTap: () => onSelect(s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: s == selected ? MH.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: s == selected
                        ? null
                        : Border.all(
                            color: playedSets.contains(s)
                                ? MH.rule
                                : MH.rule.withValues(alpha: 0.4),
                          ),
                  ),
                  child: Text(
                    'Set $s',
                    style: MH.sans(
                      size: 10,
                      weight: FontWeight.w600,
                      color: s == selected
                          ? MH.paper
                          : playedSets.contains(s)
                              ? MH.pencil
                              : MH.pencil.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}
