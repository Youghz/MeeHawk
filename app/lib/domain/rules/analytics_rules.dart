import 'dart:math';


import 'package:app/domain/match_state.dart';

class AnalyticsRules {
  /// Exchanges = net crossings minus the service crossing (capped at 4).
  static int exchanges(PointRecord p) {
    final nc = p.netCrossings;
    if (nc <= 1) return 0;
    return min(nc - 1, 4);
  }

  static int maxStreak(List<PointRecord> pts, TeamSide team) {
    var best = 0;
    var cur = 0;
    for (final p in pts) {
      if (p.winner == team) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return best;
  }

  static String? subtype(String text) {
    final parts = text.split('·');
    if (parts.isEmpty) return null;
    final words = parts[0].trim().split(' ');
    if (words.length <= 1) return null;
    return words.sublist(1).join(' ').trim();
  }

  static String cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Maps raw court x ∈ [0, 1] to half-court x ∈ [0=net, 1=baseline].
  /// Uses physical position so side-change rounds are handled correctly.
  static double halfX(double x) {
    if (x >= 0.5) return ((x - 0.5) * 2).clamp(0.0, 1.0);
    return ((0.5 - x) * 2).clamp(0.0, 1.0);
  }
}
