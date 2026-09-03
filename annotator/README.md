# annotator/

Deux points d'entrée qui partagent le même moteur de scoring :

- **`agent.py`** — annote une vidéo de match avec Gemini, échange par échange
- **`mcp_server.py`** — expose les mêmes actions de scoring comme outils MCP, pour
  annoter à la main depuis une session Claude en miroir de l'UI Flutter

Les deux pilotent `MatchAnnotator` (`core.py`), un port ligne à ligne du `MatchNotifier`
Flutter. C'est ce qui garantit qu'un match annoté par l'agent est indiscernable d'un match
scoré à la main : mêmes règles, même JSON, même dossier de sortie.

## La stratégie `rally_segmented`

Envoyer une vidéo de match complète à Gemini coûte cher et donne des résultats médiocres :
le modèle survole, saute des échanges, invente des timestamps. L'agent fait l'inverse — il
découpe d'abord, puis regarde de près.

```
1. Timestamps    vidéo entière → bornes de chaque échange + métadonnées du match
                 (1 appel API, sortie JSON structurée)

2. Download      yt-dlp récupère la vidéo une fois, cache par ID, plafonnée à 720p

3. Par échange   ffmpeg découpe le clip en stream copy (quasi instantané)
                 → envoyé en bytes inline → impacts + vainqueur
                 (N appels API, un par échange)

4. Rejeu         chaque échange est rejoué dans MatchAnnotator, qui applique les
                 vraies règles beach — le modèle ne décide jamais du score
```

Le point clé de l'étape 4 : Gemini fournit des **observations** (où la balle a touché, qui
a gagné l'échange), jamais des **conclusions** (le score, le serveur suivant, la fin du
set). Celles-ci sont dérivées par le même code que l'app. Un modèle qui hallucine un score
n'a donc aucun effet.

### Pourquoi des bytes inline plutôt que la Files API

La Files API n'est pas disponible sur Vertex AI et impose un quota journalier sur l'API
Developer. Les clips faisant quelques secondes, les envoyer inline supprime l'upload, la
suppression, et le quota — au prix d'une requête un peu plus lourde.

### Garde-fous sur les timestamps

Gemini rend parfois les timestamps en minutes au lieu de secondes, et parfois un échange
dont la fin précède le début. `_sanitize_timestamps` corrige les deux avant tout découpage,
sinon ffmpeg produirait des clips vides et l'annotation échouerait sans raison lisible.

## Utilisation

```bash
uv sync --group dev

# Annoter une vidéo
uv run meehawk-annotate "https://youtube.com/watch?v=XXXX" \
    --label set1-v6 \
    --context "Uniquement les 20 premières minutes."

# Annoter et pousser dans l'app d'un coup
uv run meehawk-annotate video.mp4 --label essai --import-to-app

# Importer un état déjà produit
uv run meehawk-import annotator/match_state_set1-v6.json --video clip.mp4

# Coût et précision des runs passés
uv run meehawk-report --last 10
```

Prérequis : `yt-dlp` et `ffmpeg` sur le PATH (`brew install yt-dlp ffmpeg`), et
`GOOGLE_CLOUD_PROJECT` (Vertex AI) ou `GEMINI_API_KEY` dans l'environnement ou
`annotator/.env`.

## Modules

| Fichier | Rôle |
|---|---|
| `core.py` | `MatchAnnotator` — moteur de scoring. **Port de `match_provider.dart`** |
| `state.py` | `MatchState`, `MatchCodec`. **Port de `match_state.dart` + `match_codec.dart`** |
| `rules.py` | Règles pures. **Port de `app/lib/domain/rules/`** |
| `agent.py` | Pipeline d'annotation + CLI |
| `schemas.py` | Schémas Pydantic des sorties structurées Gemini |
| `prompts/` | Prompts en markdown, éditables sans toucher au code |
| `retry.py` | Backoff sur 429 / 503 / coupures réseau |
| `video.py` | yt-dlp et ffmpeg |
| `cost.py` | Comptage de tokens, coût, précision vs `ground_truth.json` |
| `report.py` | Tableau des runs passés |
| `importer.py` | Écrit un match dans `match_history/` |
| `mcp_server.py` | Serveur MCP (déclaré dans `.mcp.json`) |

## Parité avec le Dart

`core.py`, `state.py` et `rules.py` sont des ports. Toute modification d'une règle côté
Dart doit être répercutée ici — et l'inverse est un bug, le Dart est la source de vérité.

`../parity/` rend la règle vérifiable : un scénario partagé est rejoué des deux côtés et
les états produits doivent être identiques. Le hook pre-commit lance `pytest`, donc une
dérive bloque le commit. Voir [`../parity/README.md`](../parity/README.md).

Deux écarts sont assumés et documentés là-bas : l'app ouvre une pop-up pour choisir le
premier serveur et pour enchaîner un set, l'agent tranche automatiquement.

## Sortie

Un `match_state_<label>.json` dans `annotator/`, au format `MatchCodec` — le même que
celui que l'app écrit. Avec `--import-to-app`, également un `match_history/<id>.json` que
l'app relit directement au lancement (desktop/mobile). Aucune API entre les deux, juste ce
dossier partagé.
