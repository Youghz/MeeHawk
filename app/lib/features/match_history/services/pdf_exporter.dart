import 'dart:math';
import 'dart:typed_data';

import 'package:app/core/rules/analytics_rules.dart';
import 'package:app/features/match/domain/match_state.dart';
import 'package:app/features/match_history/screens/analytics/analytics_input.dart';
import 'package:app/features/match_history/screens/analytics/widgets/advice.dart';
import 'package:app/features/match_history/screens/analytics/widgets/analytics_court.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> generateAnalyticsPdf(AnalyticsInput input) async {
  final pdf =
      pw.Document(title: 'Analyse — ${input.team.name}', author: 'CrabCoach');

  final isE1 = input.selectedTeam == TeamSide.e1;
  final teamPdfColor =
      isE1 ? PdfColor.fromHex('#4B8EFF') : PdfColor.fromHex('#FFB020');

  final pts = input.pts;
  final pairs = input.ptsWithServer;

  // Summary
  final myWins = pts.where((p) => p.winner == input.selectedTeam).length;
  final myServes = pairs.where((p) => p.server == input.selectedTeam).toList();
  final myRecv = pairs.where((p) => p.server != input.selectedTeam).toList();
  final myServeWins =
      myServes.where((p) => p.pt.winner == input.selectedTeam).length;
  final myRecvWins =
      myRecv.where((p) => p.pt.winner == input.selectedTeam).length;
  final streak = AnalyticsRules.maxStreak(pts, input.selectedTeam);
  var maxLead = 0;
  for (final p in pts) {
    final lead =
        p.scoreOf(input.selectedTeam) - p.scoreOf(input.selectedTeam.other);
    if (lead > maxLead) maxLead = lead;
  }
  final first5 = pts.take(min(5, pts.length)).toList();
  final f5Wins = first5.where((p) => p.winner == input.selectedTeam).length;
  final pressurePts = pts
      .where((p) =>
          p.scoreOf(input.selectedTeam) >= 15 ||
          p.scoreOf(input.selectedTeam.other) >= 15)
      .toList();
  final pressWins =
      pressurePts.where((p) => p.winner == input.selectedTeam).length;
  final decPts = pts
      .where((p) =>
          p.scoreOf(input.selectedTeam) >= 18 ||
          p.scoreOf(input.selectedTeam.other) >= 18)
      .toList();
  final decWins = decPts.where((p) => p.winner == input.selectedTeam).length;

  // Rally data
  final rallyData = <int, ({int wins, int total})>{};
  for (final pt in pts) {
    final ex = AnalyticsRules.exchanges(pt);
    final won = pt.winner == input.selectedTeam;
    final prev = rallyData[ex] ?? (wins: 0, total: 0);
    rallyData[ex] = (wins: prev.wins + (won ? 1 : 0), total: prev.total + 1);
  }
  final rallySorted = rallyData.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  // Service dots
  final serviceDots = <AnalyticsDot>[];
  for (final (:pt, :server, :serverId) in pairs) {
    if (server != input.selectedTeam) continue;
    if (input.filterPlayerId != null && serverId != input.filterPlayerId) {
      continue;
    }
    BallImpact? landing;
    var seenServer = false;
    for (final imp in pt.impacts) {
      if (imp.isServerPosition) {
        seenServer = true;
        continue;
      }
      if (seenServer) {
        landing = imp;
        break;
      }
    }
    if (landing == null) continue;
    final crossings = pt.netCrossings;
    final AnalyticsDotKind sKind;
    if (crossings == 0) {
      sKind = AnalyticsDotKind.fault;
    } else if (crossings == 1) {
      sKind = AnalyticsDotKind.ace;
    } else {
      sKind = pt.winner == input.selectedTeam
          ? AnalyticsDotKind.won
          : AnalyticsDotKind.lost;
    }
    serviceDots.add(AnalyticsDot(
        x: crossings == 0 ? 0.0 : AnalyticsRules.halfX(landing.x),
        y: landing.y,
        kind: sKind));
  }

  // Attack dots
  final attackDots = <AnalyticsDot>[];
  final opponent = input.selectedTeam.other;
  for (final p in input.ptsForPlayer) {
    BallImpact? attackLanding;
    for (final imp in p.impacts.reversed) {
      if (imp.isServerPosition) continue;
      if (imp.teamSide == opponent) {
        attackLanding = imp;
        break;
      }
    }
    if (attackLanding == null) continue;
    attackDots.add(AnalyticsDot(
      x: AnalyticsRules.halfX(attackLanding.x),
      y: attackLanding.y,
      kind: !attackLanding.isOutside && p.winner == input.selectedTeam
          ? AnalyticsDotKind.won
          : AnalyticsDotKind.lost,
    ));
  }

  // Endings
  final endings = <String, ({int wins, int total})>{};
  final attackSubs = <String, ({int wins, int total})>{};
  for (final p in input.ptsForPlayer) {
    Annotation? last;
    for (final a in p.annotations.reversed) {
      if (a.team == input.selectedTeam) {
        last = a;
        break;
      }
    }
    if (last == null) continue;
    final won = p.winner == input.selectedTeam;
    final prev = endings[last.type] ?? (wins: 0, total: 0);
    endings[last.type] =
        (wins: prev.wins + (won ? 1 : 0), total: prev.total + 1);
    if (last.type == 'attack') {
      final sub = AnalyticsRules.subtype(last.text);
      if (sub != null && sub.isNotEmpty) {
        final prevSub = attackSubs[sub] ?? (wins: 0, total: 0);
        attackSubs[sub] =
            (wins: prevSub.wins + (won ? 1 : 0), total: prevSub.total + 1);
      }
    }
  }
  final grandTotal = endings.isEmpty
      ? 1
      : endings.values.map((v) => v.total).reduce((a, b) => a + b);
  final endingsSorted = endings.entries.toList()
    ..sort((a, b) => b.value.total.compareTo(a.value.total));
  final subsSorted = attackSubs.entries.toList()
    ..sort((a, b) => b.value.total.compareTo(a.value.total));

  const typeLabels = {
    'attack': 'Attaque',
    'block': 'Bloc',
    'fault': 'Faute adverse',
    'service': 'Ace / direct',
  };
  const rallyLabels = {
    0: 'Direct',
    1: '1 échange',
    2: '2 échanges',
    3: '3 échanges',
    4: '4+ échanges',
  };

  final advice = buildAdvice(input);

  final filterParts = <String>[];
  if (input.filterSetNumber != null) {
    filterParts.add('Set ${input.filterSetNumber}');
  }
  if (input.filterPlayerId != null) {
    final p = input.team.players.firstWhere(
        (p) => p.id == input.filterPlayerId,
        orElse: () => const Player(id: '', name: ''));
    if (p.name.isNotEmpty) filterParts.add(p.name);
  }
  final filterDesc = filterParts.join(' · ');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      build: (context) {
        return [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CRABCOACH',
                      style: const pw.TextStyle(
                          fontSize: 7,
                          letterSpacing: 2,
                          color: PdfColors.grey500)),
                  pw.SizedBox(height: 3),
                  pw.Text(input.team.name,
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: teamPdfColor)),
                  pw.Text('vs ${input.otherTeamName}',
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(DateTime.now().toIso8601String().substring(0, 10),
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey500)),
                  if (filterDesc.isNotEmpty)
                    pw.Text(filterDesc,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 14),

          _pdfSectionTitle('RÉSUMÉ'),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _pdfStatBox('Points', myWins, pts.length, teamPdfColor),
              pw.SizedBox(width: 12),
              _pdfStatBox(
                  'Service', myServeWins, myServes.length, teamPdfColor),
              pw.SizedBox(width: 12),
              _pdfStatBox(
                  'Réception', myRecvWins, myRecv.length, PdfColors.grey500),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _pdfKeyVal('Série max', '$streak pts'),
            pw.SizedBox(width: 24),
            _pdfKeyVal('Avance max', '+$maxLead pts'),
          ]),
          if (first5.isNotEmpty ||
              pressurePts.isNotEmpty ||
              decPts.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Row(children: [
              if (first5.isNotEmpty)
                _pdfPressCell('5 premiers', f5Wins, first5.length),
              if (pressurePts.isNotEmpty) ...[
                pw.SizedBox(width: 16),
                _pdfPressCell('Points ≥ 15', pressWins, pressurePts.length),
              ],
              if (decPts.isNotEmpty) ...[
                pw.SizedBox(width: 16),
                _pdfPressCell('Points ≥ 18', decWins, decPts.length),
              ],
            ]),
          ],
          pw.SizedBox(height: 18),

          _pdfSectionTitle('ÉCHANGES'),
          pw.SizedBox(height: 8),
          for (final e in rallySorted) ...[
            _pdfBar(
              rallyLabels[e.key] ?? '${e.key}+ échanges',
              e.value.total > 0 ? e.value.wins / e.value.total : 0,
              null,
              '${e.value.wins}/${e.value.total}  ${(e.value.total > 0 ? e.value.wins / e.value.total * 100 : 0).round()}%',
              teamPdfColor,
            ),
            pw.SizedBox(height: 5),
          ],
          pw.SizedBox(height: 4),
          pw.Row(children: [
            _pdfKeyVal(
                'Touches moy. (nous)', input.avgTouchesUs.toStringAsFixed(1)),
            pw.SizedBox(width: 24),
            _pdfKeyVal(
                'Touches moy. (eux)', input.avgTouchesThem.toStringAsFixed(1)),
          ]),
          pw.SizedBox(height: 18),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSectionTitle('ZONES DE SERVICE'),
                    pw.SizedBox(height: 8),
                    if (serviceDots.isNotEmpty)
                      _pdfHalfCourt(serviceDots)
                    else
                      pw.Text('Aucune donnée',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 6),
                    pw.Text('● Point gagné  ○ Point perdu  ← Filet',
                        style: const pw.TextStyle(
                            fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSectionTitle("ZONES D'ATTAQUE"),
                    pw.SizedBox(height: 8),
                    if (attackDots.isNotEmpty)
                      _pdfHalfCourt(attackDots)
                    else
                      pw.Text('Aucune donnée',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 6),
                    pw.Text('● Point gagné  ○ Faute / repoussé  ← Filet',
                        style: const pw.TextStyle(
                            fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          if (endingsSorted.isNotEmpty) ...[
            _pdfSectionTitle('ATTAQUE & FIN DE RALLYE'),
            pw.SizedBox(height: 8),
            for (final e in endingsSorted) ...[
              _pdfBar(
                typeLabels[e.key] ?? e.key,
                e.value.total / grandTotal,
                e.value.total > 0 ? e.value.wins / e.value.total : 0,
                '${e.value.wins}/${e.value.total}  ${(e.value.total / grandTotal * 100).round()}%',
                PdfColors.grey700,
              ),
              pw.SizedBox(height: 4),
              if (e.key == 'attack')
                for (final sub in subsSorted) ...[
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 16),
                    child: _pdfBar(
                      AnalyticsRules.cap(sub.key),
                      sub.value.total / grandTotal,
                      sub.value.total > 0
                          ? sub.value.wins / sub.value.total
                          : 0,
                      '${sub.value.wins}/${sub.value.total}  ${(sub.value.total / grandTotal * 100).round()}%',
                      PdfColors.grey500,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                ],
            ],
            pw.SizedBox(height: 18),
          ],

          if (advice.isNotEmpty) ...[
            _pdfSectionTitle('CONSEILS'),
            pw.SizedBox(height: 8),
            for (final tip in advice) ...[
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    margin: const pw.EdgeInsets.only(top: 3, right: 8),
                    decoration: pw.BoxDecoration(
                      color: tip.positive
                          ? PdfColor.fromHex('#22C55E')
                          : PdfColor.fromHex('#F59E0B'),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(tip.text,
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                            lineSpacing: 3)),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
          ],
        ];
      },
    ),
  );

  return pdf.save();
}

pw.Widget _pdfSectionTitle(String title) => pw.Text(
      title,
      style: pw.TextStyle(
          fontSize: 7,
          letterSpacing: 1.5,
          color: PdfColors.grey500,
          fontWeight: pw.FontWeight.bold),
    );

pw.Widget _pdfStatBox(
    String label, int wins, int total, PdfColor color) {
  final rate = total > 0 ? wins / total : 0.0;
  return pw.Container(
    width: 88,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: color),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      children: [
        pw.Text('${(rate * 100).round()}%',
            style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: color)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style:
                const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text('$wins/$total',
            style:
                const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
      ],
    ),
  );
}

pw.Widget _pdfKeyVal(String label, String value) => pw.Row(children: [
      pw.Text('$label : ',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.Text(value,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ]);

pw.Widget _pdfPressCell(String label, int wins, int total) {
  final rate = total > 0 ? wins / total : 0.0;
  final color = rate >= 0.6
      ? PdfColor.fromHex('#22C55E')
      : rate >= 0.4
          ? PdfColor.fromHex('#F59E0B')
          : PdfColor.fromHex('#EF4444');
  return pw.Row(children: [
    pw.Text('$label : ',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    pw.Text('$wins/$total',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(width: 4),
    pw.Container(
        width: 6,
        height: 6,
        decoration:
            pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
  ]);
}

pw.Widget _pdfBar(String label, double ratio, double? winRatio, String value,
    PdfColor color) {
  const barW = 180.0;
  const barH = 7.0;
  return pw.Row(
    children: [
      pw.SizedBox(
        width: 108,
        child: pw.Text(label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            maxLines: 1),
      ),
      pw.SizedBox(width: 8),
      pw.CustomPaint(
        size: const PdfPoint(barW, barH),
        painter: (canvas, size) {
          final fillW = size.x * ratio.clamp(0.0, 1.0);
          final winW =
              winRatio != null ? fillW * winRatio.clamp(0.0, 1.0) : fillW;
          canvas
            ..setFillColor(PdfColors.grey200)
            ..drawRect(0, 0, size.x, size.y)
            ..fillPath();
          if (fillW > 0 && winRatio != null) {
            canvas
              ..setFillColor(
                  PdfColor(color.red, color.green, color.blue, 0.25))
              ..drawRect(0, 0, fillW, size.y)
              ..fillPath();
          }
          if (winW > 0) {
            canvas
              ..setFillColor(color)
              ..drawRect(0, 0, winW, size.y)
              ..fillPath();
          }
        },
      ),
      pw.SizedBox(width: 8),
      pw.Text(value,
          style:
              const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
    ],
  );
}

pw.Widget _pdfHalfCourt(List<AnalyticsDot> dots) {
  const w = 230.0;
  const m = 14.0;
  const courtW = w - m * 2;
  const courtH = courtW * 0.65;
  const h = courtH + m * 2;

  return pw.CustomPaint(
    size: const PdfPoint(w, h),
    painter: (canvas, size) {
      canvas
        ..setFillColor(PdfColors.grey100)
        ..drawRect(0, 0, size.x, size.y)
        ..fillPath()
        ..setFillColor(PdfColors.amber50)
        ..drawRect(m, m, courtW, courtH)
        ..fillPath()
        ..setStrokeColor(PdfColors.grey400)
        ..setLineWidth(0.5)
        ..drawRect(m, m, courtW, courtH)
        ..strokePath()
        ..setStrokeColor(PdfColors.grey700)
        ..setLineWidth(2.5)
        ..moveTo(m, m)
        ..lineTo(m, m + courtH)
        ..strokePath();

      for (final dot in dots) {
        final x = m + dot.x * courtW;
        final y = m + dot.y * courtH;
        final pdfColor = switch (dot.kind) {
          AnalyticsDotKind.ace => PdfColor.fromHex('#86EFAC'),
          AnalyticsDotKind.won => PdfColor.fromHex('#22C55E'),
          AnalyticsDotKind.fault => PdfColor.fromHex('#FCA5A5'),
          AnalyticsDotKind.lost => PdfColor.fromHex('#EF4444'),
        };
        canvas
          ..setFillColor(pdfColor)
          ..drawEllipse(x, y, 3.5, 3.5)
          ..fillPath();
      }
    },
  );
}
