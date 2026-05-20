# Architecture Review

**Date**: 2026-05-20
**Scope**: Full codebase — Flutter app (`app/lib/`) post-review R1–R7

## Summary

La dette résiduelle après la première review se concentre sur un angle non traité complètement en R4 : `match_replay_screen.dart` importe encore 4 widgets de `match/widgets/` alors que trois d'entre eux sont partagés avec `match_screen.dart` et appartiennent donc à `core/widgets/`. On trouve aussi des méthodes analytiques pures mal localisées, deux gros fichiers widgets candidates au découpage, et deux micro-fichiers à fusionner.

## Dependency matrix

| Source | → Feature | Fichiers concernés | Statut |
|---|---|---|---|
| `match_history/screens/match_replay_screen.dart` | → `match/widgets/` | `timeline`, `top_score`, `replay_panel`, `match_notes` | ❌ violation |
| `core/widgets/court.dart` | → `match/widgets/` | `court_canvas`, `court_popups`, `impact_marker`, `player_dot`, `trajectory_painter` | ✅ intentionnel (R4) |
| `match_history/*` | → `match/domain/` | `match_state.dart` | ✅ type domain public |
| `match_history/*` | → `match/providers/` | `match_provider.dart`, `match_notifier_base.dart` | ✅ provider public |
| `home_screen.dart` | → toutes features | écrans d'entrée + types domain | ✅ hub orchestration |

Aucun cycle A → B + B → A détecté.

## Strengths

- **Zéro import Flutter dans `core/rules/`** : invariant tenu.
- **Sealed classes `MatchPopup`** : 5 sous-classes, champs non-nullables, exhaustivité compiler-vérifiée (R3).
- **`MatchNotifierBase`** : no-ops documentés, aucune dérive détectée.
- **Providers propres** : 4 providers, responsabilités distinctes, aucune redondance.
- **`app.dart` source unique** de persistence/archivage, pas de duplication lifecycle (R4).
- **`core/rules/`** : 7 fichiers, toutes méthodes pures, testables sans Flutter.

## Recommendations

### High Impact

- [x] **R8 — Compléter R4 : déplacer `timeline`, `top_score`, `replay_panel` dans `core/widgets/`**

  Ces trois widgets sont importés par **à la fois** `match_screen.dart` et `match_replay_screen.dart`. Selon la règle CLAUDE.md, tout widget utilisé par ≥ 2 features appartient à `core/widgets/`. La situation est strictement identique à `court.dart` traité en R4.

  `match_notes.dart` est l'inverse : uniquement importé par `match_replay_screen.dart` (jamais par le live match), mais il vit dans `match/widgets/`. Le déplacer dans `match_history/widgets/`.

  Après ce changement, `match_replay_screen.dart` n'importera plus rien de `match/widgets/`.

  Fichiers :
  - `app/lib/features/match/widgets/timeline.dart` → `app/lib/core/widgets/timeline.dart`
  - `app/lib/features/match/widgets/top_score.dart` → `app/lib/core/widgets/top_score.dart`
  - `app/lib/features/match/widgets/replay_panel.dart` → `app/lib/core/widgets/replay_panel.dart`
  - `app/lib/features/match/widgets/match_notes.dart` → `app/lib/features/match_history/widgets/match_notes.dart`

- [x] **R9 — Extraire les méthodes analytiques pures vers `core/rules/analytics_rules.dart`**

  `analytics_input.dart` déclare `AnalyticsInput` (classe de données) mais embarque aussi 5 méthodes statiques pures : `exchanges()`, `maxStreak()`, `subtype()`, `cap()`, `halfX()`. Ces méthodes opèrent uniquement sur `PointRecord`/`List<PointRecord>` sans accès à Flutter, Riverpod, ou contexte. Elles appartiennent à `core/rules/`.

  Impact MCP : `exchanges`, `maxStreak`, `subtype` portent de la logique métier. Les porter dans `mcp/rules.py` (classe `AnalyticsRules`) conformément à la règle de synchronisation CLAUDE.md.

  Fichier : `app/lib/features/match_history/screens/analytics/analytics_input.dart`

### Medium Impact

- [x] **R10 — Découper `court_popups.dart` (426 lignes, 5 classes privées)**

  Le fichier contient 3 overlays publics indépendants (`FaultOverlay`, `PickServerOverlay`, `PlayerPickerOverlay`) et leurs helpers privés (`_AnchoredDropdown`, `_DropdownRow`, `_AnchoredPlayerPicker`, `_PopupScrim`, `_PopupCard`). La granularité est bonne mais la taille et le mélange de 3 préoccupations différentes rendent la navigation difficile.

  Découpage proposé :
  - `fault_overlay.dart` — `FaultOverlay` + `_AnchoredDropdown` + `_DropdownRow`
  - `pick_server_overlay.dart` — `PickServerOverlay` + `_PopupScrim` + `_PopupCard`
  - `player_picker_overlay.dart` — `PlayerPickerOverlay` + `_AnchoredPlayerPicker`

  Fichier : `app/lib/features/match/widgets/court_popups.dart`

- [x] **R11 — Examiner `match_provider.dart` (590 lignes)**

  Seul fichier de la couche providers, 590 lignes avec ~25 méthodes. Le fichier est correctement structuré par sections commentées (scoring, rally, mutation, etc.). Il n'y a pas de découpage évident sans créer un couplage artificiel. Option : extraire `_commitPoint` + `_finishSet` + `_shouldChangeSides` dans un mixin ou helper privé `_MatchPointLogic` — réduit le fichier principal à ~350 lignes et isole la logique de scoring des mutations UI.

  Fichier : `app/lib/features/match/providers/match_provider.dart`

### Low Impact

- [ ] **R12 — Découper `home_screen.dart` (419 lignes, 6 classes privées)**

  `_Header`, `_SectionLabel`, `_OngoingCard`, `_PrimaryCta`, `_NavCard`, `_MenuItem` sont autosuffisantes et pourraient vivre dans `features/home/widgets/`. Réduirait le fichier à un coordinateur de ~80 lignes.

  Fichier : `app/lib/features/home/home_screen.dart`

- [ ] **R13 — Fusionner `server_badge.dart` + `serve_banner.dart` (49 + 45 = 94 lignes)**

  `ServeBanner` n'utilise que `ServerBadge`, les deux forment une unité conceptuelle unique. Un fichier `serve_banner.dart` de ~90 lignes avec `ServerBadge` en classe privée est plus lisible qu'un import one-to-one.

  Fichiers : `app/lib/features/match/widgets/server_badge.dart` + `serve_banner.dart`

- [ ] **R14 — `court_constants.dart` (1 ligne) — NE PAS FUSIONNER**

  Le fichier d'une ligne (`const kCourtMargin = 28.0`) semble trivial mais est nécessaire : fusionner `kCourtMargin` dans `core/widgets/court.dart` recréerait le cycle `court.dart ↔ player_dot.dart` qu'il a précisément été créé pour rompre. Laisser tel quel.
