import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../theme.dart';

class TopScore extends ConsumerWidget {
  const TopScore({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final leftTk = state.sidesSwapped ? 'e2' : 'e1';
    final rightTk = state.sidesSwapped ? 'e1' : 'e2';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: MH.paper,
        border: Border(bottom: BorderSide(color: MH.rule)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TeamHead(tk: leftTk, align: TextAlign.right),
                const SizedBox(width: 10),
                _Score(value: state.scoreOf(leftTk)),
              ],
            ),
          ),
          Text(' · ', style: MH.sans(size: 18, color: MH.rule)),
          Expanded(
            child: Row(
              children: [
                _Score(value: state.scoreOf(rightTk)),
                const SizedBox(width: 10),
                _TeamHead(tk: rightTk, align: TextAlign.left),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  final int value;
  const _Score({required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 36,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: MH.sans(
            size: 34,
            weight: FontWeight.w700,
            color: MH.ink,
            height: 1,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      );
}

class _TeamHead extends ConsumerWidget {
  final String tk;
  final TextAlign align;
  const _TeamHead({required this.tk, required this.align});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final team = state.teams[tk]!;
    final color = tk == 'e1' ? MH.them : MH.us;
    return Flexible(
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _EditableText(
            value: team.name,
            onChanged: (v) =>
                ref.read(matchProvider.notifier).renameTeam(tk, v),
            style: MH.sans(
              size: 12,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            alignment: align == TextAlign.right
                ? WrapAlignment.end
                : WrapAlignment.start,
            children: [
              for (int i = 0; i < team.players.length; i++) ...[
                if (i > 0)
                  Text(' · ',
                      style: MH.sans(size: 11, color: MH.pencil)),
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
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableText extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final TextStyle style;
  const _EditableText({
    required this.value,
    required this.onChanged,
    required this.style,
  });

  @override
  State<_EditableText> createState() => _EditableTextState();
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
          ),
          onSubmitted: (_) => _focus.unfocus(),
        ),
      );
}
