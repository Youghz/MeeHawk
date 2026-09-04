# CrabCoach — instructions projet

App Flutter de scoring beach volley en direct, plus un agent Python qui annote des vidéos
de match avec Gemini. 100 % local : aucun compte, aucun backend, aucune donnée qui sort
de l'appareil.

Ce fichier ne contient que ce qui n'est pas déductible du code. Pour ce que fait l'app et
comment la lancer, voir `README.md`.

## Structure du repo

| Dossier | Rôle |
|---|---|
| `app/` | L'app Flutter. Voir « Architecture » plus bas. |
| `annotator/` | Agent d'annotation vidéo + serveur MCP. Voir `annotator/README.md`. |
| `parity/` | Scénario partagé qui verrouille la parité Dart ↔ Python. |
| `validation/` | Corpus d'évaluation de l'agent : matchs annotés à la main, **versionnés**. Seule la provenance `human` fait référence — voir son README. |
| `match_history/` | **Données runtime, gitignored** — un `.json` par match, écrit par l'app (desktop/mobile) et par l'agent, lu par les deux. Ce n'est **pas** le corpus d'évaluation : l'app y réécrit en continu. Ne pas confondre non plus avec `app/lib/features/match_history/`, la feature Flutter. |
| `landing/` | Page d'accueil statique du SaaS. `index.html` autonome, aucun lien avec `app/`. |
| `design-system/` | Archive du handoff de design d'origine. **Pas une source de vérité** — voir son README. |

Config : `pyproject.toml` (racine, projet Python), `.mcp.json` (serveurs MCP partagés),
`.claude/` (hook pre-commit, skills).

**Branches :** `main` (cette branche), `feature/video-analysis` (pipeline de vision, séparé).

## Architecture — `app/lib/`

Cinq couches, dépendances strictement descendantes.

```
features/   Écrans.
    ↓
core/       Thème + widgets partagés par ≥ 2 features.
    ↓
state/      Notifiers Riverpod.
    ↓
data/       Codecs et stockage.
    ↓
domain/     Entités + règles pures. Zéro import Flutter.
```

**Règles non négociables :**

1. **Jamais de flèche vers le haut.** `domain/` n'importe rien du repo, `core/` n'importe
   jamais `features/`. Vérifiable :
   ```bash
   cd app/lib
   grep -rn "package:flutter" domain/
   grep -rn "package:app/\(data\|state\|core\|features\)" domain/
   grep -rn "package:app/features" core/
   ```
   Les trois doivent être vides.

2. **Une feature n'importe d'une autre que son écran d'entrée** (pour naviguer). Le graphe
   actuel est acyclique : `home → {match_setup, match, match_history}`, `match_setup → match`,
   `match → match_history`. Avant tout commit cross-feature, vérifier qu'aucune arête
   inverse n'a été ajoutée.

3. **Les règles de jeu vivent dans `domain/rules/`**, en méthodes statiques pures. Un
   widget qui décide qui gagne un point est un bug d'architecture — c'est le cas qu'on
   vient de corriger dans `court.dart`.

4. **`app.dart` est la source unique de persistance**, via un seul `ref.listen`. Ne jamais
   sauvegarder depuis un lifecycle d'écran.

5. **Imports absolus uniquement** (`package:app/...`), enforcé par `very_good_analysis`.

## Parité Dart ↔ Python — obligatoire

`annotator/` porte la logique métier Flutter en Python. Les deux doivent produire le même
état pour la même séquence d'actions.

| Dart (source de vérité) | Python (port) |
|---|---|
| `app/lib/state/match_provider.dart` | `annotator/core.py` |
| `app/lib/domain/match_state.dart` | `annotator/state.py` |
| `app/lib/data/match_codec.dart` | `annotator/state.py` — `MatchCodec` |
| `app/lib/domain/rules/*.dart` | `annotator/rules.py` |
| `app/lib/domain/match_archive.dart` — `idFor` | `annotator/importer.py` — `match_id_for` |

**Le Dart est la source de vérité.** Toute modification d'un fichier de gauche se répercute
dans celui de droite, dans le même commit.

Ce n'est pas déclaratif : `parity/scenario.json` est rejoué des deux côtés et les états
comparés (`app/test/parity_test.dart` + `annotator/tests/test_parity.py`). Le hook
pre-commit lance `pytest`, donc une dérive bloque le commit. Après un changement de règle
volontaire, régénérer le golden (`UPDATE_PARITY_GOLDEN=1 flutter test test/parity_test.dart`)
puis relancer `uv run pytest` — s'il échoue, le port n'a pas suivi. Voir `parity/README.md`.

## Design — l'utilisateur est sur le terrain

Chaque élément visuel sert une action, pas une explication.

- **Pas de pop-up de confirmation** pour une action réversible (undo existe). Pop-up =
  friction = erreur en match.
- **Pas de texte superflu** : libellés courts, icônes explicites, aucune instruction à l'écran.
- **Actions reconnaissables sans hover ni tooltip** — l'app tourne au doigt, en plein soleil.
- **Feedback < 100 ms** sur toute action.
- **Hiérarchie** : score en grand, actions en moyen, contexte (sets, serveur) en petit.
- **Dark theme**, accent réservé à l'état actif.
- **Aucune animation décorative** : une animation sert le feedback, jamais l'esthétique.
- **Aucune couleur en dur** : tout passe par les tokens `MH` de `core/theme.dart`.

## Règles métier beach volley

- Maximum 3 contacts par équipe et par possession ; la 4ᵉ touche est une faute automatique.
- **Bloc** : valide uniquement si l'équipe qui bloque a eu 0 contact dans la possession en
  cours. Sinon elle est en attaque, pas en position de bloquer. Le bloqueur peut rejouer la
  balle juste après son bloc, mais ce second contact consomme une touche.
- **Attaque** : attribuée au dernier joueur à toucher la balle du côté gagnant.
- **Balle dehors** : la faute revient au **dernier contact réel**, jamais au côté où la
  balle est retombée. Sans contact préalable, c'est une faute de service.
- **Ace de service** : la balle arrive du côté adverse sans être touchée (netCrossings = 1).
- **Faute de service** : balle au filet ou dehors avant d'avoir croisé (netCrossings = 0).

## Avant chaque commit

`flutter analyze` + `flutter test` + `uv run pytest` doivent être verts. Le hook
`.claude/hooks/pre-commit-check.sh` l'enforce.

Ne jamais commiter de secret. Pas de `Co-Authored-By: Claude`.

## Vérification frontend

Pour toute modification qui touche l'UX : `flutter build web`, puis relecture critique
(alignement, texte tronqué, boutons atteignables au pouce). Corriger avant de présenter.

La checklist anti-overflow détaillée est dans le skill `mobile-ux-ui` — l'invoquer plutôt
que de la dupliquer ici.
