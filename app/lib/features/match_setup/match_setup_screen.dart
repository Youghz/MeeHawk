import 'dart:async';

import 'package:app/core/rules/match_format.dart';
import 'package:app/core/theme.dart';
import 'package:app/features/match/match_screen.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:app/features/match_setup/widgets/setup_format_section.dart';
import 'package:app/features/match_setup/widgets/setup_server_picker.dart';
import 'package:app/features/match_setup/widgets/setup_team_section.dart';
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
  final _videoUrl = TextEditingController();
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
    _videoUrl.dispose();
    super.dispose();
  }

  Map<String, String> get _pickerLabels => {
        'p1': _label(_p1, 'Joueur 1'),
        'p2': _label(_p2, 'Joueur 2'),
        'p3': _label(_p3, 'Joueur 3'),
        'p4': _label(_p4, 'Joueur 4'),
      };

  String _label(TextEditingController c, String fallback) {
    final t = c.text.trim();
    return t.isEmpty ? fallback : t;
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Nouveau match',
                  style: MH.sans(size: 22, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 32),
              SetupTeamSection(
                color: MH.them,
                teamCtrl: _team1,
                pACtrl: _p1,
                pBCtrl: _p2,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              SetupTeamSection(
                color: MH.us,
                teamCtrl: _team2,
                pACtrl: _p3,
                pBCtrl: _p4,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 24),
              SetupServerPicker(
                labels: _pickerLabels,
                selectedId: _initialServerId,
                onChanged: (id) => setState(() => _initialServerId = id),
              ),
              const SizedBox(height: 24),
              SetupFormatSection(
                setsToWin: _setsToWin,
                setPoints: _setPoints,
                changeSideEvery: _changeSideEvery,
                onSetsToWinChanged: (n) => setState(() => _setsToWin = n),
                onSetPointsChanged: (n) => setState(() => _setPoints = n),
                onChangeSideDecrement: () =>
                    setState(() { if (_changeSideEvery > 1) _changeSideEvery--; }),
                onChangeSideIncrement: () =>
                    setState(() => _changeSideEvery++),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _videoUrl,
                style: MH.mono(size: 13),
                decoration: InputDecoration(
                  labelText: 'URL vidéo (optionnel)',
                  labelStyle: MH.mono(size: 12, color: MH.inkSoft),
                  prefixIcon: const Icon(
                    Icons.videocam_outlined,
                    color: MH.inkSoft,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: MH.sand,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MH.ball,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Commencer la partie',
                    style: MH.sans(
                      size: 16,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );

  void _start() {
    final url = _videoUrl.text.trim();
    ref.read(matchVideoUrlProvider.notifier).url = url.isEmpty ? null : url;
    ref.read(matchProvider.notifier).startMatch(
          teamE1Name: _label(_team1, 'Équipe 1'),
          teamE2Name: _label(_team2, 'Équipe 2'),
          p1: _label(_p1, 'Joueur 1'),
          p2: _label(_p2, 'Joueur 2'),
          p3: _label(_p3, 'Joueur 3'),
          p4: _label(_p4, 'Joueur 4'),
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
}
