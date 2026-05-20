# Architecture Review

**Date**: 2026-05-20
**Scope**: Full codebase — Flutter app (`app/lib/`) post-review R1–R13

## Summary

Les reviews précédentes ont résolu les dettes structurelles majeures (décomposition, dépendances circulaires, sealed classes, mixin scoring). La dette résiduelle est concentrée sur deux axes : `court.dart` (734 lignes) qui mélange widget, gestion des gestes et helpers purs ; et une duplication de `_formatDate` entre deux écrans de `match_history`. Deux candidats au découpage de taille moyenne (`history_screen.dart`, `match_setup_screen.dart`) complètent le tableau.

## Dependency matrix

| Source | → Cible | Fichiers concernés | Statut |
|---|---|---|---|
| `core/widgets/court.dart` | → `match/widgets/` | `court_canvas`, `fault_overlay`, `impact_marker`, `pick_server_overlay`, `player_dot`, `player_picker_overlay`, `trajectory_painter` | ✅ intentionnel (R4) |
| `core/widgets/court.dart` | → `match/domain/` | `match_state` | ✅ type domain public |
| `core/widgets/court.dart` | → `match/providers/` | `match_provider` | ✅ provider public |
| `home/widgets/ongoing_card.dart` | → `match/`, `match_history/` | `match_screen`, `match_provider`, `archive_storage_provider` | ✅ hub navigation |
| `match_history/*` | → `match/domain/` | `match_state` | ✅ type domain public |
| `match_history/*` | → `match/providers/` | `match_provider`, `match_notifier_base` | ✅ provider public |
| `home_screen.dart` | → toutes features | écrans d'entrée + providers | ✅ hub orchestration |

Aucun cycle A → B + B → A détecté.

## Strengths

- **`_MatchPointLogic` mixin** : scoring isolé, `MatchNotifier` limité à son API publique (R11).
- **`core/rules/analytics_rules.dart`** : 5 méthodes pures portées, MCP synchronisé (R9).
- **Sealed classes `MatchPopup`** : complètes, exhaustivité compiler-vérifiée (R3).
- **`home/widgets/`** : 5 widgets autonomes, coordinateur 98 lignes (R12).
- **`core/widgets/`** : `timeline`, `top_score`, `replay_panel` partagés correctement (R8).
- **Zéro import Flutter dans `core/rules/`** : invariant tenu.
- **Zéro cycle inter-features** : invariant tenu.

## Recommendations

### High Impact

- [x] **R15 — Extraire les gesture handlers de `_CourtState` dans un mixin `_CourtGestures`**

  `court.dart` fait 734 lignes. `_CourtState` contient à la fois `build()` (~80 lignes) et ~10 handlers de gestes (`_onInnerTapDown`, `_handleSingleTap`, `_handleBlock`, `_onInsideSwipe`, `_onInsideLongPress`, `_onOutsideTap`, `_onOutsideLongPress`, `_handleOutBall`, `_handleTouch`, `_isServerZone`, `_impactIndex`, `_visitIndex`, `_maybeDismissReplay`) soit ~330 lignes de logique.

  Pattern R11 : extraire dans `mixin _CourtGestures on ConsumerState<Court>` déclaré dans le même fichier. `_CourtState` se réduit à `build()` + initialisation de l'animation (~120 lignes). Les champs d'état gesture (`_swipeDragStart`, `_lastTapTime`, `_lastTapPos`, `_tapHandled`) migrent dans le mixin.

  Fichier : `app/lib/core/widgets/court.dart`

- [x] **R16 — Promouvoir `_lastPlayerOnSide` + `_lastPlayerWhoTouched` dans `touch_attribution.dart`**

  Deux fonctions top-level privées dans `court.dart` (lignes 39–56) opèrent uniquement sur `List<BallImpact>` sans dépendance Flutter. Même famille que `TouchAttribution.inferNextPlayer`. Les déplacer comme méthodes statiques sur `TouchAttribution`.

  `_shouldShowPlayerPicker` (ligne 27–36) reste dans `court.dart` — elle prend une décision d'affichage UI (montrer ou non le picker), même si elle opère sur du domaine.

  Impact MCP : `touch_attribution.dart` est dans le périmètre de synchronisation — porter les deux méthodes dans `mcp/rules.py` (classe `TouchAttribution`).

  Fichiers :
  - `app/lib/core/widgets/court.dart` (supprimer lignes 39–56)
  - `app/lib/core/rules/touch_attribution.dart` (ajouter 2 méthodes statiques)
  - `mcp/rules.py` (ajouter dans classe `TouchAttribution`)

### Medium Impact

- [ ] **R17 — Dédupliquer `_formatDate`**

  `_formatDate(DateTime dt)` est définie identiquement dans `history_screen.dart:366` et `match_replay_screen.dart:156`. Déplacer dans `app/lib/features/match_history/domain/date_format.dart` comme fonction top-level `formatMatchDate(DateTime dt)`. Les deux écrans importent ce fichier.

  Pas de synchronisation MCP nécessaire (affichage pur).

  Fichiers :
  - `app/lib/features/match_history/domain/date_format.dart` (nouveau, ~15 lignes)
  - `app/lib/features/match_history/screens/history_screen.dart`
  - `app/lib/features/match_history/screens/match_replay_screen.dart`

- [ ] **R18 — Découper `history_screen.dart` (377 lignes, 4 classes privées)**

  `_SearchBar`, `_EmptyState`, `_MatchCard`, `_TeamBlock` sont autosuffisantes. Pattern identique à R12. Les déplacer dans `match_history/widgets/`. `HistoryScreen` devient coordinateur de ~80 lignes.

  `_formatDate` sera déjà déplacé par R17 — appliquer R17 d'abord.

  Fichier : `app/lib/features/match_history/screens/history_screen.dart`

### Low Impact

- [ ] **R19 — Découper `match_setup_screen.dart` (424 lignes)**

  `_MatchSetupScreenState` contient des méthodes builder privées (`_teamSection`, `_serverPicker`, `_serverChip`, `_formatSection`) qui pourraient être des `StatelessWidget` dans `match_setup/widgets/`. Ces méthodes ne dépendent pas directement du state — elles reçoivent des controllers et callbacks en paramètre.

  Découpage proposé :
  - `team_section.dart` — reçoit `Color`, `TextEditingController × 3`
  - `server_picker.dart` — reçoit la grille de chips + callback
  - `format_section.dart` — reçoit les valeurs et callbacks de mutation

  Réduit `_MatchSetupScreenState` à ~150 lignes de coordination pure.

  Fichier : `app/lib/features/match_setup/match_setup_screen.dart`

- [ ] **R20 — Examiner `pdf_exporter.dart` (563 lignes)**

  Seul fichier de service PDF, 563 lignes avec la génération de toutes les sections (sommaire, zones service/réception, attaques, notes). La logique de layout PDF et la logique de calcul analytique sont mélangées. Les fonctions de calcul ont déjà été extraites vers `AnalyticsRules` (R9), mais il reste des boucles de calcul inline.

  Avant de découper, vérifier si les sections sont réellement indépendantes ou si elles partagent des helpers de layout PDF internes. Si indépendantes : extraire `_buildSummarySection`, `_buildServiceZones`, etc. dans `match_history/services/pdf_sections/`. Si couplées : documenter comme acceptable et ne pas découper.

  Fichier : `app/lib/features/match_history/services/pdf_exporter.dart`
