# MeeHawk — Design System

Cette documentation décrit le design system de l'app MeeHawk (beach volley scoring en live). Elle sert de référence pour ajouter ou modifier une feature en restant cohérent avec l'existant.

- **Source de vérité visuelle** : `reference/` — prototype React interactif + spec fournie par Claude Design
- **Source de vérité code** : `app/lib/theme.dart` (tokens) + `app/lib/widgets/` (composants) + `app/lib/screens/match_screen.dart` (assemblage)

Les deux doivent rester alignés. Si tu modifies un token ou un composant, mets à jour le document correspondant.

---

## 1. Palette

Tous les tokens sont exposés via la classe `MH` dans `app/lib/theme.dart`.

| Token       | Hex       | Usage                                           |
|-------------|-----------|-------------------------------------------------|
| `sand`      | `#F5F1E8` | Fond du terrain                                 |
| `paper`     | `#FFFEFB` | Fond général, surfaces de carte                 |
| `ink`       | `#1A1A1A` | Texte primaire, contours                        |
| `inkSoft`   | `#3D3D3D` | Texte secondaire                                |
| `pencil`    | `#6B6B6B` | Texte tertiaire, placeholders, hints            |
| `rule`      | `#D4CFC1` | Hairlines, lignes de terrain                    |
| `ruleSoft`  | `#E8E2D2` | Séparateurs très discrets                       |
| `ball`      | `#E4662A` | Accent volley (service, réception)              |
| `ballSoft`  | `#FBE9DD` | Fond teinté pour éléments ball                  |
| `us`        | `#2E7D57` | Équipe 2 / vert terrain                         |
| `usSoft`    | `#DDEEE3` | Fond teinté équipe 2                            |
| `them`      | `#B33A3A` | Équipe 1 / rouge adversaire                     |
| `themSoft`  | `#F3DADA` | Fond teinté équipe 1                            |
| `good`      | `#2E7D57` | Échelle qualité — positif                       |
| `mid`       | `#C88A2E` | Échelle qualité — neutre                        |
| `bad`       | `#B33A3A` | Échelle qualité — négatif                       |

Règles :
- `ink` est la seule couleur autorisée pour le texte primaire.
- `us` / `them` ne s'appliquent qu'à l'équipe, pas au UI chrome.
- `ball` est réservé au service / à la réception (accent orange unique).
- Ne jamais inventer une couleur — étendre `MH` si vraiment nécessaire.

## 2. Typographie

Chargée via `google_fonts` dans `theme.dart`.

| Rôle                  | Famille  | Helper               |
|-----------------------|----------|----------------------|
| UI + body             | Roboto   | `MH.sans(...)`       |
| Labels mono-small-caps| Rubik    | `MH.mono(...)`       |
| Annotations sketchy   | Caveat   | `MH.hand(...)`       |

Roboto remplace "Google Sans" de la spec (pas disponible sur Google Fonts).

Tailles usuelles :
- `34` — score principal (`TopScore`)
- `18` — titres de modal
- `15` — boutons primaires
- `13` — body
- `12` — labels team
- `11` — player names, hints
- `10`–`9` — mono uppercase (GESTES, ÉCHANGE N, +POINT)

Pour les chiffres tabulaires (scores, timeline) : `FontFeature.tabularFigures()`.

## 3. Espacement

Rythme défini dans `MH` :

```
s1=4  s2=8  s3=12  s4=16  s5=20  s6=24  s8=32  s10=40
```

Usage :
- Gouttière latérale de l'écran Match : `14px`
- Gap interne d'une carte : `s2`–`s3`
- Inter-sections verticale : `s2`–`s4`

## 4. Rayons et bordures

| Élément         | Radius       |
|-----------------|--------------|
| Boutons         | 8–12         |
| Cartes / popups | 10–16        |
| Terrain         | 6            |
| Pills (server, swap, chips, change-side) | 999 |

Épaisseurs :
- Thin : `1.5` (player dot, chips, contour éditable)
- Regular : `1.8`
- Thick : `2` (terrain, popup border, + POINT button)
- Dashed : pour le rectangle intérieur du terrain et la bordure de la zone Notes

## 5. Composants Flutter

Tous dans `app/lib/widgets/` sauf mention contraire.

| Composant               | Fichier                       | Rôle                                           |
|-------------------------|-------------------------------|------------------------------------------------|
| `BallIcon`              | `ball_icon.dart`              | Icône volley (cercle + 3 arcs), CustomPaint    |
| `ServerBadge`           | `server_badge.dart`           | Pill orange "Service · {joueur}"               |
| `TopScore`              | `top_score.dart`              | Bande haut : noms d'équipe/joueurs éditables + score |
| `ServeBanner`           | `serve_banner.dart`           | Affiche la pill `ServerBadge` du bon côté      |
| `Court`                 | `court.dart`                  | Terrain sand + filet + labels + marker réception pulsant |
| `PlayerDot`             | `player_dot.dart`             | Pastille joueur déplaçable (long-press + drag) |
| `AttackPopup`/`FaultPopup` | `court_popups.dart`        | Modals de type d'attaque / faute               |
| `SwapSidesButton`       | `swap_sides_button.dart`      | Pill sous le terrain                           |
| `Timeline`              | `timeline.dart`               | Deux lignes scrollables des points marqués     |
| `ReplayPanel`           | `replay_panel.dart`           | Carte sombre du point sélectionné              |
| `MatchNotes`            | `match_notes.dart`            | Zone de notes dashed en bas                    |
| `BottomActions`         | `bottom_actions.dart`         | Deux gros boutons + POINT + Annuler            |
| `HelpHint`              | `help_hint.dart`              | Overlay d'aide gestuelle (top-right)           |
| `ChangeSidePrompt`      | `change_side_prompt.dart`     | Modal tous les 7 points                        |

Les écrans correspondants sont dans `app/lib/screens/` (`home_screen.dart`, `match_setup_screen.dart`, `match_screen.dart`).

## 6. Interactions — geste → action

Implémentées dans `Court` et `PlayerDot` via `GestureDetector`.

| Geste                              | Cible            | Effet                                                  |
|------------------------------------|------------------|--------------------------------------------------------|
| `onTapUp`                          | Terrain (vide)   | Pose un marker de réception pulsant                    |
| `onLongPressStart`                 | Terrain (vide)   | Ouvre `AttackPopup` — équipe opposée au côté marque    |
| `onLongPressStart` + pas de move   | Player dot       | Ouvre `FaultPopup` — équipe adverse marque             |
| `onLongPressStart` + `onLongPressMoveUpdate` | Player dot | Repositionne le joueur (clamp 0.05–0.95 × 0.10–0.90) |
| `onTap` sur cellule timeline       | Timeline         | Sélectionne le point → affiche `ReplayPanel`          |

## 7. Logique métier (reducer Dart)

Portée depuis `reference/proto-core.jsx` dans `app/lib/providers/match_provider.dart`.

- **Rotation serveur (sideout)** : l'équipe qui reçoit et marque gagne le service ; son serveur devient `team.players[nextServerIndex[team]]` puis `nextServerIndex[team]` tourne modulo le nombre de joueurs. Si l'équipe qui marque servait déjà, même serveur.
- **Undo** : re-rejoue l'historique complet depuis `initialServerId` pour reconstruire `servingPlayerId` et `nextServerIndex`.
- **Swap sides** : miroir des x autour de `0.5` + bascule `sidesSwapped`. Cette bool drive qui est à gauche/droite dans `TopScore`, `ServeBanner`, labels du terrain et `BottomActions`.
- **Change-side prompt** : ouvert quand `total % 7 == 0 && total > 0 && !changeSidePromptDismissed`.

## 8. Animations

- `meeHawkPulse` — marker de réception : scale 1→1.15, opacity 0.9→0.55, 1.5 s, `reverse: true`
- Déplacement du player dot : `AnimatedContainer` 150 ms, désactivé pendant le drag

## 9. Points d'extension

Si tu ajoutes :
- **Une nouvelle action** → nouvelle méthode sur `MatchNotifier`, pas de `copyWith` libre dans les widgets.
- **Un nouveau type d'annotation** → alimenter via `Annotation(type:, text:, team:)` dans `addPoint(annotations: …)`.
- **Un nouveau bouton** → utiliser les tokens `MH.*` et un radius existant. Si le design appelle quelque chose qu'aucun token ne couvre, étendre `MH` plutôt qu'utiliser une hex value inline.

---

## Alignement avec la référence

`reference/` contient le handoff original (prototype React + spec + wireframes). En cas de divergence entre ce README et la spec :

1. Si l'écart est un compromis Flutter (par ex. Roboto au lieu de Google Sans) → doc ici fait foi.
2. Si l'écart est un bug → corriger le code Flutter pour coller à la spec.

La source canonique de la logique métier reste `reference/proto-core.jsx`.
