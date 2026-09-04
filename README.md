# CrabCoach

Application de scoring et d'analyse pour le beach volley. Sur le bord du terrain, on tape
le téléphone pour enregistrer chaque échange — qui touche, où, qui marque — et on obtient
un scoreboard en direct, une timeline, un replay des trajectoires et des statistiques de
fin de match.

Un agent Python annexe fait la même chose depuis une vidéo, avec Gemini, en réutilisant
exactement les mêmes règles de jeu.

100 % local : aucun compte, aucun backend, aucune donnée qui sort de l'appareil.

## Ce que ça fait

**Saisie sur le terrain** — le terrain est la surface de saisie. Un tap pose un impact de
balle, un double-tap un bloc, un swipe vertical désigne le joueur, un appui long termine
l'échange. Un tap hors des limites signifie « balle dehors » et attribue la faute au
dernier contact réel. La bande extérieure du côté serveur sert à poser la position de
service. Aucune pop-up de confirmation : tout est annulable.

**Règles beach appliquées automatiquement** — rotation de service en sideout, 4ᵉ touche
faute automatique, bloc qui ne consomme pas la possession de la même façon, sets à 21 /
tie-break à 15, changements de côté à la bonne cadence selon le set.

**Historique et analyse** — chaque match est archivé, rejouable point par point, avec une
page d'analyse (zones de service, de réception, issues d'attaque, longueur des échanges,
conseils) et un export PDF.

**Lecture vidéo synchronisée** — quand un match a une vidéo associée, la timeline du
lecteur porte un repère par échange ; cliquer un point saute au bon instant.

**Annotation vidéo automatique** — `annotator/` découpe une vidéo de match en échanges et
les annote avec Gemini, puis écrit le résultat dans `match_history/` où l'app le relit.
Voir [`annotator/README.md`](annotator/README.md).

## Structure

```
app/          Application Flutter (web, iOS, Android, macOS)
annotator/    Agent d'annotation vidéo Python + serveur MCP
parity/       Scénario partagé qui verrouille la parité Dart ↔ Python
landing/      Page d'accueil statique du SaaS (index.html autonome)
design-system/ Archive du handoff de design d'origine — pas une source de vérité
match_history/ Données runtime, gitignored : un .json par match archivé
```

### Architecture de `app/lib/`

Cinq couches, dépendances strictement descendantes. Une flèche vers le haut est un bug.

```
features/   Écrans. N'importent d'une autre feature que son écran d'entrée.
    ↓
core/       Thème + widgets partagés par ≥ 2 features (terrain, timeline, score).
    ↓
state/      Notifiers Riverpod. La machine à états du match vit ici.
    ↓
data/       Codecs JSON et stockage (SharedPreferences sur web, fichiers ailleurs).
    ↓
domain/     Entités et règles pures. Zéro import Flutter, zéro dépendance.
```

Cette direction est vérifiable en une commande :

```bash
cd app/lib
grep -rn "package:flutter" domain/                     # doit être vide
grep -rn "package:app/\(data\|state\|core\|features\)" domain/   # doit être vide
grep -rn "package:app/features" core/                  # doit être vide
```

Navigation : `HomeScreen → MatchSetupScreen → MatchScreen`, et
`HomeScreen → HistoryScreen → MatchReplayScreen | AnalyticsScreen`.

## Stack

- **Flutter 3.11+** / **Dart 3** — `flutter_riverpod` pour l'état partagé,
  `very_good_analysis` comme linter, `pdf` + `printing` pour l'export, `package:web`
  pour le lecteur vidéo web.
- **Python 3.11+** — `google-genai` (Gemini), `pydantic` pour les sorties structurées,
  `mcp` pour le serveur d'annotation, `yt-dlp` + `ffmpeg` pour le découpage vidéo.
  Géré avec `uv`.

## Développement

```bash
# App
cd app
flutter pub get
flutter run -d chrome          # hot reload
flutter analyze                # doit être clean
flutter test

# Agent d'annotation
uv sync --group dev
uv run pytest
uv run meehawk-annotate "https://youtube.com/watch?v=..." --label essai1
```

Un hook pre-commit (`.claude/hooks/pre-commit-check.sh`) bloque le commit si
`flutter analyze`, `flutter test` ou `pytest` échouent.

### Place disque

Rien de lourd n'est versionné — l'historique git fait quelques mégaoctets. Mais le dossier
de travail grossit vite, et pour deux raisons distinctes :

- **Caches régénérables.** `app/build` (jusqu'à 4 Go, dont ~3 Go rien que pour le build
  Android) et `app/.dart_tool` (~600 Mo). `flutter clean && rm -rf app/.dart_tool` les
  efface ; `flutter pub get` les reconstruit.
- **Vidéos de match.** Quelques centaines de mégaoctets chacune, et le même fichier est
  utilisé à deux endroits : le cache yt-dlp (`annotator/downloads/`) et les assets servis
  par l'app web (`app/web/videos/`). `meehawk-import` crée un **lien physique** plutôt
  qu'une copie, donc une vidéo n'occupe la place qu'une fois. Si tu déposes un fichier à la
  main dans les deux dossiers, tu paies la place deux fois — utilise `ln` plutôt que `cp`.

`git gc` de temps en temps : les renommages massifs laissent beaucoup d'objets non
compactés (343 Mo → 7 Mo après la restructuration).

## La règle de parité

`annotator/core.py` est un port ligne à ligne de `app/lib/state/match_provider.dart`, et
`annotator/rules.py` de `app/lib/domain/rules/`. Les deux doivent produire exactement le
même état pour la même séquence d'actions.

Ce n'est pas une question de discipline : `parity/scenario.json` rejoue une séquence
d'actions des deux côtés et compare les JSON produits. Le hook pre-commit fait échouer le
commit si le port a dérivé. Voir [`parity/README.md`](parity/README.md).

## Branches

- `main` — l'app + l'agent d'annotation, entièrement local.
- `feature/video-analysis` — pipeline de vision par ordinateur (détection, tracking,
  découpe d'échanges), séparé.
