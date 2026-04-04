import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../theme.dart';
import '../widgets/serve_zone_picker.dart';

class ManualAnalysisScreen extends ConsumerStatefulWidget {
  const ManualAnalysisScreen({super.key});

  @override
  ConsumerState<ManualAnalysisScreen> createState() => _ManualAnalysisScreenState();
}

class _ManualAnalysisScreenState extends ConsumerState<ManualAnalysisScreen> {
  final _us1 = TextEditingController(text: 'Joueur 1');
  final _us2 = TextEditingController(text: 'Joueur 2');
  final _them1 = TextEditingController(text: 'Joueur 1');
  final _them2 = TextEditingController(text: 'Joueur 2');
  final _teamUs = TextEditingController(text: 'Equipe A');
  final _teamThem = TextEditingController(text: 'Equipe B');
  int _pointsPerSet = 21;
  bool _showDetails = false;

  @override
  void dispose() {
    _us1.dispose(); _us2.dispose();
    _them1.dispose(); _them2.dispose();
    _teamUs.dispose(); _teamThem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = ref.watch(matchProvider);
    if (ms.isSetup) return _buildSetup();
    if (ms.needsServerPick) return _buildServerPick(ms);
    return _buildMatch(ms);
  }

  // --- SETUP ---

  Widget _buildSetup() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_volleyball, size: 36, color: AppColors.accent),
            const SizedBox(height: 10),
            const Text('Nouvelle Partie', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _teamSection(AppColors.green, _teamUs, _us1, _us2),
            const SizedBox(height: 16),
            _teamSection(AppColors.red, _teamThem, _them1, _them2),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Points par set', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Commencer la partie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamSection(Color color, TextEditingController teamCtrl,
      TextEditingController p1, TextEditingController p2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: _field(teamCtrl, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const SizedBox(width: 12),
          Expanded(child: _field(p1)),
          const SizedBox(width: 8),
          Expanded(child: _field(p2)),
        ]),
      ],
    );
  }

  Widget _field(TextEditingController c, {TextStyle? style}) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      style: style ?? const TextStyle(fontSize: 13),
      onTap: () => c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length),
    );
  }

  void _startMatch() {
    ref.read(matchProvider.notifier).startMatch(
      teamUsName: _teamUs.text.trim().isEmpty ? 'Equipe A' : _teamUs.text.trim(),
      teamThemName: _teamThem.text.trim().isEmpty ? 'Equipe B' : _teamThem.text.trim(),
      playerA: _us1.text.trim().isEmpty ? 'Joueur 1' : _us1.text.trim(),
      playerB: _us2.text.trim().isEmpty ? 'Joueur 2' : _us2.text.trim(),
      opponentA: _them1.text.trim().isEmpty ? 'Joueur 1' : _them1.text.trim(),
      opponentB: _them2.text.trim().isEmpty ? 'Joueur 2' : _them2.text.trim(),
      pointsPerSet: _pointsPerSet,
    );
  }

  // --- SERVER PICK ---

  Widget _buildServerPick(MatchState ms) {
    final match = ms.match!;
    final isUs = match.servingTeam == 'us';
    final teamName = isUs ? match.teamUsName : match.teamThemName;
    final player1 = isUs ? match.playerA : match.opponentA;
    final player2 = isUs ? match.playerB : match.opponentB;
    final color = isUs ? AppColors.green : AppColors.red;

    return Center(
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_volleyball, size: 32, color: color),
            const SizedBox(height: 12),
            Text('Qui sert pour $teamName ?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _serverButton(player1, color)),
              const SizedBox(width: 12),
              Expanded(child: _serverButton(player2, color)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _serverButton(String name, Color color) {
    return GestureDetector(
      onTap: () => ref.read(matchProvider.notifier).pickServer(name),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ),
      ),
    );
  }

  // --- MATCH ---

  Widget _buildMatch(MatchState ms) {
    final match = ms.match!;
    final pending = ms.pending;
    final notifier = ref.read(matchProvider.notifier);
    final setDone = match.scoreUs >= match.pointsPerSet || match.scoreThem >= match.pointsPerSet;

    return Row(
      children: [
        // Timeline column — LEFT, no scroll
        SizedBox(
          width: 140,
          child: Container(
            color: AppColors.surface,
            child: _timeline(match),
          ),
        ),
        const VerticalDivider(width: 1, color: AppColors.border),
        // Main content — CENTER
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    // Score display
                    _scoreBlock(match, notifier),
                    const SizedBox(height: 24),
                    // Action buttons
                    if (setDone)
                      _setDoneBlock(match, notifier)
                    else ...[
                      Row(children: [
                        Expanded(child: _scoreButton(match.teamUsName, 'us', AppColors.green, notifier)),
                        const SizedBox(width: 12),
                        Expanded(child: _scoreButton(match.teamThemName, 'them', AppColors.red, notifier)),
                      ]),
                      const SizedBox(height: 12),
                      // Undo
                      GestureDetector(
                        onTap: match.points.isNotEmpty ? notifier.undo : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.undo, size: 16,
                                  color: match.points.isNotEmpty ? AppColors.textSecondary : AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text('Annuler le dernier point',
                                  style: TextStyle(fontSize: 12,
                                      color: match.points.isNotEmpty ? AppColors.textSecondary : AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Details toggle
                      GestureDetector(
                        onTap: () => setState(() => _showDetails = !_showDetails),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_showDetails ? Icons.expand_less : Icons.expand_more,
                                size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(_showDetails ? 'Masquer les détails' : 'Détails du point',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
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
    );
  }

  // --- Score block at top center ---

  Widget _scoreBlock(dynamic match, MatchNotifier notifier) {
    final weServe = match.servingTeam == 'us';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _teamColumn(
              teamName: match.teamUsName,
              p1: match.playerA,
              p2: match.playerB,
              score: match.scoreUs,
              color: AppColors.green,
              isServing: weServe,
              serverName: weServe ? match.servingPlayer : null,
              onTeamNameChanged: notifier.setTeamUsName,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('—', style: TextStyle(fontSize: 24, color: AppColors.textMuted)),
            ),
            _teamColumn(
              teamName: match.teamThemName,
              p1: match.opponentA,
              p2: match.opponentB,
              score: match.scoreThem,
              color: AppColors.red,
              isServing: !weServe,
              serverName: !weServe ? match.servingPlayer : null,
              onTeamNameChanged: notifier.setTeamThemName,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Set ${match.currentSet}',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _teamColumn({
    required String teamName,
    required String p1,
    required String p2,
    required int score,
    required Color color,
    required bool isServing,
    required String? serverName,
    required ValueChanged<String> onTeamNameChanged,
  }) {
    return Column(
      children: [
        // Ball
        Icon(Icons.sports_volleyball, size: 16,
            color: isServing ? AppColors.orange : Colors.transparent),
        const SizedBox(height: 2),
        // Team name
        GestureDetector(
          onTap: () => _editName(teamName, onTeamNameChanged),
          child: Text(teamName,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ),
        // Players
        Text('$p1 · $p2',
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.6))),
        const SizedBox(height: 4),
        // Score
        Text('$score',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        // Service badge
        SizedBox(
          height: 14,
          child: isServing
              ? Text(serverName != null ? 'SERVICE $serverName' : 'SERVICE',
                  style: const TextStyle(fontSize: 8, color: AppColors.orange, fontWeight: FontWeight.bold))
              : const Text('RECEPTION',
                  style: TextStyle(fontSize: 8, color: AppColors.accent, fontWeight: FontWeight.bold)),
        ),
      ],
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

  // --- Set done ---

  Widget _setDoneBlock(dynamic match, MatchNotifier notifier) {
    final winner = match.scoreUs >= match.pointsPerSet ? match.teamUsName : match.teamThemName;
    return Column(
      children: [
        Text('Set terminé !', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('$winner remporte le set',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: notifier.nextSet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Set suivant'),
        ),
      ],
    );
  }

  // --- Timeline (no scroll) ---

  Widget _timeline(dynamic match) {
    final points = match.points as List;
    final max = match.pointsPerSet as int;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const SizedBox(width: 18),
              Expanded(child: Text(match.teamUsName, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8, color: AppColors.green, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
              Expanded(child: Text(match.teamThemName, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8, color: AppColors.red, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 2),
          const Divider(height: 1, color: AppColors.border),
          // Rows — expand to fill, no scroll
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < max; i++)
                  Expanded(child: _timelineRow(i + 1, i < points.length ? points[i] : null)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(int num, dynamic record) {
    final isPlayed = record != null;
    final wonByUs = isPlayed && record.result == 'us';

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          SizedBox(width: 18,
            child: Text('$num', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9,
                    color: isPlayed ? AppColors.textSecondary : AppColors.textMuted.withValues(alpha: 0.3)))),
          Expanded(
            child: isPlayed && wonByUs
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(child: Text('${record.scoreUs}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.green))))
                : const SizedBox(),
          ),
          Container(width: 1, color: AppColors.border.withValues(alpha: 0.2)),
          Expanded(
            child: isPlayed && !wonByUs
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(child: Text('${record.scoreThem}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.red))))
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _scoreButton(String teamName, String result, Color color, MatchNotifier notifier) {
    return GestureDetector(
      onTap: () => notifier.scorePoint(result),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('Point\n$teamName', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, height: 1.3)),
        ),
      ),
    );
  }

  Widget _detailRow(String label, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: children[i]),
          ],
        ]),
      ],
    );
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
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: isSelected ? activeColor : AppColors.textPrimary)),
        ),
      ),
    );
  }
}
