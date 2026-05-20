# Architecture Review

**Date**: 2026-05-19
**Scope**: Full codebase — Flutter app (`app/lib/`) + MCP Python server (`mcp/`)

## Summary

L'architecture générale est solide : séparation par feature, règles métier pures en `core/rules/`, état immutable avec Riverpod. Les principales opportunités de simplification sont un fichier monolithique à 2 125 lignes (`analytics_screen.dart`), un héritage fragile dans `ReplayNotifier` (18 overrides no-op), une classe `MatchPopup` au typage approximatif, et un fichier `annotation_rules.dart` qui n'est qu'un conteneur pour une seule constante.

## Strengths

- **Couche `core/rules/` zéro-Flutter** : toutes les règles métier sont purement Dart, testables indépendamment.
- **État immutable cohérent** : `MatchState` + `copyWith` appliqués partout, pas d'état mutable dispersé.
- **Auto-persistence propre** : `app.dart` écoute `matchProvider` et synchronise les deux storages en un seul endroit.
- **Tests significatifs** : `match_provider_test.dart` (25 KB) couvre les cas limites de scoring, rotation et changement de set.
- **Dépendances minimales** : 6 packages prod, tous justifiés, aucun doublon.
- **Port Python fidèle** : `mcp/` reflète exactement la logique Dart pour l'intégration agent.

## Recommendations

### High Impact

- [x] **R1 — Décomposer `analytics_screen.dart`** : ce fichier fait 2 125 lignes avec 27 classes privées imbriquées et mélange la génération PDF avec le rendu UI. Extraire : (1) la logique PDF dans `match_history/services/pdf_exporter.dart` ; (2) les 27 classes en widgets autonomes dans `match_history/screens/analytics/widgets/`. Le fichier écran devient un coordinateur de ~100 lignes. Fichier : `app/lib/features/match_history/screens/analytics_screen.dart`

- [x] **R2 — Remplacer l'héritage `ReplayNotifier` par de la composition** : `ReplayNotifier` redéfinit 18 méthodes en no-ops pour bloquer les mutations de `MatchNotifier`. Toute nouvelle méthode ajoutée à `MatchNotifier` oubliée dans `ReplayNotifier` introduira silencieusement un bug en replay. Extraire une interface `MatchStateReader` (méthodes de lecture + `selectPoint`/`clearSelection`/`viewSet`) et faire implémenter les deux classes indépendamment. Fichiers : `app/lib/features/match_history/providers/replay_notifier.dart`, `app/lib/features/match/providers/match_provider.dart`

### Medium Impact

- [x] **R3 — Migrer `MatchPopup` vers des classes scellées** : `MatchPopup` utilise des champs optionnels (`playerId?`, `tapPos?`, `pendingImpact?`) qui ne sont pertinents que selon le `PopupKind`. Un `switch` sur `kind` ne garantit aucune exhaustivité. Dart 3 permet des classes scellées : `sealed class MatchPopup {}` + `FaultPopup`, `PickServerPopup`, `PickPlayerPopup(tapPos, pendingImpact)`, `SetEndPopup`, `MatchEndPopup`. Le compilateur vérifie l'exhaustivité dans les `switch`. Fichier : `app/lib/features/match/domain/match_popup.dart`

- [x] **R4 — Casser la dépendance circulaire `match ↔ match_history`** : `match_screen.dart` importe `match_history/persistence/` (pour archiver) et `match_history/` importe `match/widgets/court.dart` (pour le replay). Déplacer `Court` dans `core/widgets/` ou un sous-dossier `match/widgets/shared/` accessible des deux features. Pour l'archivage, passer par un callback ou un provider dans `core/` plutôt qu'un import direct. Fichiers : `app/lib/features/match/match_screen.dart`, `app/lib/features/match_history/screens/match_replay_screen.dart`

### Low Impact

- [x] **R5 — Fusionner `annotation_rules.dart` dans `set_rules.dart`** : `annotation_rules.dart` contient exactement une constante (`maxTeamTouches = 3`). Un fichier de 6 lignes pour une seule constante ajoute du bruit. La déplacer dans `set_rules.dart` (qui gère déjà les règles de possession et de set) ou dans `match_format.dart`. Fichier : `app/lib/core/rules/annotation_rules.dart`

- [x] **R6 — Inliner `match_storage_provider.dart`** : ce fichier de 8 lignes ne fait que déclarer `matchStorageProvider`. Le coller directement dans `match_storage.dart` (qui définit `MatchStorage`) réduit le nombre de fichiers sans perte de clarté. Fichier : `app/lib/features/match/persistence/match_storage_provider.dart`

- [x] **R7 — Déplacer les seed matches dans les assets ou la factory de test** : `seed_matches.dart` (510 lignes) génère des données d'exemple codées en dur dans le code applicatif. Ces données ne sont utilisées qu'à l'initialisation si l'historique est vide. Les déplacer dans `test/fixtures/` ou charger depuis `assets/seed_matches.json` pour que le code de production n'embarque pas de données de développement. Fichier : `app/lib/features/match_history/data/seed_matches.dart`
