import 'package:app/core/theme.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TopScore extends ConsumerWidget {
  const TopScore({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leftTeam = ref.watch(matchProvider.select((s) => s.leftTeam));
    final scoreLeft =
        ref.watch(matchProvider.select((s) => s.scoreOf(leftTeam)));
    final scoreRight =
        ref.watch(matchProvider.select((s) => s.scoreOf(leftTeam.other)));
    final setsLeft =
        ref.watch(matchProvider.select((s) => s.setsWonOf(leftTeam)));
    final setsRight =
        ref.watch(matchProvider.select((s) => s.setsWonOf(leftTeam.other)));
    final showSets = setsLeft > 0 || setsRight > 0;
    final setNumber = ref.watch(matchProvider.select((s) => s.setNumber));
    final matchOver = ref.watch(matchProvider.select((s) => s.matchOver));
    final nameE1 = ref.watch(matchProvider.select((s) => s.teams[TeamSide.e1]!.name));
    final nameE2 = ref.watch(matchProvider.select((s) => s.teams[TeamSide.e2]!.name));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: MH.paper,
        border: Border(bottom: BorderSide(color: MH.rule)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _TeamHead(tk: leftTeam, align: TextAlign.right),
                    const SizedBox(width: 10),
                    _Score(value: scoreLeft),
                  ],
                ),
              ),
              Text(' · ', style: MH.sans(size: 18, color: MH.rule)),
              Expanded(
                child: Row(
                  children: [
                    _Score(value: scoreRight),
                    const SizedBox(width: 10),
                    _TeamHead(tk: leftTeam.other, align: TextAlign.left),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            showSets
                ? 'SET $setNumber · Sets $setsLeft–$setsRight'
                : 'SET $setNumber',
            style: MH.sans(
              size: 10,
              weight: FontWeight.w600,
              color: MH.pencil,
              letterSpacing: 0.6,
            ),
          ),
          if (matchOver) ...[
            const SizedBox(height: 5),
            _WinnerBadge(
              winnerName: setsLeft > setsRight ? nameE1 : nameE2,
              winnerSide: setsLeft > setsRight ? leftTeam : leftTeam.other,
            ),
          ],
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 36),
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: MH.sans(
            size: 34,
            weight: FontWeight.w700,
            height: 1,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      );
}

class _TeamHead extends ConsumerWidget {
  const _TeamHead({required this.tk, required this.align});

  final TeamSide tk;
  final TextAlign align;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(matchProvider.select((s) => s.teams[tk]!));
    final color = tk == TeamSide.e1 ? MH.them : MH.us;
    final isTracked = ref.watch(
      matchProvider.select((s) => s.trackedTeams.contains(tk)),
    );
    final isRight = align == TextAlign.right;

    return Flexible(
      child: Column(
        crossAxisAlignment:
            isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isRight) ...[
                _EditableText(
                  value: team.name,
                  onChanged: (v) =>
                      ref.read(matchProvider.notifier).renameTeam(tk, v),
                  style: MH.sans(size: 12, weight: FontWeight.w700, color: color),
                ),
                const SizedBox(width: 6),
                _RecordBadge(
                  active: isTracked,
                  onTap: () =>
                      ref.read(matchProvider.notifier).toggleTeamTracking(tk),
                ),
              ] else ...[
                _RecordBadge(
                  active: isTracked,
                  onTap: () =>
                      ref.read(matchProvider.notifier).toggleTeamTracking(tk),
                ),
                const SizedBox(width: 6),
                _EditableText(
                  value: team.name,
                  onChanged: (v) =>
                      ref.read(matchProvider.notifier).renameTeam(tk, v),
                  style: MH.sans(size: 12, weight: FontWeight.w700, color: color),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          for (int i = 0; i < team.players.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment:
                    isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    'J${i + 1} ',
                    style: MH.sans(
                      size: 10,
                      weight: FontWeight.w600,
                      color: MH.pencil,
                    ),
                  ),
                  _EditableText(
                    value: team.players[i].name,
                    onChanged: (v) => ref
                        .read(matchProvider.notifier)
                        .renamePlayer(team.players[i].id, v),
                    style: MH.sans(
                      size: 11,
                      weight: FontWeight.w500,
                      color: MH.pencil,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordBadge extends StatelessWidget {
  const _RecordBadge({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(
              color: active ? MH.bad : MH.rule,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.fiber_manual_record,
            size: 10,
            color: active ? MH.bad : MH.rule,
          ),
        ),
      );
}

class _EditableText extends StatefulWidget {
  const _EditableText({
    required this.value,
    required this.onChanged,
    required this.style,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final TextStyle style;

  @override
  State<_EditableText> createState() => _EditableTextState();
}

class _WinnerBadge extends StatelessWidget {
  const _WinnerBadge({required this.winnerName, required this.winnerSide});

  final String winnerName;
  final TeamSide winnerSide;

  @override
  Widget build(BuildContext context) {
    final color = winnerSide == TeamSide.e1 ? MH.them : MH.us;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.emoji_events_rounded, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          '${winnerName.toUpperCase()} REMPORTE LE MATCH',
          style: MH.sans(
            size: 9,
            weight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _EditableTextState extends State<_EditableText> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) widget.onChanged(_ctrl.text.trim());
  }

  @override
  void didUpdateWidget(covariant _EditableText old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text && !_focus.hasFocus) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: widget.style,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 2),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: MH.rule),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: MH.rule),
            ),
            suffixIcon: Icon(
              Icons.edit,
              size: 10,
              color: MH.rule,
            ),
            suffixIconConstraints: BoxConstraints(maxWidth: 14, maxHeight: 14),

          ),
          onSubmitted: (_) => _focus.unfocus(),
        ),
      );
}
