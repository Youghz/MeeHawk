# MeeHawk

## Project Overview

MeeHawk est une application de scoring en temps réel pour le beach volley. L'utilisateur enregistre les actions d'un match en live (points, service, réception, attaque, bloc) sans avoir besoin de vidéo.

Le traitement vidéo (détection, tracking, découpe) est sur la branche `feature/video-analysis`.

## Tech Stack

- **Flutter** — App cross-platform (web + iOS + Android)
- **Riverpod** — State management
- **very_good_analysis** — Linter (Very Good Ventures)
- Auth : aucune pour le moment

## Architecture

Structure par **feature** (tranche verticale), avec séparation stricte des responsabilités au sein de chaque feature.

```
lib/
├── main.dart
├── app.dart                    # MaterialApp + ref.listen persistence (source unique d'archivage)
├── core/
│   ├── theme.dart              # Dark theme, constantes visuelles
│   ├── rules/                  # Logique domaine pure — ZERO import Flutter
│   │   ├── attack_inference.dart
│   │   ├── match_format.dart
│   │   ├── rally_analyzer.dart
│   │   ├── service_rotation.dart
│   │   ├── set_rules.dart      # contient aussi maxTeamTouches
│   │   └── team_side.dart
│   └── widgets/                # Widgets partagés entre ≥2 features
│       ├── ball_icon.dart
│       ├── court.dart          # Court widget (utilisé par match et match_history)
│       └── court_constants.dart # kCourtMargin
└── features/
    ├── home/
    │   └── home_screen.dart
    ├── match_setup/
    │   └── match_setup_screen.dart
    ├── match/
    │   ├── match_screen.dart
    │   ├── domain/             # entities, match_state, popup types (sealed classes)
    │   ├── providers/          # match_provider (MatchNotifierBase + MatchNotifier)
    │   ├── persistence/        # match_codec, match_storage
    │   └── widgets/            # timeline, top_score, bottom_actions…
    └── match_history/
        ├── screens/            # history_screen, match_replay_screen, analytics/
        ├── domain/             # match_archive
        ├── providers/          # replay_notifier
        ├── persistence/        # archive_storage
        └── services/           # pdf_exporter
```

**Règles d'architecture :**

- Direction des dépendances : `UI → providers → domain → rules`. Jamais l'inverse.
- `core/rules/` ne doit jamais `import 'package:flutter/...'`.
- Une feature A n'importe jamais `features/B/widgets/` — seulement l'écran d'entrée ou les types domain publics de B.
- Si un widget est utilisé par ≥ 2 features, il appartient à `core/widgets/`. Extraire les constantes de layout partagées dans un fichier séparé pour éviter les imports circulaires.
- Imports absolus uniquement : `package:<app>/...` (jamais relatifs). `very_good_analysis` l'enforce via `always_use_package_imports`.
- Les méthodes de règles métier vivent en `core/rules/` (méthodes statiques pures, testables sans Flutter), pas dans les notifiers.
- `app.dart` est la **source unique** de persistence/archivage via `ref.listen`. Ne pas dupliquer de logique de sauvegarde dans les écrans (lifecycle callbacks redondants).
- Avant tout commit cross-feature : vérifier l'absence de cycle A → B et B → A. Un cycle signale qu'une dépendance doit transiter par `core/`.

## Navigation

```
HomeScreen → MatchSetupScreen → MatchScreen
HomeScreen → HistoryScreen → MatchReplayScreen
                            → AnalyticsScreen
```

## Python annotation package — synchronisation obligatoire

Le dossier `annotator/` contient un port Python exact de la logique métier Flutter.
**Toute modification d'un des fichiers Dart listés ci-dessous doit être répercutée immédiatement dans le fichier Python correspondant.**

| Dart (source de vérité) | Python (port à maintenir) |
|---|---|
| `app/lib/features/match/providers/match_provider.dart` — `MatchNotifier` | `annotator/core.py` — `MatchAnnotator` |
| `app/lib/features/match/persistence/match_codec.dart` — `MatchCodec` | `annotator/state.py` — `MatchCodec` + helpers |
| `app/lib/features/match/domain/match_state.dart` — `MatchState`, `initialMatchState` | `annotator/state.py` — `MatchState`, `initial_match_state` |
| `app/lib/core/rules/service_rotation.dart` — `ServiceRotation` | `annotator/rules.py` — `ServiceRotation` |
| `app/lib/core/rules/set_rules.dart` — `SetRules` | `annotator/rules.py` — `SetRules` |
| `app/lib/core/rules/attack_inference.dart` — `AttackInference` | `annotator/rules.py` — `AttackInference` |
| `app/lib/core/rules/rally_analyzer.dart` — `RallyAnalyzer` | `annotator/rules.py` — `RallyAnalyzer` |
| `app/lib/core/rules/match_format.dart` — `MatchFormat` | `annotator/state.py` — `MatchFormat` |

**Règle opérationnelle :** Avant chaque commit touchant un de ces fichiers Dart, ouvrir le fichier Python miroir et appliquer le changement équivalent. Vérifier ensuite `uv run --project annotator python -c "from annotator import MatchAnnotator; ..."` pour valider.

## Development

```bash
# Build + serve
cd app && flutter build web && python3 -m http.server 8080 --directory build/web

# Analyze
cd app && flutter analyze

# Tests
cd app && flutter test
```

## Règles de développement

### Vérification frontend (obligatoire)

Pour toute modification touchant l'UX :
1. `flutter build web`
2. Regard critique sur le code : clair, intuitif, bien aligné, sans texte tronqué, boutons accessibles
3. Corriger avant de présenter

### Contrôle qualité overflow (à exécuter sur demande)

Checklist anti-overflow à appliquer sur tous les widgets modifiés ou créés :

**Règles `Row` :**
- Tout `Text` dans un `Row` qui n'est pas seul doit être dans un `Flexible` ou `Expanded`
- `overflow: TextOverflow.ellipsis` sur tout `Text` dans un contexte contraint
- Pas de `Spacer()` si les voisins ne sont pas eux-mêmes contraints
- Les `Row` imbriqués dans un `Expanded` peuvent encore déborder si leurs enfants sont non contraints

**Patterns dangereux à identifier :**
```dart
// ❌ Overflow garanti sur écran étroit
Row(children: [Badge(), Text('texte long'), Spacer(), Text('autre')]);

// ✅ Correct
Row(children: [Badge(), Flexible(child: Text('...', overflow: TextOverflow.ellipsis)), SizedBox(width:8), Text('court')]);
```

**Vérification systématique :**
- Grep tous les `Row(` dans les fichiers modifiés
- Pour chaque `Row`, vérifier que chaque `Text` enfant direct est dans `Flexible`/`Expanded`
- Vérifier que `IntrinsicWidth` n'est pas utilisé dans un `Flexible` (double passe + débordement possible)
- Tester mentalement avec un nom d'équipe de 20 caractères et un écran de 360px de large

### Design — Principes fondamentaux

**L'utilisateur n'a pas de temps à perdre sur le terrain.** Chaque élément visuel doit servir une action, pas expliquer.

- **Pas de pop-up** pour confirmer des actions réversibles (undo existe). Pop-up = friction = erreur en match.
- **Pas de texte superflu** : libellés courts, icônes explicites, zéro instruction contextuelle à l'écran.
- **Actions visibles au premier regard** : les éléments cliquables doivent être reconnaissables sans hover ni tooltip.
- **Feedback visuel immédiat** : toute action doit produire un retour visible < 100 ms (couleur, animation, score).
- **Hiérarchie visuelle claire** : score en grand, actions en moyen, contexte (sets, serveur) en petit.
- **Dark theme** cohérent, couleurs neutres pour les éléments secondaires, accent uniquement sur l'état actif.
- **Pas d'animation décorative** : les animations servent le feedback (transition de score, point accordé), pas l'esthétique.

### Flutter — Bonnes pratiques

**Widgets :**
- `const` sur tout widget immuable (court-circuite les rebuilds).
- `StatelessWidget` par défaut ; `StatefulWidget` uniquement si état local non partagé.
- Un widget = une responsabilité, max ~100 lignes.
- Noms explicites : `ServeZonePicker`, `TopScore`, pas `MyWidget`, `Panel`.

**Performance :**
- Jamais `Opacity` pour les animations → utiliser `FadeTransition` (controller) ou `AnimatedOpacity` (state).
- `AnimatedBuilder` : toujours passer le sous-arbre statique en `child`, jamais inline dans `builder`.
- `RepaintBoundary` autour des `CustomPaint` coûteux qui se redessinent indépendamment (ex : canvas terrain vs marqueur animé).
- `ListView.builder` / `GridView.builder` pour toute liste potentiellement longue.
- Préférer `borderRadius` sur `BoxDecoration` plutôt que `ClipRRect` quand aucun enfant ne déborde.
- Éviter `IntrinsicHeight` / `IntrinsicWidth` (double passe de layout).
- Pour une opacité statique sur un widget peint : passer l'alpha directement dans la `Paint.color`, pas via un widget `Opacity`.

**State :**
- Riverpod pour tout état partagé entre widgets ou écrans.
- `setState` uniquement pour état purement local et éphémère (ex : focus d'un champ).
- `ListView.builder` pour les listes variables.

**Modélisation de domaine :**
- `sealed class` + sous-classes `final` pour tout type discriminé (plusieurs variantes avec des champs différents). Ne jamais modéliser ça avec `enum + champs optionnels` : les champs non-nullables sur les sous-classes et l'exhaustivité des `switch`/`is` sont supérieurs.
- Quand une sous-classe redéfinit N méthodes en no-ops pour bloquer le comportement parent, extraire une classe de base abstraite avec les no-ops comme défaut. Toute nouvelle méthode oubliée sera safe par défaut.
- Un fichier `< 15 lignes` contenant une seule déclaration (constante, provider trivial) → fusionner dans le fichier conceptuellement lié.
- Un fichier `> 500 lignes` avec des classes privées multiples mélange les responsabilités — signal de découpage.

**Lint :**
- Linter : `very_good_analysis` — inclure dans `analysis_options.yaml`.
- Désactiver uniquement `public_member_api_docs: false` et `lines_longer_than_80_chars: false` pour le code applicatif.
- `flutter analyze` doit être propre avant chaque commit.

### Règles métier beach volley

- Maximum 3 contacts par équipe par possession.
- **Bloc** : action valide uniquement si l'équipe qui bloque n'a eu **0 contact** de son côté dans la possession en cours. Si elle a déjà eu un contact (réception, passe), elle est en attaque — pas en position de bloquer une balle entrante.
- **Attaque** : l'attaquant est le dernier joueur à toucher la balle du côté gagnant.
- **Faute** : l'équipe perdante envoie la balle hors limites ou dans le filet.
- **Ace de service** : la balle arrive du côté adverse sans être touchée (netCrossings = 1).
- **Faute de service** : balle dans le filet ou hors avant de croiser (netCrossings = 0).
- Attribution toujours sur le **dernier contact réel** — jamais sur un joueur supposé.

### Communs

- Pas de valeurs magiques : constantes dans `core/` ou dans le fichier de domaine concerné.
- Pas de secrets commis.
- Commit + push après chaque modification significative.
- `flutter analyze` + `flutter test` verts avant chaque commit (hook de pré-commit enforce cette règle).
