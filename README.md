# MeeHawk

App interne de scoring live pour le beach volley. Un coach ou un coéquipier sur la touche tape le téléphone pour enregistrer chaque échange — qui marque, comment, où, et pourquoi — et obtient un scoreboard en direct, une timeline des points et un replay des annotations.

Ce repo contient la branche `main` (app de scoring seule) et une branche `feature/video-analysis` (pipeline d'analyse vidéo, séparée).

## Capacités actuelles

### Scoring en temps réel
- Saisie manuelle d'un point via deux gros boutons `+ POINT` (un par équipe)
- Rotation de service conforme au beach (sideout) : même serveur tant que l'équipe sert, l'autre joueur prend le service quand son équipe le récupère
- Annulation du dernier point avec re-calcul correct de l'état de service (replay de l'historique)
- Noms d'équipes et de joueurs éditables en cours de match

### Saisie détaillée depuis le terrain
- **Tap** sur le terrain adverse → pose un marker de réception (visuel, éphémère)
- **Long-press** sur le terrain → popup du type d'attaque (`Cut`, `Line`, `Shot`, `Power`, `Ace`, `Bloc`) → le point est attribué à l'équipe du côté opposé
- **Long-press** sur un joueur → popup du type de faute (`Service`, `Filet`, `Double`, `Out`, `Pied`, `Autre`) → le point va à l'équipe adverse avec annotation nominative
- **Long-press + glisse** sur un joueur → repositionne la pastille sur le terrain

### Timeline et replay
- Deux rangées horizontales (une par équipe) avec un cube coloré par point gagné et un cube vide pour les rallies perdus
- Auto-scroll vers la droite à chaque nouveau point
- Tap sur un cube → ouvre un panneau de replay avec le n° de l'échange, le score au moment et toutes les annotations

### Règles beach spécifiques
- Bouton `Changer de côté` sous le terrain (miroir des positions joueurs)
- Modal automatique tous les 7 points pour rappeler le changement de côté
- Option « Ne pas changer de côté » qui silence définitivement le rappel pour ce match

### Divers
- Zone de notes libre (conditions, tactique, observations)
- Overlay d'aide gestuelle (`?` en haut à droite)

## Stack technique

### Frontend
- **Flutter 3.11+** — app cross-platform (web + iOS + Android)
- **Riverpod 3** — state management, un unique `MatchNotifier` porte la logique de match (rotation serveur, undo, swap sides, change-side prompt)
- **google_fonts** — Roboto (UI), Rubik (labels mono uppercase), Caveat (callouts terrain)
- Pas de backend ni de persistance à ce jour : l'état vit en mémoire pour la durée du match
- Aucune authentification

### Architecture
```
app/lib/
├── main.dart                 ProviderScope
├── app.dart                  MaterialApp → HomeScreen
├── theme.dart                Tokens MH + ThemeData
├── models/match_state.dart   MatchState, Team, Player, PointRecord, Annotation, Popup
├── providers/match_provider.dart   Reducer porté de proto-core.jsx
├── screens/                  home, match_setup, match
└── widgets/                  court, player_dot, timeline, replay_panel, etc.
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

Linter : `flutter analyze` doit être clean avant commit.

### Conventions
- `const` sur tout widget immuable
- Un widget = une responsabilité, max ~100 lignes
- `StatelessWidget` par défaut, `StatefulWidget` seulement pour l'état local UI
- Riverpod pour l'état partagé (`matchProvider`)
- Pas de hex values inline — toujours passer par `MH.*` dans `theme.dart`
- Pas de secrets commités
- Commit + push après chaque modification significative

## Pistes court terme
- Persistance locale (Hive ou SharedPreferences) pour survivre à un kill d'app
- Export CSV/JSON de la timeline
- Gestion multi-sets (UI pour clôturer un set, score de sets)
- Intégration des rallies découpés par la branche `feature/video-analysis`
