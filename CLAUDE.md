# MeeHawk

## Project Overview

MeeHawk est une application de scoring en temps reel pour le beach volley. L'utilisateur enregistre les actions d'un match en live (points, service, reception, attaque, bloc) sans avoir besoin de video.

Le traitement video (detection, tracking, decoupe) est sur la branche `feature/video-analysis`.

## Tech Stack

- **Flutter** — App cross-platform (web + iOS + Android)
- **Riverpod** — State management
- Auth : aucune pour le moment

## Architecture

```
MeeHawk/
├── app/
│   └── lib/
│       ├── main.dart
│       ├── app.dart              # MaterialApp → HomeScreen
│       ├── theme.dart            # Dark theme
│       ├── providers/
│       │   └── match_provider.dart   # Etat du match, scoring, undo
│       ├── models/
│       │   └── match_data.dart       # MatchData, PointRecord, PendingPoint
│       ├── screens/
│       │   ├── home_screen.dart       # Landing page
│       │   ├── match_setup_screen.dart # Config equipes + points par set
│       │   └── match_screen.dart      # Scoring en cours de match
│       └── widgets/
│           └── serve_zone_picker.dart # Terrain cliquable 6 zones
└── CLAUDE.md
```

## Navigation

```
HomeScreen → MatchSetupScreen → MatchScreen
                                    ↓ (quitter)
                                HomeScreen
```

## Development

```bash
cd app && flutter build web && python3 -m http.server 8080 --directory build/web
```

- Analyze : `cd app && flutter analyze`
- Build : `cd app && flutter build web`
- Servir : `python3 -m http.server 8080 --directory build/web`

## Regles de developpement

### Verification frontend

Pour toute modification touchant l'UX :
1. `flutter build web`
2. Regard critique sur le code : clair, intuitif, bien aligne, accessible
3. Corriger avant de presenter

### Flutter

- `const` sur tout widget immuable
- Un widget = une responsabilite, max 100 lignes
- `StatelessWidget` par defaut
- Riverpod pour l'etat partage, `setState` pour le local
- `ListView.builder` pour les listes variables
- Noms explicites : `ServeZonePicker`, pas `MyWidget`

### Communs

- Pas de valeurs magiques, constantes dans config
- Pas de secrets commites
- Commit + push apres chaque modification significative
- `flutter analyze` + lint clean avant chaque commit
