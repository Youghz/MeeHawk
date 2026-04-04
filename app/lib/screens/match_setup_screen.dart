import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../theme.dart';
import 'match_screen.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  final _us1 = TextEditingController(text: 'Joueur 1');
  final _us2 = TextEditingController(text: 'Joueur 2');
  final _them1 = TextEditingController(text: 'Joueur 1');
  final _them2 = TextEditingController(text: 'Joueur 2');
  final _teamUs = TextEditingController(text: 'Equipe A');
  final _teamThem = TextEditingController(text: 'Equipe B');
  int _pointsPerSet = 21;

  @override
  void dispose() {
    _us1.dispose(); _us2.dispose();
    _them1.dispose(); _them2.dispose();
    _teamUs.dispose(); _teamThem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text('Nouveau match',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 32),
                _teamSection(AppColors.green, _teamUs, _us1, _us2),
                const SizedBox(height: 24),
                _teamSection(AppColors.red, _teamThem, _them1, _them2),
                const SizedBox(height: 24),
                // Points per set
                Row(
                  children: [
                    Text('Points par set',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const Spacer(),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 15, label: Text('15')),
                        ButtonSegment(value: 21, label: Text('21')),
                        ButtonSegment(value: 25, label: Text('25')),
                      ],
                      selected: {_pointsPerSet},
                      onSelectionChanged: (v) => setState(() => _pointsPerSet = v.first),
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Commencer la partie',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamSection(Color color, TextEditingController teamCtrl,
      TextEditingController p1, TextEditingController p2) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(child: _field(teamCtrl, style: TextStyle(
                fontSize: 15, color: color, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(p1, hint: 'Joueur 1')),
            const SizedBox(width: 10),
            Expanded(child: _field(p2, hint: 'Joueur 2')),
          ]),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, {TextStyle? style, String? hint}) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.accent)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: AppColors.surfaceLight,
      ),
      style: style ?? const TextStyle(fontSize: 14),
      onTap: () => c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length),
    );
  }

  void _start() {
    ref.read(matchProvider.notifier).startMatch(
      teamUsName: _teamUs.text.trim().isEmpty ? 'Equipe A' : _teamUs.text.trim(),
      teamThemName: _teamThem.text.trim().isEmpty ? 'Equipe B' : _teamThem.text.trim(),
      playerA: _us1.text.trim().isEmpty ? 'Joueur 1' : _us1.text.trim(),
      playerB: _us2.text.trim().isEmpty ? 'Joueur 2' : _us2.text.trim(),
      opponentA: _them1.text.trim().isEmpty ? 'Joueur 1' : _them1.text.trim(),
      opponentB: _them2.text.trim().isEmpty ? 'Joueur 2' : _them2.text.trim(),
      pointsPerSet: _pointsPerSet,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MatchScreen()),
    );
  }
}
