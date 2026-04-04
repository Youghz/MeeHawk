# MeeHawk

## Project Overview

MeeHawk est une plateforme d'analyse de beach volley avec deux modes :
1. **Analyse vidéo** — Détection et tracking de joueurs via RF-DETR + SAM 2, détection de points via Gemini VLM, découpe automatique en clips
2. **Analyse manuelle** — Scoring en temps réel d'un match sans vidéo (actions, zones de service, attaques, blocs)

## Tech Stack

### Frontend (Flutter)
- **Flutter** — App cross-platform (web + iOS + Android)
- **Riverpod** — State management
- **Dio** — HTTP client
- **video_player** — Lecture vidéo
- **file_picker** — Upload de fichiers

### Backend (Python)
- **FastAPI** — API REST
- **RF-DETR** via `rfdetr` (RFDETRBase) — Détection de joueurs
- **SAM 2** via `transformers` (Sam2VideoModel) — Segmentation et tracking vidéo
- **Gemini 2.0 Flash** via `google-genai` — Détection de points joués
- **OpenCV** — Traitement vidéo, optical flow
- **yt-dlp** — Téléchargement YouTube
- **ffmpeg** — Découpe vidéo
- **uv** — Package manager Python
- **ruff** — Linter + formatter
- Auth : aucune pour le moment

## Architecture

```
MeeHawk/
├── app/                    # Flutter app
│   └── lib/
│       ├── main.dart
│       ├── app.dart        # TabBar: Video Analysis | Manual Analysis
│       ├── theme.dart      # Dark theme
│       ├── providers/      # Riverpod (video_provider, match_provider)
│       ├── models/         # Data classes (video_info, tracking_data, match_data)
│       ├── services/       # API client (api_service.dart)
│       ├── screens/        # video_analysis_screen, manual_analysis_screen
│       ├── widgets/        # UI components
│       └── utils/          # homography.dart
├── backend/                # Python FastAPI
│   ├── app/
│   │   ├── api/routes.py
│   │   ├── core/config.py
│   │   ├── models/schemas.py
│   │   ├── services/       # video, pipeline, point, correction services
│   │   └── vision/         # detector.py, segmenter.py, pipeline.py
│   └── tests/
├── data/                   # Vidéos uploadées + résultats
│   ├── uploads/
│   └── results/
├── docs/                   # Documentation recherche
├── .env                    # GEMINI_API_KEY
└── videos/                 # Vidéos de test (non committées)
```

Séparer le code par domaine fonctionnel, pas par type de fichier. Un nouveau feature ne doit jamais nécessiter de toucher à plus de 2-3 dossiers.

## Development Workflow

### Lancer le projet
```bash
# Terminal 1 - Backend (hot reload)
cd backend && uv run python run.py

# Terminal 2 - Flutter web
cd app && flutter build web && python3 -m http.server 8080 --directory build/web
```

### Backend
- Linter : `cd backend && uv run ruff check . && uv run ruff format .`
- Tests : `cd backend && uv run python -m pytest tests/ -q`
- Python 3.12 (requis par rfdetr/inference)

### Frontend
- Build : `cd app && flutter build web`
- Le serveur statique sert `build/web/` sur `http://localhost:8080`

---

## Règles de développement

### IMPORTANT — Vérification visuelle frontend

**Pour toute modification frontend touchant l'UX ou les interactions utilisateur :**
1. Générer le build (`flutter build web`)
2. Faire un regard critique sur le code : est-ce que c'est clair ? intuitif ? bien aligné ? pas de texte tronqué ? les boutons sont accessibles ?
3. Corriger les problèmes identifiés AVANT de présenter le résultat

### Flutter — Règles strictes

**Widgets**
- Tout widget immuable doit avoir le mot-clé `const`. Sans exception.
- Un widget = une responsabilité. Si un widget fait plus de 100 lignes, le découper.
- `StatelessWidget` par défaut. `StatefulWidget` uniquement si le widget gère un état local qui lui est propre (ex : champ de formulaire, animation).
- Ne jamais mettre de logique métier dans un widget. Les widgets affichent, ils ne calculent pas.

**State management**
- Utiliser Riverpod pour tout état partagé entre widgets ou écrans.
- `setState()` uniquement pour l'état purement local et isolé (ex : toggle d'un menu).
- Les providers doivent être définis en dehors des widgets, jamais à l'intérieur d'un `build()`.

**Performance**
- Utiliser `ListView.builder` ou `SliverList` pour toute liste de longueur variable.
- Tout traitement lourd (parsing JSON volumineux, calculs) doit passer par un `Isolate`.
- Ne jamais faire d'appel réseau directement dans un widget. Passer par un service ou provider.

**Qualité**
- Nommer les widgets de façon explicite : `ServeZonePicker`, `PointTimeline`, pas `MyWidget`.
- Les commentaires expliquent le pourquoi, jamais le quoi.

### Python — Règles strictes

**Structure et modularité**
- Un fichier = une responsabilité. Un fichier qui dépasse 200 lignes est un signal qu'il faut découper.
- Les routes ne font qu'appeler des services. La logique métier est dans les services.

**Performance**
- `async`/`await` pour toute opération I/O. Ne jamais bloquer le thread principal.
- Pour les opérations CPU-intensives, utiliser `asyncio.to_thread()` ou `concurrent.futures`.
- Utiliser des générateurs (`yield`) pour traiter de grandes collections sans tout charger en mémoire.

**Typage et contrats**
- Typer tous les paramètres et retours de fonctions. Toujours.
- Utiliser Pydantic pour valider et sérialiser toutes les données API.

**Gestion des erreurs**
- Ne jamais laisser passer une exception silencieusement avec un `except: pass`.
- Toujours retourner des erreurs structurées depuis l'API, jamais des stack traces brutes.

**Qualité**
- Utiliser des dataclasses ou Pydantic pour tous les objets de données.
- Nommer pour qu'on comprenne le rôle sans lire le contenu : `detect_points()` pas `process()`.

### Règles communes

- Aucune valeur magique dans le code. Constantes dans un fichier de config dédié.
- Ne jamais committer de secrets. Variables d'environnement dans `.env`.
- Les vidéos et données ne sont jamais committées (.gitignore).
- CORS configuré pour `localhost:5173` et `localhost:8080`.
- Tout nouveau feature commence par définir son interface (modèles, contrats API) avant l'implémentation.

### Tests

**Flutter**
- Unit tests pour toute logique dans les providers et services.
- Widget tests pour les composants réutilisables.

**Python**
- Unit tests pour tous les services avec `pytest`.
- Routes testées via tests d'intégration avec client HTTP de test.
- `cd backend && uv run ruff check .` avant tout commit.
