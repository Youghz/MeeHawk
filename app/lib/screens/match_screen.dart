import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../theme.dart';
import '../widgets/serve_zone_picker.dart';
import 'home_screen.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  bool _showDetails = false;
  bool _showTimeline = true;

  @override
  Widget build(BuildContext context) {
    final ms = ref.watch(matchProvider);
    if (ms.needsServerPick) return _serverPick(ms);
    if (ms.match == null) return const SizedBox();
    return _match(ms);
  }

  // --- SERVER PICK ---

  Widget _serverPick(MatchState ms) {
    final match = ms.match!;
    final isUs = match.servingTeam == 'us';
    final teamName = isUs ? match.teamUsName : match.teamThemName;
    final p1 = isUs ? match.playerA : match.opponentA;
    final p2 = isUs ? match.playerB : match.opponentB;
    final color = isUs ? AppColors.green : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          width: 340, padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_volleyball, size: 32, color: color),
              const SizedBox(height: 12),
              Text('Qui sert pour\n$teamName ?',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _pickButton(p1, color)),
                const SizedBox(width: 12),
                Expanded(child: _pickButton(p2, color)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickButton(String name, Color color) {
    return GestureDetector(
      onTap: () => ref.read(matchProvider.notifier).pickServer(name),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(name,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color))),
      ),
    );
  }

  // --- MATCH ---

  Widget _match(MatchState ms) {
    final match = ms.match!;
    final pending = ms.pending;
    final notifier = ref.read(matchProvider.notifier);
    final setDone = match.scoreUs >= match.pointsPerSet || match.scoreThem >= match.pointsPerSet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
          onPressed: () => _confirmExit(notifier),
        ),
        title: Text('Set ${match.currentSet}',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        centerTitle: true,
        actions: [
          if (match.points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo, color: AppColors.textSecondary, size: 20),
              tooltip: 'Annuler',
              onPressed: notifier.undo,
            ),
        ],
      ),
      body: Row(
        children: [
          // Timeline
          if (_showTimeline)
            SizedBox(
              width: 130,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _showTimeline = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.chevron_left, size: 14, color: AppColors.textMuted),
                          Text('Timeline', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ]),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(child: _timeline(match)),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _showTimeline = true),
              child: Container(
                width: 20, color: AppColors.surface,
                child: const Center(child: Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted)),
              ),
            ),
          // Main
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      _scoreBlock(match, notifier),
                      const SizedBox(height: 28),
                      if (setDone)
                        _setDone(match, notifier)
                      else ...[
                        Row(children: [
                          Expanded(flex: 3, child: _actionButton(
                              'Point\n${match.teamUsName}', AppColors.green, () => notifier.scorePoint('us'))),
                          const SizedBox(width: 10),
                          Expanded(flex: 2, child: _actionButton(
                              'Annuler', AppColors.textMuted,
                              match.points.isNotEmpty ? notifier.undo : null,
                              icon: Icons.undo)),
                          const SizedBox(width: 10),
                          Expanded(flex: 3, child: _actionButton(
                              'Point\n${match.teamThemName}', AppColors.red, () => notifier.scorePoint('them'))),
                        ]),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => setState(() => _showDetails = !_showDetails),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_showDetails ? Icons.expand_less : Icons.expand_more,
                                size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(_showDetails ? 'Masquer les détails' : 'Détails du point',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ]),
                        ),
                        if (_showDetails) ...[
                          const SizedBox(height: 12),
                          ServeZonePicker(selectedZone: pending.serveZone, onZoneSelected: notifier.setServeZone),
                          const SizedBox(height: 12),
                          _detailRow('RECEPTION', [
                            _toggle(match.playerA, 'player_a', pending.receiver, notifier.setReceiver, AppColors.accent),
                            _toggle(match.playerB, 'player_b', pending.receiver, notifier.setReceiver, AppColors.purple),
                          ]),
                          const SizedBox(height: 10),
                          _detailRow('ATTAQUE', [
                            _toggle('Cut', 'cut', pending.attackType, notifier.setAttackType, AppColors.orange),
                            _toggle('Line', 'line', pending.attackType, notifier.setAttackType, AppColors.orange),
                          ]),
                          const SizedBox(height: 10),
                          _detailRow('BLOC', [
                            _toggle('Diag', 'diag', pending.blockDirection, notifier.setBlockDirection, AppColors.textSecondary),
                            _toggle('Line', 'line', pending.blockDirection, notifier.setBlockDirection, AppColors.textSecondary),
                          ]),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Score block ---

  Widget _scoreBlock(dynamic match, MatchNotifier notifier) {
    final weServe = match.servingTeam == 'us';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 180, child: _teamCol(
          teamName: match.teamUsName, p1: match.playerA, p2: match.playerB,
          score: match.scoreUs, color: AppColors.green, isServing: weServe,
          serverName: weServe ? match.servingPlayer : null,
          onTeamNameChanged: notifier.setTeamUsName,
        )),
        const Padding(
          padding: EdgeInsets.only(top: 32),
          child: Text('—', style: TextStyle(fontSize: 28, color: AppColors.textMuted)),
        ),
        SizedBox(width: 180, child: _teamCol(
          teamName: match.teamThemName, p1: match.opponentA, p2: match.opponentB,
          score: match.scoreThem, color: AppColors.red, isServing: !weServe,
          serverName: !weServe ? match.servingPlayer : null,
          onTeamNameChanged: notifier.setTeamThemName,
        )),
      ],
    );
  }

  Widget _teamCol({
    required String teamName, required String p1, required String p2,
    required int score, required Color color, required bool isServing,
    required String? serverName, required ValueChanged<String> onTeamNameChanged,
  }) {
    return Column(children: [
      Icon(Icons.sports_volleyball, size: 18,
          color: isServing ? AppColors.orange : Colors.transparent),
      const SizedBox(height: 2),
      GestureDetector(
        onTap: () => _editName(teamName, onTeamNameChanged),
        child: Text(teamName, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 2),
      Text('$p1  ·  $p2', style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
      const SizedBox(height: 6),
      Text('$score', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isServing ? AppColors.orange.withValues(alpha: 0.2) : AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isServing ? (serverName != null ? 'SERVICE $serverName' : 'SERVICE') : 'RECEPTION',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
              color: isServing ? AppColors.orange : AppColors.accent),
        ),
      ),
    ]);
  }

  // --- Buttons ---

  Widget _actionButton(String label, Color color, VoidCallback? onTap, {IconData? icon}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : AppColors.surfaceLight,
          border: Border.all(color: enabled ? color : AppColors.border, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: icon != null
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 20, color: enabled ? color : AppColors.textMuted),
                  const SizedBox(height: 4),
                  Text(label, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: enabled ? color : AppColors.textMuted)),
                ])
              : Text(label, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, height: 1.3)),
        ),
      ),
    );
  }

  // --- Set done ---

  Widget _setDone(dynamic match, MatchNotifier notifier) {
    final winner = match.scoreUs >= match.pointsPerSet ? match.teamUsName : match.teamThemName;
    return Column(children: [
      Text('Set terminé !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('$winner remporte le set', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: notifier.nextSet,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text('Set suivant'),
      ),
    ]);
  }

  // --- Timeline ---

  Widget _timeline(dynamic match) {
    final points = match.points as List;
    final max = match.pointsPerSet as int;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(children: [
        Row(children: [
          const SizedBox(width: 18),
          Expanded(child: Text(match.teamUsName, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: AppColors.green, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
          Expanded(child: Text(match.teamThemName, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: AppColors.red, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 2),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Column(children: [
            for (int i = 0; i < max; i++)
              Expanded(child: _timelineRow(i + 1, i < points.length ? points[i] : null)),
          ]),
        ),
      ]),
    );
  }

  Widget _timelineRow(int num, dynamic record) {
    final isPlayed = record != null;
    final wonByUs = isPlayed && record.result == 'us';
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.2)))),
      child: Row(children: [
        SizedBox(width: 18, child: Text('$num', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: isPlayed ? AppColors.textSecondary : AppColors.textMuted.withValues(alpha: 0.3)))),
        Expanded(child: isPlayed && wonByUs
            ? Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                child: Center(child: Text('${record.scoreUs}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.green))))
            : const SizedBox()),
        Container(width: 1, color: AppColors.border.withValues(alpha: 0.2)),
        Expanded(child: isPlayed && !wonByUs
            ? Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                child: Center(child: Text('${record.scoreThem}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.red))))
            : const SizedBox()),
      ]),
    );
  }

  // --- Helpers ---

  void _confirmExit(MatchNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Quitter le match ?', style: TextStyle(fontSize: 16)),
        content: const Text('Les données du match seront perdues.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              notifier.endMatch();
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
              );
            },
            child: const Text('Quitter', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _editName(String current, ValueChanged<String> onChanged) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Modifier', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller, autofocus: true,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          onSubmitted: (v) { if (v.trim().isNotEmpty) onChanged(v.trim()); Navigator.of(ctx).pop(); },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          TextButton(onPressed: () { final v = controller.text.trim(); if (v.isNotEmpty) onChanged(v); Navigator.of(ctx).pop(); }, child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Row(children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ]),
    ]);
  }

  Widget _toggle(String label, String value, String? selected, ValueChanged<String> onTap, Color activeColor) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : AppColors.surfaceLight,
          border: Border.all(color: isSelected ? activeColor : AppColors.border, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: isSelected ? activeColor : AppColors.textPrimary))),
      ),
    );
  }
}
