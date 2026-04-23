/// Annotation and action validation rules for beach volleyball.
///
/// All constants and predicates are derived directly from the
/// **FIVB Official Beach Volleyball Rules 2021-2024**
/// (FIVB-BeachVolleyball_Rules2021_2024-FR-v01b.pdf, at the repository root).
///
/// Sections referenced: §9 (team touches), §13 (attack), §14 (block/contre).
/// No Flutter imports — pure Dart, fully testable.
class AnnotationRules {
  const AnnotationRules._();

  // ─── §9.1 — Team touches ──────────────────────────────────────────────────

  /// Maximum touches a team may use per possession to return the ball.
  /// Exceeding this limit is a "QUATRE TOUCHES" fault.
  static const int maxTeamTouches = 3;

  // ─── §14.4.1 — Block counts as first team touch ───────────────────────────

  /// A block touch counts as the team's **first** touch (§14.4.1).
  /// After blocking, the team retains [maxTeamTouches] − 1 further touches.
  static int touchesRemainingAfterBlock() => maxTeamTouches - 1;

  // ─── §9.1 — Four-touches fault ────────────────────────────────────────────

  /// Returns true when a team has exceeded [maxTeamTouches].
  /// The block counts as touch 1 (§14.4.1), so "three more after the block"
  /// is already a fault.
  static bool isFourTouchesFault(int teamTouches) =>
      teamTouches > maxTeamTouches;

  // ─── §14.5 + §14.3 + §14.6.1 — Block validity ────────────────────────────

  /// Blocking the opponent's **service** is unconditionally forbidden (§14.5).
  static const bool canBlockService = false;

  /// A block annotation is valid only when **both** conditions hold:
  ///
  /// 1. The ball did **not** arrive directly from a service — blocking a
  ///    service is forbidden (§14.5, §14.6.3).
  /// 2. The opposing team had made **at least one contact** in their current
  ///    possession, confirming they were in an attack phase — reaching into
  ///    the opponent's space before their attack is a fault (§14.3, §14.6.1).
  ///
  /// Parameters
  /// - [opponentContactsThisPossession]: contacts by the attacking team
  ///   before the ball reached the blocking team.
  /// - [wasDirectFromService]: true when the rally was opened by a service
  ///   with zero contacts on the receiving side before the "block".
  static bool isBlockValid({
    required int opponentContactsThisPossession,
    required bool wasDirectFromService,
  }) {
    if (wasDirectFromService) return false; // §14.5
    return opponentContactsThisPossession >= 1; // §14.3 / §14.6.1
  }

  // ─── §6.1.1.1 + §12 — Service ace ─────────────────────────────────────────

  /// A service is an **ace** when the receiving team makes zero contacts and
  /// the ball touches the floor of their court (§6.1.1.1).
  static bool isAce({required int receivingTeamContacts}) =>
      receivingTeamContacts == 0;

  // ─── §13.2.3 — Forbidden attack types ────────────────────────────────────

  /// An open-hand fingertip attack (tip / dink) with separated, non-rigid
  /// fingers is **forbidden** in beach volleyball (§13.2.3).
  /// This restriction does not exist in indoor volleyball.
  static const List<String> forbiddenAttackTypes = ['tip'];

  /// Returns true when [attackType] is forbidden under beach volleyball rules.
  static bool isAttackTypeForbidden(String attackType) =>
      forbiddenAttackTypes.contains(attackType.toLowerCase());

  // ─── §13.2.5 — Overhand set over the net ─────────────────────────────────

  /// A high overhand set sent over the net must travel perpendicular to the
  /// line of the setter's shoulders (§13.2.5). A set that is not
  /// perpendicular and is not directed to the setter's own partner is an
  /// attack fault. This restriction is specific to beach volleyball.
  static const bool overhandSetMustBePerpendicular = true;
}
