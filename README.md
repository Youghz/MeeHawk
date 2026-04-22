# MeeHawk

App interne de scoring live pour le beach volley. Un coach ou un coéquipier sur la touche tape le téléphone pour enregistrer chaque échange — qui marque, comment, où, et pourquoi — et obtient un scoreboard en direct, une timeline des points et un replay des annotations.

Ce repo contient la branche `main` (app de scoring seule) et une branche `feature/video-analysis` (pipeline d'analyse vidéo, séparée).

## Capacités actuelles

### Scoring en temps réel
- Saisie manuelle d'un point via deux gros boutons `+ POINT` (un par équipe)
- Rotation de service conforme au beach (sideout) : même serveur tant que l'équipe sert, l'autre joueur prend le service quand son équipe le récupère
- Annulation du dernier point avec re-calcul correct de l'état de service (replay de l'historique)
- Noms d'équipes et de joueurs éditables en cours de match
- Gestion multi-sets avec prompt automatique de fin de set

### Saisie détaillée depuis le terrain
- **Tap** sur le terrain → pose un impact de balle (marker visuel)
- **Long-press** sur le terrain → popup du type d'attaque (`Cut`, `Line`, `Shot`, `Power`, `Ace`, `Bloc`) → le point est attribué à l'équipe du côté opposé
- **Long-press** sur un joueur → popup du type de faute (`Service`, `Filet`, `Double`, `Out`, `Pied`, `Autre`) → le point va à l'équipe adverse avec annotation nominative
- **Long-press + glisse** sur un joueur → repositionne la pastille sur le terrain
- Auto-inférence des types d'impact (Service / Attaque) selon les traversées de filet

### Timeline et replay
- Deux rangées horizontales (une par équipe) avec un cube coloré par point gagné et un cube vide pour les rallies perdus
- Auto-scroll vers la droite à chaque nouveau point
- Tap sur un cube → ouvre un panneau de replay avec le n° de l'échange, le score au moment et la trajectoire annotée

### Règles beach spécifiques
- Bouton `Changer de côté` sous le terrain (miroir des positions joueurs)
- Modal automatique tous les 7 points pour rappeler le changement de côté
- Option « Ne pas changer de côté » qui silence définitivement le rappel pour ce match

### Persistance
- Sauvegarde automatique de l'état du match en local (SharedPreferences)
- Reprise du match en cas de kill d'app ou de rechargement

### Divers
- Zone de notes libre (conditions, tactique, observations)
- Overlay d'aide gestuelle (`?` en haut à droite)

## Stack technique

### Frontend
- **Flutter 3.11+** — app cross-platform (web + iOS + Android)
- **Riverpod 3** — state management ; `MatchNotifier` porte la logique de match (rotation serveur, undo, swap sides, impacts, persistence)
- **google_fonts** — Roboto (UI), Rubik (labels mono uppercase), Caveat (callouts terrain)
- **SharedPreferences** — persistance locale du match en cours
- Aucune authentification, aucun backend

### Architecture
```
app/lib/
├── main.dart
├── app.dart                          MaterialApp → HomeScreen
├── core/
│   ├── theme.dart                    Tokens MH + ThemeData
│   ├── widgets/ball_icon.dart
│   └── rules/                        Logique pure, zéro import Flutter
│       ├── set_rules.dart            Conditions de victoire d'un set
│       ├── service_rotation.dart     Rotation de service beach
│       ├── team_side.dart            Côté terrain par équipe
│       ├── rally_analyzer.dart       Traversées de filet, inférence d'impacts
│       ├── attack_inference.dart     Auto-annotation Service / Attaque
│       └── match_format.dart        Nombre de sets, points par set
└── features/
    ├── home/home_screen.dart
    ├── match_setup/match_setup_screen.dart
    └── match/
        ├── match_screen.dart
        ├── domain/                   Entités, état, popups
        ├── providers/                match_provider, drag_preview_provider
        ├── persistence/              match_codec, match_storage
        └── widgets/                  court, timeline, replay_panel, etc.
```

Navigation : `HomeScreen → MatchSetupScreen → MatchScreen`.

### Design system
Documenté dans [`design-system/`](design-system/README.md). Contient les tokens, les composants Flutter et la référence originale (prototype React `reference/`).

### Analyse vidéo (branche séparée)
La branche `feature/video-analysis` contient une stack Python (FastAPI + RF-DETR + SAM 2 + Gemini) pour détecter, tracker et découper les rallies depuis une vidéo de match. Hors scope de l'app main — à merger / intégrer plus tard.

## Développement

```bash
cd app
flutter pub get
flutter run -d chrome              # hot reload web
# ou
flutter build web && python3 -m http.server 8080 --directory build/web
```

Tests : `flutter test`  
Linter : `flutter analyze` doit être clean avant commit.

### Conventions
- `const` sur tout widget immuable
- Un widget = une responsabilité, max ~100 lignes
- `StatelessWidget` par défaut, `StatefulWidget` seulement pour l'état local UI
- Riverpod pour l'état partagé, `setState` pour le local
- Règles métier dans `core/rules/` — aucun import Flutter
- Pas de hex values inline — toujours passer par les tokens dans `theme.dart`
- Pas de secrets commités
- `flutter analyze` + `flutter test` verts avant chaque commit

## Pistes court terme
- Export CSV/JSON de la timeline
- Intégration des rallies découpés par la branche `feature/video-analysis`
