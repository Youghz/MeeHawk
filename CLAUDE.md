# MeeHawk

## Project Overview

MeeHawk est une application d'analyse vidéo pour le volleyball. L'objectif principal est la détection et le tracking de joueurs sur des vidéos de matchs. Les données brutes de tracking serviront ensuite de base pour des features d'analyse avancées (tactique, performance, statistiques).

## Tech Stack

### Frontend
- **React** — Interface principale (upload vidéo, visualisation, dashboard)
- **Vue.js** — Composants spécialisés / micro-frontends pour les modules d'analyse
- **Vite** — Build tooling

### Backend
- **Python** (FastAPI) — API REST, orchestration des pipelines vidéo
- **RF-DETR** via le package `rfdetr` (RFDETRBase) — Détection des joueurs
- **ByteTrack** — Tracking multi-objets (suivi des joueurs frame par frame)
- **OpenCV** — Traitement vidéo, extraction de frames
- **Supervision** (Roboflow) — Annotations et visualisation des détections
- **uv** — Package manager Python (pyproject.toml, pas requirements.txt)

### Storage & Data
- Vidéos uploadées stockées localement ou sur un object store
- Données de tracking exportées en JSON/CSV pour analyse ultérieure

## Vidéos de test

Le dossier `videos/` contient deux vidéos de référence pour le développement :

- `videos/video_1.mp4` (~28 Mo)
- `videos/video_2.mp4` (~26 Mo)

Ces vidéos servent de fixtures de validation. **Tous les modules développés (détection, tracking, pipeline, API) doivent être testés contre ces vidéos** pour s'assurer que le code fonctionne sur de vraies données volleyball. Les agents Tester et Implementor doivent les utiliser comme données d'entrée lors des vérifications.

## Architecture

```
MeeHawk/
├── videos/                # Vidéos de test (NE PAS committer)
│   ├── video_1.mp4
│   └── video_2.mp4
├── frontend/              # React app principale
│   ├── src/
│   │   ├── components/    # Composants React (VideoUploader, VideoPlayer, etc.)
│   │   ├── views/         # Pages principales
│   │   └── services/      # Appels API
│   └── package.json
├── analysis-modules/      # Vue.js micro-frontends pour modules d'analyse
│   ├── src/
│   │   ├── components/    # Composants Vue d'analyse
│   │   └── views/
│   └── package.json
├── backend/               # Python FastAPI
│   ├── app/
│   │   ├── api/           # Routes FastAPI
│   │   ├── core/          # Config, settings
│   │   ├── models/        # Schémas Pydantic
│   │   ├── services/      # Logique métier
│   │   └── vision/        # Pipeline de détection/tracking
│   │       ├── detector.py    # RF-DETR detection
│   │       ├── tracker.py     # ByteTrack tracking
│   │       └── pipeline.py    # Orchestration du pipeline vidéo
│   ├── tests/
│   └── pyproject.toml
└── data/                  # Vidéos uploadées + résultats de tracking
    ├── uploads/
    └── results/
```

## Agent Architecture

Le projet utilise trois agents spécialisés :

- **Implementor** — Écrit le code de production (frontend React/Vue + backend Python + pipeline vision)
- **Tester** — Écrit et exécute les tests, valide les détections et le tracking
- **Integrator** — Assemble frontend/backend/vision, s'assure que tout fonctionne end-to-end

## Workflow

1. **Implementor** reçoit une tâche et produit le code
2. **Tester** valide l'implémentation avec des tests
3. **Integrator** combine le tout et valide l'intégration complète

## Conventions

- Agents définis dans `.claude/agents/`
- Backend Python : type hints, docstrings, async quand possible
- Frontend React : composants fonctionnels, hooks
- Frontend Vue : Composition API, `<script setup>`
- Les résultats de détection/tracking suivent un format JSON standardisé
- Les vidéos ne sont jamais committées dans le repo (ajoutées au .gitignore)

## Pipeline Vision

1. **Upload** — L'utilisateur charge une vidéo via l'interface React
2. **Extraction** — OpenCV extrait les frames de la vidéo
3. **Détection** — RF-DETR détecte les joueurs sur chaque frame
4. **Tracking** — ByteTrack associe les détections entre frames (IDs persistants)
5. **Export** — Les données de tracking sont sauvegardées en JSON et rendues disponibles via l'API
6. **Rendu vidéo annotée** — Le backend génère une vidéo de sortie avec les annotations dessinées sur chaque frame (bounding boxes + tracker IDs) via Supervision/OpenCV, sauvegardée dans `data/results/`
7. **Lecture** — Le frontend permet de lire la vidéo annotée pour visualiser le résultat final

## Output vidéo annotée

Le livrable principal est une **vidéo annotée** que l'utilisateur peut lire dans l'interface. Chaque frame doit afficher :

- **Bounding boxes** autour de chaque joueur détecté
- **Tracker ID** affiché au-dessus de chaque box (ex: `#1`, `#2`, ...)
- Les IDs doivent rester **cohérents** d'une frame à l'autre (même joueur = même ID)
- Les annotations sont rendues côté backend avec Supervision (`sv.BoundingBoxAnnotator` + `sv.LabelAnnotator`) et encodées dans un fichier vidéo MP4
- La vidéo annotée est servie par l'API et lisible dans le player du frontend
