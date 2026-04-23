/// Pure inference of attack type from normalized ball impact positions.
///
/// Positions are in the *outer court frame* (terrain + out-of-bounds margin)
/// normalized to 0..1. The net sits at x = 0.5.
///
/// Classification uses two axes:
/// - Depth (|to.x - 0.5|): how deep in the target half the ball landed.
/// - Laterality: whether the landing y stays on the attacker's side of the
///   court-length (same y-half) or crosses to the opposite side.
class AttackInference {
  const AttackInference._();

  /// Threshold (in outer-frame units) below which the landing is considered
  /// "short" (front court). Tuneable — default targets roughly the 3-metre
  /// line on a standard beach court given our render ratio.
  static const double shortDepthThreshold = 0.22;

  /// Classify the attack given the attacker's position (prev impact) and
  /// the ball landing position.
  static String classify({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    double shortThreshold = shortDepthThreshold,
  }) {
    final depth = (toX - 0.5).abs();
    final isShort = depth < shortThreshold;
    final lateralSame = (fromY - 0.5) * (toY - 0.5) > 0;
    if (isShort && lateralSame) return 'Amorti';
    if (isShort && !lateralSame) return 'Coupé';
    if (!isShort && lateralSame) return 'Ligne';
    return 'Diagonale';
  }
}
