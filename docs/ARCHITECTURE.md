# Architecture technique — MeeHawk

Documentation de référence du code. À tenir à jour à chaque commit qui change l'architecture, le modèle de données ou les flux d'interaction.

- Palette / tokens visuels : voir `design-system/README.md`
- Spec de design canonique (React prototype) : `design-system/reference/`

---

## 1. Vue d'ensemble

App Flutter de scoring en direct pour le beach-volley. Elle capture la trajectoire du ballon (`BallImpact` par impact) et l'action gagnante (annotation du dernier coup), et dérive des stats d'échange (longueur, moyenne de touches).

**Principes** :
- Flutter + Riverpod, thème clair fidèle aux tokens `MH.*` (voir `app/lib/theme.dart`).
- Pas de backend, état 100% en mémoire, pas d'auth.
- Unidirectional data flow : les widgets lisent le state via `ref.watch`, émettent via des méthodes du Notifier.
- Pas de magic numbers : couleurs, spacing, typographie passent par les helpers de `MH`.

---

## 2. Arborescence

```
app/lib/
├── main.dart                          ProviderScope → MeeHawkApp
├── app.dart                           MaterialApp → HomeScreen
├── theme.dart                         Classe MH (tokens) + ThemeData
│
├── models/
│   └── match_state.dart               Player, Team, CourtPos,
│                                       BallImpact, Annotation,
│                                       PointRecord (+ stats dérivées),
│                                       MatchPopup, MatchState
│
├── providers/
│   ├── match_provider.dart            MatchNotifier : reducer ADD_POINT,
│   │                                  UNDO, SWAP_SIDES, pickFirstServer,
│   │                                  swapTeammates, addBallImpact,
│   │                                  addRallyAnnotation, etc.
│   └── drag_preview_provider.dart     DragPreviewNotifier : état transient
│                                      du drag (swap) pour preview live
│
├── screens/
│   ├── home_screen.dart               Page d'accueil avec CTA principal +
│   │                                  placeholders
│   ├── match_setup_screen.dart        Config équipes, joueurs, serveur
│   │                                  initial
│   └── match_screen.dart              Écran d'annotation en direct
│
└── widgets/
    ├── ball_icon.dart                 Icône ballon (CustomPaint)
    ├── server_badge.dart              Pill « Service · [joueur] »
    ├── top_score.dart                 Score + noms éditables
    ├── serve_banner.dart              Badge serveur sur le bon côté
    ├── court.dart                     Terrain, zones cliquables,
    │                                  markers d'impacts, hooks popups
    ├── player_dot.dart                Pastille joueur (tap = faute,
    │                                  long-press drag = swap)
    ├── court_popups.dart              AttackPopup, FaultPopup,
    │                                  OutsideFaultPopup, BlockPopup,
    │                                  PickServerPopup, helpers
    │                                  _AnchoredDropdown et _PopupScrim
    ├── swap_sides_button.dart         Bouton « Changer de côté »
    ├── timeline.dart                  Deux rangées synchronisées
    │                                  d'historique
    ├── replay_panel.dart              Carte sombre d'un point sélectionné
    ├── match_notes.dart               Zone de notes libres
    ├── bottom_actions.dart            Boutons + POINT et Annuler
    ├── help_hint.dart                 Overlay d'aide (fermé par défaut)
    └── change_side_prompt.dart        Modal tous les 7 points
```

---

## 3. Navigation

```
HomeScreen ──► MatchSetupScreen ──► MatchScreen
     ▲                                    │
     └────────── (retour) ────────────────┘
```

---

## 4. State management

### 4.1 Providers

Deux `NotifierProvider` :

| Provider | Type | Rôle |
|---|---|---|
| `matchProvider` | `MatchNotifier` → `MatchState` | État principal du match. Persistant pour la durée de vie de l'app (en mémoire uniquement). |
| `dragPreviewProvider` | `DragPreviewNotifier` → `DragState?` | État transient du geste de drag (swap joueur). Permet au coéquipier de « pré-afficher » à la bonne position sans polluer `matchProvider`. |

### 4.2 Flux typique d'un point

```
┌─────────────────────────────────────────────────────────┐
│ Utilisateur                                             │
└───────────────┬─────────────────────────────────────────┘
                │ tap(terrain), tap(extérieur),
                │ double-tap(filet)…
                ▼
┌─────────────────────────────────────────────────────────┐
│ Widget Court / PlayerDot                                │
│ ── calcule position normalisée, teamSide,               │
│    joueur le plus proche                                │
└───────────────┬─────────────────────────────────────────┘
                │ notifier.addBallImpact(BallImpact{...})
                │ notifier.addRallyAnnotation(Annotation{bloc…})
                │ notifier.showPopup(MatchPopup{kind,...})
                ▼
┌─────────────────────────────────────────────────────────┐
│ MatchNotifier (reducer)                                 │
│ ── accumule rallyImpacts / rallyAnnotations             │
│ ── au commit (addPoint) : flush dans PointRecord,       │
│    rotation serveur, prompt changement de côté          │
└───────────────┬─────────────────────────────────────────┘
                │ state = state.copyWith(...)
                ▼
┌─────────────────────────────────────────────────────────┐
│ Widgets (re-watch)                                      │
└─────────────────────────────────────────────────────────┘
```

---

## 5. Modèle de données

### 5.1 Entités de base

```dart
class Player {
  String id;          // 'p1'..'p4', stables pour le match
  String name;
}

class Team {
  String name;
  List<Player> players;   // longueur 2 pour du beach
}

class CourtPos {
  double x, y;        // 0..1 dans le référentiel INTÉRIEUR du terrain
}
```

### 5.2 `BallImpact` — cœur du modèle

Représente une touche de ballon pendant un échange.

```dart
class BallImpact {
  double x, y;        // 0..1 dans le référentiel EXTÉRIEUR
                      // (terrain + marge out-of-bounds)
  bool isOutside;     // vrai si tombé dans la marge
  String teamSide;    // 'e1' | 'e2' — côté du terrain au moment
                      // de l'impact (capturé maintenant pour
                      // résister aux swap ultérieurs)
  String? playerId;   // joueur le plus proche sur teamSide
                      // (auto-attribution)
}
```

**Référentiel extérieur** : le tap peut tomber dans la marge cliquable (hors lignes). `(x, y)` est normalisé par la largeur/hauteur totale (terrain + marge des 2 côtés). Cela permet de stocker aussi bien les impacts inside que outside dans un seul tableau cohérent.

**Auto-attribution du joueur** : calcul de distance au carré (x² + y²) entre le tap et les positions des deux joueurs du `teamSide`. Le plus proche est enregistré. Heuristique imparfaite (un attaquant adverse peut être plus proche que le défenseur en théorie, mais on limite à l'équipe du côté).

### 5.3 `Annotation`

Description textuelle d'une action. Utilisée à la fois pour les événements de rally (blocs) et pour l'action gagnante (attaque/faute).

```dart
class Annotation {
  String type;        // 'attack' | 'fault' | 'block' | 'manual'
  String text;        // "Attaque Cut · Léa", "Bloc Ligne · Marie"…
  String? team;       // équipe concernée
}
```

### 5.4 `PointRecord`

Données complètes d'un point marqué.

```dart
class PointRecord {
  String winner;                     // 'e1' | 'e2'
  List<Annotation> annotations;      // blocs du rally + action gagnante
  int scoreE1, scoreE2;              // score APRÈS le point
  String serverId;                   // serveur de ce point
  List<BallImpact> impacts;          // trajectoire complète

  int scoreOf(String team);

  // ── Stats dérivées ──
  int get rallyLength;               // nombre de passages du filet
                                     // (0 au serveur, +1 à chaque
                                     // transition teamSide[i] ≠ [i-1])

  Map<String, double> averageTouchesPerVisit();
                                     // { 'e1': x, 'e2': y }
                                     // moyenne des longueurs des
                                     // runs consécutifs par teamSide
}
```

### 5.5 `MatchPopup`

Dialogue ouvert (fault/outsideFault/block/pickServer).

```dart
enum PopupKind { fault, pickServer, outsideFault, block }

class MatchPopup {
  PopupKind kind;
  String winner;                  // team cible (ou bloqueur pour block)
  String? playerId;               // fixé pour fault (joueur dot tappé)
  Offset? tapPos;                 // ancre du dropdown
  List<Annotation> pendingAnnotations;
                                  // utilisé par pickServer pour différer
                                  // le commit du point
}
```

Le cas **attack** a été supprimé : le long-press intérieur commit
directement le point sans popup, puisque le scoreur (= dernier
toucheur) et le type d'attaque sont auto-dérivés.

### 5.6 `MatchState`

```dart
class MatchState {
  Map<String, Team> teams;                 // {'e1': …, 'e2': …}
  Map<String, CourtPos> positions;         // {pId: pos} en frame intérieure
  String servingPlayerId;                  // serveur courant
  String initialServerId;                  // premier serveur du match
  Map<String, int> nextServerIndex;        // index rotation par équipe
  Map<String, int?> firstServerIndex;      // null = pas encore pris
  List<Annotation> rallyAnnotations;       // tampon du rally courant
  List<BallImpact> rallyImpacts;           // tampon du rally courant
  List<PointRecord> history;               // points joués
  bool sidesSwapped;
  String notes;
  int? selectedPointIndex;                 // point sélectionné dans
                                           // la timeline pour le replay
  bool changeSidePromptDismissed;          // silence permanent du rappel
  bool changeSidePromptOpen;               // affichage courant du modal
  MatchPopup? popup;
}
```

**Invariants** :
- `teams` a toujours exactement les clés `'e1'` et `'e2'`.
- `rallyAnnotations` et `rallyImpacts` sont **vidés** à chaque commit de point.
- `firstServerIndex[team]` passe de `null` à une valeur entière lors du 1er service de l'équipe (popup `pickServer`).

### 5.7 `DragState`

Ephémère, vit dans `dragPreviewProvider` pour la durée d'un geste de swap.

```dart
class DragState {
  String playerId;         // joueur draggé
  CourtPos? pos;            // position courante du drag
  bool armed;               // vrai quand plus proche du coéquipier
                            // que de l'origine → swap si relâché
}
```

---

## 6. Logique métier

### 6.1 Rotation du service (sideout beach)

Dans `MatchNotifier._commitPoint` :

- Si `winner == servingTeam` → même serveur (`state.servingPlayerId` inchangé).
- Sinon → l'équipe qui marque récupère le service :
  - `newServer = team.players[nextServerIndex[team]]`
  - `nextServerIndex[team]` tourne modulo `team.players.length`.

### 6.2 Premier service de l'équipe receveuse

Quand une équipe qui n'a pas encore servi gagne un point et récupère le service (`firstServerIndex[winner] == null`), `addPoint` **diffère** le commit et ouvre un `PopupKind.pickServer`. L'utilisateur choisit le joueur, `pickFirstServer` fixe `firstServerIndex[winner]` ET `nextServerIndex[winner]` sur le même index, puis appelle `_commitPoint` avec les annotations en attente.

### 6.3 Undo

`undoPoint` retire le dernier point puis rejoue tout l'historique depuis `initialServerId` pour reconstruire `servingPlayerId` et `nextServerIndex`. `firstServerIndex` et `rallyImpacts`/`rallyAnnotations` ne sont pas altérés.

### 6.4 Changement de côté

`swapSides` miroite les `positions.x` autour de 0.5 et bascule `sidesSwapped`. Celle-ci influence :
- quel côté affiche quelle équipe (labels, TopScore, ServeBanner, BottomActions)
- la détermination du `teamSide` lors d'un nouveau `BallImpact`

Un modal `ChangeSidePrompt` s'ouvre automatiquement quand `(scoreE1 + scoreE2) % 7 == 0`, sauf si `changeSidePromptDismissed == true`.

---

## 7. Carte des gestes (Court et PlayerDot)

Chaque geste qui touche le terrain **enregistre un `BallImpact`** avec auto-attribution au joueur le plus proche du côté du tap. La popup éventuelle ne sert plus à saisir un joueur (il est déjà connu par le dernier impact), seulement à qualifier l'action (type de faute, direction de bloc).

| Geste | Cible | Effet |
|---|---|---|
| **Tap simple** | Terrain (intérieur) | `BallImpact` (isOutside=false). Marker orange numéroté. Si le côté change vs l'impact précédent, auto-annotation `Attaque <type>` (ou `Service <type>` pour le 1er cross). |
| **Tap simple** | Marge extérieure | `BallImpact` (isOutside=true). Marker rouge numéroté. |
| **Long-press** | Terrain (intérieur) | `BallImpact` + **commit direct** du point à l'équipe opposée au côté du tap. Pas de popup. Type d'attaque auto-dérivé. |
| **Long-press** | Marge extérieure | `BallImpact` + ouverture d'`OutsideFaultPopup` (1-step : type de faute). Faulteur = dernier toucheur avant l'impact out. |
| **Double-tap** | Zone filet (±18% autour du centre) | `BallImpact` au point du tap + ouverture de `BlockPopup` (1-step : Ligne/Diagonale). Bloqueur = joueur auto-attribué à l'impact. **N'incrémente pas le score.** |
| **Tap simple** | Pastille joueur | Ouvre `FaultPopup` (Filet/Double/Contrôle). Point à l'équipe adverse. Cadre rouge peu importe l'équipe. |
| **Long-press + drag** | Pastille joueur | Active le swap vers le coéquipier. Preview live dès que l'on passe le seuil « plus proche du coéquipier ». Relâcher en état armé commit le swap. |
| **Tap** | Cellule de la timeline | Sélectionne le point → passe le terrain en **mode replay**. |
| **Geste** | Terrain pendant un replay | Quitte le mode replay (remet l'état live). |
| **Tap hors popup** | Scrim / fond | Ferme la popup ouverte. |

### 7.1 Auto-dérivation du type d'attaque

À chaque `BallImpact` qui change de `teamSide` vs le précédent, le notifier calcule le type à partir de :
- la position du dernier toucheur (`prev.x, prev.y`) = attaquant
- la position d'atterrissage (`current.x, current.y`)

| `depth = |current.x - 0.5|` | Latéralité (y attaquant vs y impact) | Type |
|---|---|---|
| `< 0.22` (court) | même demi-court en y | `Shot` |
| `< 0.22` (court) | demi-court opposé | `Cut` |
| `≥ 0.22` (fond) | même demi-court | `Ligne` |
| `≥ 0.22` (fond) | demi-court opposé | `Diag` |

Le seuil 0.22 correspond à peu près à la mi-profondeur du demi-terrain opposé dans la frame extérieure normalisée. L'annotation ajoutée est `Attaque <type> · <nom>` (ou `Service <type> · <nom>` pour le premier passage du filet du point).

### 7.2 Mode replay

Quand l'utilisateur clique une cellule de la timeline (`selectedPointIndex` non nul) :
- Le terrain affiche les impacts du `PointRecord` sélectionné (au lieu du `rallyImpacts` live).
- Les pastilles joueurs sont masquées (les positions historiques ne sont pas mémorisées).
- Des lignes pointillées relient chaque impact au suivant (via `_TrajectoryPainter`) pour visualiser la trajectoire.
- `ReplayPanel` sous le terrain affiche uniquement **la longueur de l'échange** (nombre de coups / passages du filet) et **la dernière action gagnante**.
- `MatchScreen` superpose un `Listener` plein écran qui, sur `onPointerDown`, appelle `clearSelection` : **n'importe quel clic dans l'app** sort du mode replay. Le `Listener` utilise `HitTestBehavior.translucent` donc le tap continue vers le widget sous-jacent — la sortie de replay et l'action cible ont lieu dans le même geste.

### 7.3 Seed de l'impact 0 au service

Au début de chaque échange (rallie vide, hors mode replay), le Court planifie via un `addPostFrameCallback` la création du premier impact : position du joueur en train de servir (`state.positions[state.servingPlayerId]` convertie en frame extérieure à partir des dimensions mesurées par le `LayoutBuilder`). Ainsi chaque `PointRecord.impacts[0]` représente le point d'émission du service.

L'auto-annotation des crosses fonctionne sans adaptation : le premier tap de l'utilisateur (qui atterrit en général sur le côté receveur) détecte la transition vs l'impact 0 et génère un `Service <type> · <serveur>`.

---

## 8. Composition de l'écran Match

```
┌──────────────────────────────────────────────────┐
│ TopScore (noms éditables + score)                │
│ ServeBanner (badge orange côté serveur)          │
│ ┌──────────────────────────────────────────────┐ │
│ │ Court (sand + filet)                         │ │
│ │  ─ marge cliquable out-of-bounds             │ │
│ │  ─ 4 PlayerDot positionnés                   │ │
│ │  ─ markers d'impacts accumulés               │ │
│ │  ─ popups ancrés au curseur                  │ │
│ └──────────────────────────────────────────────┘ │
│ SwapSidesButton                                  │
│ Timeline (2 rangées, scroll synchronisé)         │
│ ReplayPanel (visible si point sélectionné)       │
│ MatchNotes                                       │
│ [Spacer scroll]                                  │
├──────────────────────────────────────────────────┤
│ BottomActions (+ POINT ×2 · Annuler)  [pinned]   │
└──────────────────────────────────────────────────┘
  + HelpHint (overlay, bouton « Aide »)
  + ChangeSidePrompt (modal auto tous les 7 pts)
```

La partie scrollable est entre `TopScore` et `MatchNotes` (via `Expanded` + `SingleChildScrollView`). `BottomActions` reste ancré en bas, peu importe la taille de l'écran.

---

## 9. Patterns de performance appliqués

Référence : `docs.flutter.dev/perf/best-practices`. Voir aussi `memory/feedback_flutter_perf.md`.

- `const` constructors partout où possible.
- `RepaintBoundary` autour de `_CourtCanvas` (texture sable en `CustomPaint` lourd).
- `FadeTransition` + `ScaleTransition` pour les animations continues (pas d'`Opacity` ni `Transform.scale` dans un `AnimatedBuilder`).
- `AnimatedBuilder`/Transitions avec `child` pré-construit en `const` quand possible.
- Pas d'`Opacity` binaire (0/1) : remplacement par rendu conditionnel.
- `AnimatedPositioned` pour les déplacements animés du joueur après swap (duration: 0 pendant le drag pour suivre le doigt, 260 ms pour le retour/swap).

---

## 10. Pointeurs

- **Design system** : couleurs, typo, composants, mapping Flutter dans `design-system/README.md`.
- **Spec canonique (React)** : `design-system/reference/proto-core.jsx` (reducer originel, dont le porting Dart vit dans `match_provider.dart`).
- **README projet** : capacités utilisateur + stack technique dans `README.md` racine.
