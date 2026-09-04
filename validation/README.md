# validation/ — corpus d'évaluation de l'agent

C'est **ici** que vont les matchs annotés à la main qui servent de référence à l'agent.

```
validation/
├── manifest.json     provenance, source vidéo, empreinte — versionné
├── matches/<id>.json annotations humaines — versionnées
└── README.md
```

## Pourquoi pas `match_history/`

`match_history/` est du **runtime**, pas un corpus :

- il est gitignoré — un corpus qu'on ne peut ni versionner, ni partager, ni rejouer
  n'est pas un corpus
- l'app y réécrit en continu : chaque action de scoring fait un `upsert`. Une référence
  qui bouge invalide silencieusement toutes les mesures faites contre elle
- les matchs annotés **sur le web n'y arrivent jamais** (voir plus bas)

`validation/` est versionné et l'app n'y écrit jamais.

## Seul l'humain fait référence

`manifest.json` porte un champ `provenance` obligatoire, `human` ou `agent`.
**Seul `human` compte comme vérité terrain.**

Noter l'agent contre une ancienne sortie d'agent mesure la reproductibilité, pas la
justesse — et pousse les prompts vers les erreurs du modèle précédent. `meehawk-eval`
refuse explicitement une référence `agent` plutôt que d'afficher un score qui ne veut
rien dire.

La provenance est **déduite, pas déclarée** : l'agent horodate ses impacts
(`videoTimeSec`), l'app ne le fait jamais — elle ne fait que lire ce champ. Un seul
impact horodaté suffit à trancher.

État actuel du corpus :

| Match | Provenance | Rallyes | Utilisable comme référence |
|---|---|---|---|
| `match_20260522T030751000` | humain | 67 | ✅ |
| `match_20260520T145725000` | agent | 6 | ❌ conservé pour comparer des runs |

**Une seule vérité terrain, 67 rallyes.** C'est assez pour détecter une régression
franche, pas pour mesurer un gain de quelques points. D'où ce dossier : pour que le
corpus grandisse proprement.

## Annoter un nouveau match

### 1. Attention à la plateforme

| Où tu annotes | Où le match atterrit |
|---|---|
| `flutter run -d macos` (ou iOS / Android) | `match_history/<id>.json` ✅ |
| `flutter run -d chrome` | localStorage du navigateur ❌ |

**Annote sur desktop ou mobile.** Sur le web, le match reste dans le navigateur et
n'est récupérable qu'à la main via les DevTools.

### 2. Attacher la vidéo

Déposer le fichier dans `app/web/videos/<id>.mp4`, puis, dans l'écran Replay, l'icône
caméra en haut à droite → saisir `/videos/<id>.mp4`.

Si la vidéo vient de YouTube et est déjà dans le cache yt-dlp, **lier plutôt que
copier** — elle pèse plusieurs centaines de mégaoctets :

```bash
ln annotator/downloads/<videoId>.mp4 app/web/videos/<id>.mp4
```

### 3. Promouvoir dans le corpus

```bash
uv run meehawk-promote match_20260601T104500000 \
    --video-source "https://youtube.com/watch?v=XXXX" \
    --by "Hugo" \
    --notes "Tournoi de Marseille, contre-jour sur la fin du set 2"
```

La commande copie l'annotation, déduit la provenance, calcule l'empreinte SHA-1 de la
vidéo et met à jour le manifeste. Elle prévient si la vidéo est absente ou si le match
ressemble à une sortie d'agent.

### 4. Évaluer

```bash
uv run meehawk-eval annotator/match_state_run1.json
```

Sans `--truth`, la run est notée contre **tous** les matchs humains du corpus.

## Les vidéos ne sont pas versionnées

Trop volumineuses. Le manifeste porte pour chacune sa `source` (URL ou description),
son chemin local attendu et son `sha1` — de quoi vérifier qu'on a bien le bon fichier,
sans mettre des gigaoctets dans git.

Pour reconstituer le corpus sur une autre machine : récupérer les vidéos depuis leurs
`source`, les placer aux chemins `local` indiqués, comparer les `sha1`.

## Ce qui manque à ce corpus

À garder en tête avant de conclure quoi que ce soit d'une évaluation :

- **Un seul match humain.** Une paire d'équipes, un lieu, une caméra. Tout gain mesuré
  dessus est probablement du surajustement. Viser 4–5 matchs, tournés dans des
  conditions différentes (angle, luminosité, niveau de jeu).
- **Aucun `videoTimeSec` côté humain.** La saisie manuelle n'en produit pas, donc la
  **détection des rallyes** (pass 1 de l'agent) ne peut pas encore être évaluée — seul
  le contenu des annotations l'est. Corriger ça demanderait soit de saisir en regardant
  la vidéo avec un horodatage, soit de valider les bornes du pass 1 à la main.
- **`touchType` incomplet** : 494 impacts sur 558 en portent un. Les 64 restants ne sont
  pas comptés dans l'exactitude du type de touche.
