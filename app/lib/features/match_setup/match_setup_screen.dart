import 'dart:async';

import 'package:app/core/rules/match_format.dart';
import 'package:app/core/theme.dart';
import 'package:app/features/match/match_screen.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  final _team1 = TextEditingController(text: 'Équipe 1');
  final _team2 = TextEditingController(text: 'Équipe 2');
  final _p1 = TextEditingController(text: 'Joueur 1');
  final _p2 = TextEditingController(text: 'Joueur 2');
  final _p3 = TextEditingController(text: 'Joueur 3');
  final _p4 = TextEditingController(text: 'Joueur 4');
  String _initialServerId = 'p1';
  int _setsToWin = 2;
  int _setPoints = 21;
  int _changeSideEvery = 7;

  @override
  void dispose() {
    _team1.dispose();
    _team2.dispose();
    _p1.dispose();
    _p2.dispose();
    _p3.dispose();
    _p4.dispose();
    super.dispose();
  }

  String _pickerLabel(String id) {
    final (ctrl, fallback) = switch (id) {
      'p1' => (_p1, 'Joueur 1'),
      'p2' => (_p2, 'Joueur 2'),
      'p3' => (_p3, 'Joueur 3'),
      _ => (_p4, 'Joueur 4'),
    };
    final text = ctrl.text.trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MH.paper,
        appBar: AppBar(
          backgroundColor: MH.paper,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: MH.ink),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text('Nouveau match',
                        style: MH.sans(
                          size: 22,
                          weight: FontWeight.w700,
                        )),
                  ),
                  const SizedBox(height: 32),
                  _teamSection(MH.them, _team1, _p1, _p2),
                  const SizedBox(height: 16),
                  _teamSection(MH.us, _team2, _p3, _p4),
                  const SizedBox(height: 24),
                  _serverPicker(),
                  const SizedBox(height: 24),
                  _formatSection(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _start,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MH.ink,
                        foregroundColor: MH.paper,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text('Commencer la partie',
                          style: MH.sans(
                            size: 16,
                            weight: FontWeight.w600,
                            color: MH.paper,
                          )),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
        ),
      );

  Widget _teamSection(
      Color color,
      TextEditingController team,
      TextEditingController pA,
      TextEditingController pB,
    ) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MH.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    team,
                    style: MH.sans(
                      size: 15,
                      weight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(pA, hint: 'Joueur 1')),
              const SizedBox(width: 10),
              Expanded(child: _field(pB, hint: 'Joueur 2')),
            ]),
          ],
        ),
      );

  Widget _field(TextEditingController c, {TextStyle? style, String? hint}) =>
      TextField(
        controller: c,
        style: style ?? MH.sans(),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: MH.sans(size: 13, color: MH.pencil),
          isDense: true,
          filled: true,
          fillColor: MH.sand,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: MH.rule),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: MH.rule),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: MH.ink, width: 1.5),
          ),
        ),
      );

  Widget _serverPicker() {
    final options = ['p1', 'p2', 'p3', 'p4'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Premier serveur',
            style: MH.sans(
              size: 13,
              weight: FontWeight.w600,
              color: MH.inkSoft,
            )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((id) {
            final selected = id == _initialServerId;
            final color =
                (id == 'p1' || id == 'p2') ? MH.them : MH.us;
            return ChoiceChip(
              label: Text(
                _pickerLabel(id),
                style: MH.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  color: selected ? MH.paper : color,
                ),
              ),
              selected: selected,
              selectedColor: color,
              backgroundColor: MH.paper,
              side: BorderSide(color: color, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              onSelected: (_) => setState(() => _initialServerId = id),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _start() {
    String name(TextEditingController c, String fallback) {
      final t = c.text.trim();
      return t.isEmpty ? fallback : t;
    }

    ref.read(matchProvider.notifier).startMatch(
          teamE1Name: name(_team1, 'Équipe 1'),
          teamE2Name: name(_team2, 'Équipe 2'),
          p1: name(_p1, 'Joueur 1'),
          p2: name(_p2, 'Joueur 2'),
          p3: name(_p3, 'Joueur 3'),
          p4: name(_p4, 'Joueur 4'),
          initialServerId: _initialServerId,
          format: MatchFormat(
            setsToWin: _setsToWin,
            regularSetPoints: _setPoints,
            regularChangeSideEvery: _changeSideEvery,
          ),
        );
    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MatchScreen()),
    ));
  }

  Widget _formatSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FORMAT',
            style: MH.mono(
              weight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MH.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MH.rule, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sets à gagner',
                    style: MH.sans(size: 12, color: MH.inkSoft)),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2].map((n) {
                    final selected = n == _setsToWin;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '$n',
                          style: MH.sans(
                            size: 12,
                            weight: FontWeight.w600,
                            color: selected ? MH.paper : MH.inkSoft,
                          ),
                        ),
                        selected: selected,
                        selectedColor: MH.pencil,
                        backgroundColor: MH.sand,
                        side: BorderSide(
                          color: selected ? MH.pencil : MH.rule,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        onSelected: (_) => setState(() => _setsToWin = n),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text('Points par set',
                    style: MH.sans(size: 12, color: MH.inkSoft)),
                const SizedBox(height: 8),
                Row(
                  children: [15, 21, 25].map((n) {
                    final selected = n == _setPoints;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '$n',
                          style: MH.sans(
                            size: 12,
                            weight: FontWeight.w600,
                            color: selected ? MH.paper : MH.inkSoft,
                          ),
                        ),
                        selected: selected,
                        selectedColor: MH.pencil,
                        backgroundColor: MH.sand,
                        side: BorderSide(
                          color: selected ? MH.pencil : MH.rule,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        onSelected: (_) => setState(() => _setPoints = n),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Changer de côté tous les',
                        style: MH.sans(size: 12, color: MH.inkSoft),
                      ),
                    ),
                    _counter(
                      value: _changeSideEvery,
                      onDec: () => setState(() {
                        if (_changeSideEvery > 1) _changeSideEvery--;
                      }),
                      onInc: () =>
                          setState(() => _changeSideEvery++),
                    ),
                    const SizedBox(width: 8),
                    Text('pts', style: MH.sans(size: 12, color: MH.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _counter({
    required int value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _counterBtn(Icons.remove, onDec),
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                '$value',
                style: MH.sans(weight: FontWeight.w700),
              ),
            ),
          ),
          _counterBtn(Icons.add, onInc),
        ],
      );

  Widget _counterBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MH.sand,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MH.rule),
          ),
          child: Icon(icon, size: 14, color: MH.ink),
        ),
      );
}
