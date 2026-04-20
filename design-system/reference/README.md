# Handoff: MeeHawk — Beach Volley Match Tracker

## Overview

**MeeHawk** is a mobile app for tracking beach volleyball matches in real time. A coach or teammate on the sideline taps the phone to record every rally — who scored, how, why, and where — producing a live scoreboard, a timeline of the match, and a replay of any exchange.

This handoff covers the **main Match screen** (portrait mobile, 402×874): the single screen where all action happens during a game.

---

## About the Design Files

The files in this bundle are **design references created in HTML + React (Babel standalone)**. They are interactive prototypes showing the intended look, feel, and behavior. They are **not production code to copy directly**.

The target platform is **Flutter** (the existing MeeHawk codebase is Flutter — Dart). Recreate the UI and behavior using the existing Flutter patterns, widgets, and state-management approach already present in the codebase (likely `flutter_bloc`, `provider`, or `riverpod` — check first, reuse whatever is established).

The React reducer in `proto-core.jsx` is the canonical source of truth for **business logic** (server rotation, sideout rules, side-swap, change-side prompt every 7 points, etc.). Port that logic — not the UI code — to Dart.

---

## Fidelity

**High-fidelity (hifi)**. The prototype includes final colors, typography, spacing, micro-interactions, and animations. Recreate pixel-perfectly where feasible; where Flutter idioms diverge from the HTML, prefer Flutter conventions but stay faithful to the visual language (colors, spacing rhythm, rounded corners, border thicknesses).

---

## Screens / Views

There is **one main screen**: the **Match screen**.

### Match Screen

**Purpose** — Track every point of a beach volley match in real time: score, serve rotation, player positions, types of attacks/faults, notes, and timeline of all rallies with tap-to-replay.

**Layout** (top to bottom, single column, phone portrait 402×874, safe-area aware):

1. **Status bar** (44 px tall, stub — replace with real platform status bar in Flutter)
2. **Top score row** — left team (name + score) · center dot · right team (score + name). Team names and player names are inline-editable on long-press (in Flutter, use a dialog or inline `TextField`).
3. **Serve banner** — a rounded pill on the side where the server is currently located. Contains a volleyball icon + "Service · [player name]". The pill shifts left/right based on which team has the serve AND whether sides are swapped.
4. **Court** — sand-colored interactive canvas (full width, 300 px tall, 6 px rounded corners). See "Court component" below.
5. **Swap sides button** — centered under the court, pill, thin outline.
6. **Timeline** — two rows (one per team). Each point is a small rounded cell; a colored cell means that team scored that rally (with cumulative team score inside), a dashed-outline empty cell means the other team scored. Horizontally scrollable, auto-scrolls to the right on new points.
7. **Replay panel** — only visible when a timeline cell is tapped. Dark card with the rally index, final score, winner team, and annotations.
8. **Notes** — dashed-border box, free-form textarea with pencil icon label.
9. **Bottom actions** — two large "+ POINT" buttons side by side (colored per team, positions follow left/right team), plus an "Annuler le dernier point" button below.
10. **Overlay: Gesture help hint** — appears on top-right, dismissible.
11. **Overlay: Change-side prompt** — modal that appears when total points is a multiple of 7 (beach volley convention). Offers "Changer de côté" or "Ne pas changer de côté" (the latter permanently silences the prompt for this match).

---

### Court component (key interactive element)

The court is a horizontal rectangle representing the beach volley court viewed from above.

- **Background**: sand color `#F5F1E8` with a subtle dotted SVG pattern (circles at 8 px grid).
- **Border**: 2 px solid ink `#1A1A1A`, 6 px corner radius.
- **Inner dashed rect** (6 px inset): 1.5 px dashed, ink-soft `#3D3D3D`, 30% opacity — marks inner play area.
- **Net**: centered vertical line, 3 px solid ink, with a 14 px-wide repeating-linear-gradient overlay (2 px ink / 4 px transparent, 45% opacity) to suggest netting.
- **Team labels**: small 12 px uppercase letter-spaced team names in the two top corners, colored per team (them = `#B33A3A`, us = `#2E7D57`). Labels swap when sides are swapped.
- **4 player dots**: pill-shaped labels (min-width 52 px, 6/10 px padding, 999 px radius, 2 px colored border, white fill, 11 px/700 player name). The serving player has an extra 3 px `ballSoft` outer ring AND a small volleyball icon above the pill.
- **Serve reception marker**: an orange pulsing circle (36 px, 2.5 px ball-colored border, ballSoft fill, with centered ball icon) that appears on the court where the user taps. Cleared when a point is registered.

#### Gestures on the court

| Gesture | Target | Effect |
|---|---|---|
| **Appui** (tap) | Empty court area | Place a serve-reception marker at that point (visual only, cleared on next point) |
| **Appui prolongé** (long-press ≥ 420 ms) | Empty court area | Open the **Attaque** popup — team opposite to the long-pressed side gets the point |
| **Appui prolongé** (long-press ≥ 450 ms) then **release without moving** | A player dot | Open the **Faute** popup — opposing team gets the point |
| **Appui prolongé + drag** | A player dot | Reposition the player on the court (x clamped 0.05–0.95, y clamped 0.10–0.90) |
| **Appui** (tap) | Timeline cell | Show the replay of that rally in the replay panel |

#### Attaque popup (type of attack)
Modal over the court. Types: `Cut`, `Line`, `Shot`, `Power`, `Ace`, `Bloc`. Tapping one records a point with annotation `"Attaque <Type>"` for the winning team. Outside-tap dismisses.

#### Faute popup (type of fault)
Modal over the court. Types: `Service`, `Filet`, `Double`, `Out`, `Pied`, `Autre`. Tapping one records a point for the OPPOSING team with annotation `"Faute <Type> · <player name>"`. Outside-tap dismisses.

#### Change-side prompt (every 7 points)
Full modal, triggered automatically when `scoreE1 + scoreE2` is a positive multiple of 7 (beach volley convention). Three options:
- **Changer de côté** — applies side swap
- **Ne pas changer de côté** — permanently silences the prompt for the rest of this match

---

## Interactions & Behavior

### Server rotation (critical — follows volleyball sideout rules)

Implemented in `proto-core.jsx` → `matchReducer` → `ADD_POINT`. Port exactly.

- Each team has a **lineup order** (e.g., E1: Ana then Sara; E2: Léa then Marie).
- Each team has an independent `nextServerIndex` pointing at the player who will serve next **if their team gains the serve**.
- On `ADD_POINT`:
  - If the winner's team is **already serving** → same server continues (no rotation).
  - If the winner's team was **receiving** → they gain the serve, the server becomes `team.players[nextServerIndex[team]]`, and then `nextServerIndex[team]` rotates to the next player (modulo team size).
- **Initial state**: Léa (E2, index 0) serves. `nextServerIndex = { e1: 0, e2: 1 }` so that:
  - If E1 gains serve first → Ana serves (index 0)
  - If E2 regains serve later → Marie serves (index 1, because Léa already served)
- **Undo** must rebuild server state from scratch by replaying the reduced history. See `replayServerState` helper.

### Side swap

`SWAP_SIDES` action mirrors every player's x-coordinate around 0.5 AND toggles a global `sidesSwapped` boolean. The boolean drives:
- Which team appears left vs right in the top score row
- Which team label sits in which top corner of the court
- Which + POINT button is on the left vs right
- Which side the serve-banner pill sits on
- How the court-tap "left half" vs "right half" maps to winning team for attack popups

### Change-side prompt
- Triggered in `ADD_POINT` when `point.scoreAfter.e1 + point.scoreAfter.e2 > 0 && total % 7 === 0 && !changeSidePromptDismissed`.
- `DISMISS_CHANGE_SIDE_FOREVER` sets `changeSidePromptDismissed: true` for the match.
- `SWAP_SIDES` also closes the prompt.

### Timeline auto-scroll
On `history.length` change, both row `<div>`s get `scrollLeft = scrollWidth` to keep the latest points visible.

### Long-press + drag hook
See `useLongPressDrag` in `proto-core.jsx`. Behavior:
- Press starts a 420–450 ms timer; if the pointer moves more than 8 px before the timer fires, it's treated as a scroll and the timer is cleared.
- After the timer fires, `onLongPress` is called; further pointer movement triggers `onDrag`.
- On release: if dragging, `onDragEnd` with total delta; if not (short press, no movement, no long-press), `onTap`.

In Flutter, use `GestureDetector` with `onLongPressStart` / `onLongPressMoveUpdate` / `onLongPressEnd`, or `LongPressDraggable` for the player-dot repositioning.

---

## State Management

The full state is centralized in a reducer. Port to Flutter using whatever state solution the existing codebase uses (Bloc, Riverpod, Provider). Schema:

```dart
class MatchState {
  Map<String, Team> teams; // 'e1', 'e2'
  Map<String, CourtPosition> positions; // playerId -> {x, y} in 0..1
  String servingPlayerId;
  Map<String, int> nextServerIndex; // {'e1': 0, 'e2': 1}
  List<Point> history;
  bool sidesSwapped;
  String notes;
  int? selectedPointIndex;
  String timelineVariant; // 'bars' for now
  bool changeSidePromptDismissed;
  bool changeSidePromptOpen;
  Popup? popup; // {kind: 'attack'|'fault', x, y, winner, playerId?}
}

class Team { String name; List<Player> players; }
class Player { String id; String name; }
class CourtPosition { double x, y; }
class Point {
  String winner;            // 'e1' | 'e2'
  List<Annotation> annotations;
  Map<String, int> scoreAfter;
  String serverId;
}
class Annotation { String type; String text; String? team; }
```

### Actions (reducer events)
`ADD_POINT`, `UNDO_POINT`, `SELECT_POINT`, `CLEAR_SELECTION`, `MOVE_PLAYER`, `SET_NOTES`, `SWAP_SIDES`, `RENAME_PLAYER`, `RENAME_TEAM`, `SHOW_POPUP`, `DISMISS_POPUP`, `DISMISS_CHANGE_SIDE_FOREVER`, `CLOSE_CHANGE_SIDE_PROMPT`, `SET_TIMELINE_VARIANT`, `RESET`.

See `proto-core.jsx` for the exact reducer logic — **port the logic verbatim**, particularly `ADD_POINT` (server rotation + change-side trigger), `UNDO_POINT` (history replay), and `SWAP_SIDES`.

### Data persistence
Not yet implemented in the prototype. For production, persist `MatchState` to local storage (Hive, SharedPreferences, or SQLite) on every state change so a coach can resume a match after an accidental app-kill.

---

## Design Tokens

From `design-system.jsx`:

### Colors
```
sand      #F5F1E8   court / background
paper     #FFFEFB   card surface
ink       #1A1A1A   primary text / strokes
inkSoft   #3D3D3D   secondary text
pencil    #6B6B6B   tertiary / hints
rule      #D4CFC1   hairline rules, court lines
ruleSoft  #E8E2D2   very subtle dividers

ball      #E4662A   volleyball / serve accent (terracotta orange)
ballSoft  #FBE9DD   tinted bg for ball pills

us        #2E7D57   court green (team 2 / positive outcomes)
usSoft    #DDEEE3
them      #B33A3A   opponent red (team 1 / negative outcomes)
themSoft  #F3DADA

good      #2E7D57   quality-scale positive
mid       #C88A2E   quality-scale neutral (amber)
bad       #B33A3A   quality-scale negative
```

### Typography
- **Sans (UI + body)**: `Google Sans`, fallback `Roboto`, system UI
- **Handwritten (rare, for court callouts only)**: `Caveat`
- **"Mono" small-caps labels**: `Rubik` (configured as `fontMono` in the system but used like a sporty semi-bold for uppercase labels)

In Flutter, use `google_fonts` package: `GoogleFonts.rubik`, `GoogleFonts.caveat`. "Google Sans" is not on Google Fonts (it's proprietary); substitute with `GoogleFonts.roboto` or `GoogleFonts.inter`.

### Spacing scale
`4, 8, 12, 16, 20, 24, 32, 40` (name them `s1..s10`).

### Border radius
- Buttons: 8–12
- Cards / popups: 10–16
- Court: 6
- Pills: 999 (full-round)

### Borders
- Thin: 1.5 px solid ink
- Regular: 1.8 px solid ink
- Thick: 2.5 px solid ink
- Dashed: 2 px dashed

### Shadows
- Phone-shell: `0 30px 60px rgba(0,0,0,0.25)` (prototype only)
- Popup: `0 20px 40px rgba(0,0,0,0.25)`
- Modal scrim: `rgba(20,18,16,0.55)`

### Animations
- `meeHawkPulse` (serve-reception marker): scale 1 → 1.15, opacity 0.9 → 0.55, 1.5 s ease-in-out infinite alternate
- `meeHawkFadeIn` (popups): opacity 0 → 1, translateY 4 → 0, 120–150 ms ease-out
- Player-dot move: 150 ms ease transform (disabled during active drag)

---

## Assets

- **No bitmap assets.** All iconography is inline SVG (volleyball, edit pencil, swap-sides arrows, close ×, etc.). Recreate in Flutter with `flutter_svg` or `CustomPaint`, or use Material icons where equivalent.
- **Volleyball icon**: circle + three curved lines. Definition in `design-system.jsx` → `BallIcon`.

---

## Files

Inside this handoff folder:

| File | Purpose |
|---|---|
| `MeeHawk Interactive Prototype.html` | Entry HTML — run this in a browser to see and interact with the working prototype |
| `proto-core.jsx` | **Canonical business logic**: reducer, match state, server rotation, long-press hook. Port the reducer to Dart. |
| `proto-app.jsx` | UI: PhoneShell, TopScore, ServeBanner, Court, PlayerDot, AttackPopup, FaultPopup, Timeline, ReplayPanel, Notes, BottomActions, HelpHint, ChangeSidePrompt, Screen. |
| `design-system.jsx` | Color tokens, type stack, helper components (SketchBox, HandLabel, MonoLabel, Chip, BallIcon). |
| `MeeHawk Match Wireframes.html` | Earlier mid-fi wireframes exploring multiple flow variants (kept for reference — the interactive prototype supersedes these) |
| `wireframes.jsx` | Source for the wireframes file |

---

## Implementation checklist for Claude Code

1. **Read the existing Flutter codebase** — identify current state-management (Bloc / Riverpod / Provider), theming approach, routing, and any existing match-tracking models. Reuse established patterns.
2. **Port the reducer** from `proto-core.jsx` to Dart first, with unit tests for:
   - Server rotation across sideouts (the famous "Ana → Sara on second serve-back" rule)
   - `UNDO_POINT` correctly replays server state
   - `SWAP_SIDES` mirrors positions AND toggles `sidesSwapped`
   - Change-side prompt triggers at 7/14/21 and suppresses after `DISMISS_CHANGE_SIDE_FOREVER`
3. **Build the design tokens** as a Flutter `ThemeExtension` or const class, matching the hex values exactly.
4. **Build the Match screen** top-down (TopScore → ServeBanner → Court → Swap button → Timeline → Replay → Notes → Bottom). Wire state at the screen level, keep widgets stateless where possible.
5. **Implement the gestures** on the Court last — this is the most delicate part. Use `GestureDetector` with `onLongPressStart` for tap-vs-long-press, and `LongPressDraggable` or a custom `PanGestureRecognizer` chained after a long-press for the drag-to-reposition.
6. **Add persistence** (SharedPreferences or Hive) so a match survives app-kill.
7. **Test on real devices** — the hit-target sizing (44 px minimum) assumes fingers, not a mouse.
