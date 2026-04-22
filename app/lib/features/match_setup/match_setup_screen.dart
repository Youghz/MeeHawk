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
  final _p1 = TextEditingController(text: 'Ana');
  final _p2 = TextEditingController(text: 'Sara');
  final _p3 = TextEditingController(text: 'Léa');
  final _p4 = TextEditingController(text: 'Marie');
  String _initialServerId = 'p3';

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
    switch (id) {
      case 'p1':
        return _p1.text.trim().isEmpty ? 'Joueur 1' : _p1.text.trim();
      case 'p2':
        return _p2.text.trim().isEmpty ? 'Joueur 2' : _p2.text.trim();
      case 'p3':
        return _p3.text.trim().isEmpty ? 'Joueur 3' : _p3.text.trim();
      default:
        return _p4.text.trim().isEmpty ? 'Joueur 4' : _p4.text.trim();
    }
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
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
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
        Text('Qui sert au départ ?',
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
    ref.read(matchProvider.notifier).startMatch(
          teamE1Name:
              _team1.text.trim().isEmpty ? 'Équipe 1' : _team1.text.trim(),
          teamE2Name:
              _team2.text.trim().isEmpty ? 'Équipe 2' : _team2.text.trim(),
          p1: _p1.text.trim().isEmpty ? 'Ana' : _p1.text.trim(),
          p2: _p2.text.trim().isEmpty ? 'Sara' : _p2.text.trim(),
          p3: _p3.text.trim().isEmpty ? 'Léa' : _p3.text.trim(),
          p4: _p4.text.trim().isEmpty ? 'Marie' : _p4.text.trim(),
          initialServerId: _initialServerId,
        );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MatchScreen()),
    );
  }
}
