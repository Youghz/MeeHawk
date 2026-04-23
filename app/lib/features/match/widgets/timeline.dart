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

  // Auto-scroll right when new points arrive in the same set.
  // Jump to start when the displayed set changes.
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
    // Follow live set transitions automatically.
    ref.listen(matchProvider.select((s) => s.setNumber), (prev, next) {
      if (prev != null && next > prev) {
        setState(() => _selectedSet = next);
      }
    });

    final history = ref.watch(matchProvider.select((s) => s.history));
    final selected = ref.watch(matchProvider.select((s) => s.selectedPointIndex));
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

    final sets = history.map((p) => p.setNumber).toSet().toList()..sort();
    // If the selected set no longer exists (shouldn't happen), fall back to last.
    final effectiveSet =
        sets.contains(_selectedSet) ? _selectedSet : sets.last;

    // Build filtered list for the effective set, keeping global indices.
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
          if (sets.length > 1) ...[
            _SetPicker(
              sets: sets,
              selected: effectiveSet,
              onSelect: (s) => setState(() => _selectedSet = s),
            ),
            const SizedBox(height: 4),
          ],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(setPts, globalIndices, TeamSide.e1, MH.them,
                          selected),
                      const SizedBox(height: 3),
                      _row(setPts, globalIndices, TeamSide.e2, MH.us,
                          selected),
                    ],
                  ),
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

  Widget _row(
    List<PointRecord> setPts,
    List<int> globalIndices,
    TeamSide tk,
    Color color,
    int? selected,
  ) {
    const cellW = 20.0;
    const cellGap = 2.0;
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          for (var i = 0; i < setPts.length; i++) ...[
            if (i > 0) const SizedBox(width: cellGap),
            _cell(setPts, globalIndices, i, tk, color, cellW, selected),
          ],
        ],
      ),
    );
  }

  Widget _cell(
    List<PointRecord> setPts,
    List<int> globalIndices,
    int localIdx,
    TeamSide tk,
    Color color,
    double w,
    int? selected,
  ) {
    final p = setPts[localIdx];
    final globalIdx = globalIndices[localIdx];
    final active = selected == globalIdx;
    final isMine = p.winner == tk;
    final teamScore = p.scoreOf(tk);
    return GestureDetector(
      onTap: () => ref.read(matchProvider.notifier).selectPoint(globalIdx),
      child: Container(
        width: w,
        height: 16,
        decoration: BoxDecoration(
          color: isMine ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: isMine ? null : Border.all(color: MH.rule),
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

// ─────────────────────────────────────────────────────────────────────────────
// Set picker chips
// ─────────────────────────────────────────────────────────────────────────────

class _SetPicker extends StatelessWidget {
  const _SetPicker({
    required this.sets,
    required this.selected,
    required this.onSelect,
  });
  final List<int> sets;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final s in sets)
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
                    border:
                        s == selected ? null : Border.all(color: MH.rule),
                  ),
                  child: Text(
                    'Set $s',
                    style: MH.sans(
                      size: 10,
                      weight: FontWeight.w600,
                      color: s == selected ? MH.paper : MH.pencil,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}
