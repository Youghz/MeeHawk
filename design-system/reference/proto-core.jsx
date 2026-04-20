/* global React, MH */
// MeeHawk interactive prototype — core state, reducers, gesture hooks.

const { useState, useRef, useEffect, useCallback, useReducer, createContext, useContext } = React;

// ─────────────────────────────────────────────────────────────
// Initial state
// ─────────────────────────────────────────────────────────────
const INITIAL_STATE = {
  teams: {
    e1: { name: 'Équipe 1', color: 'them', players: [
      { id: 'p1', name: 'Ana' },
      { id: 'p2', name: 'Sara' },
    ]},
    e2: { name: 'Équipe 2', color: 'us', players: [
      { id: 'p3', name: 'Léa' },
      { id: 'p4', name: 'Marie' },
    ]},
  },
  // positions on the court: { playerId: {x, y} } — 0..1 normalized. e1 on left, e2 on right.
  positions: {
    p1: { x: 0.25, y: 0.35 },
    p2: { x: 0.25, y: 0.70 },
    p3: { x: 0.75, y: 0.35 },
    p4: { x: 0.75, y: 0.70 },
  },
  servingPlayerId: 'p3',                  // Léa sert au départ
  // Index of the NEXT player to serve within each team when that team gains serve.
  // Because Léa (e2, index 0) is already serving, e2's next server after a sideout → index 1 (Marie).
  // e1 hasn't served yet, so its first server will be index 0 (Ana).
  nextServerIndex: { e1: 0, e2: 1 },
  // history: list of points { winner: 'e1'|'e2', annotations: [...], timestamp }
  history: [],
  // When true, e2 is displayed on the left and e1 on the right (score + buttons + court labels follow).
  sidesSwapped: false,
  notes: '',
  selectedPointIndex: null,               // index in history, or null
  timelineVariant: 'bars',                // bars | dots | ticks | stacked
  // Beach volley: every 7 points (sum of both scores), prompt to change sides.
  // User can permanently dismiss the prompt (for the rest of the match).
  changeSidePromptDismissed: false,
  changeSidePromptOpen: false,
  // ephemeral UI state
  popup: null,                            // null | {kind: 'attack'|'fault', x, y, team, playerId?}
};

// Reducer
function matchReducer(state, action) {
  switch (action.type) {
    case 'ADD_POINT': {
      // action: { winner: 'e1'|'e2', annotations?: [{type, text}] }
      const annotations = action.annotations || [];
      const servingTeam = teamOfPlayer(state, state.servingPlayerId);
      const winner = action.winner;

      // Sideout rotation:
      // - If the serving team wins: same server continues (no rotation).
      // - If the receiving team wins: they gain the serve, AND their server rotates
      //   to the next player in their lineup.
      let nextServerIndex = state.nextServerIndex;
      let newServerId;
      if (winner === servingTeam) {
        newServerId = state.servingPlayerId;
      } else {
        // team wins serve back — rotate to the next player in THIS team
        const team = state.teams[winner];
        const idx = state.nextServerIndex[winner];
        newServerId = team.players[idx % team.players.length].id;
        nextServerIndex = {
          ...state.nextServerIndex,
          [winner]: (idx + 1) % team.players.length,
        };
      }

      const point = {
        winner,
        annotations,
        scoreAfter: nextScoreAfter(state, winner),
        serverId: newServerId,
      };
      const total = point.scoreAfter.e1 + point.scoreAfter.e2;
      const shouldPrompt = !state.changeSidePromptDismissed && total > 0 && total % 7 === 0;
      return {
        ...state,
        history: [...state.history, point],
        servingPlayerId: newServerId,
        nextServerIndex,
        popup: null,
        changeSidePromptOpen: shouldPrompt,
      };
    }
    case 'UNDO_POINT': {
      if (state.history.length === 0) return state;
      // Rebuild server state from scratch by replaying history minus the last point
      const newHistory = state.history.slice(0, -1);
      const replay = replayServerState(newHistory, state.teams);
      return {
        ...state,
        history: newHistory,
        selectedPointIndex: null,
        servingPlayerId: replay.servingPlayerId,
        nextServerIndex: replay.nextServerIndex,
      };
    }
    case 'SELECT_POINT': {
      return { ...state, selectedPointIndex: action.index };
    }
    case 'CLEAR_SELECTION': {
      return { ...state, selectedPointIndex: null };
    }
    case 'MOVE_PLAYER': {
      return {
        ...state,
        positions: { ...state.positions, [action.playerId]: action.pos },
      };
    }
    case 'SET_NOTES': {
      return { ...state, notes: action.notes };
    }
    case 'SWAP_SIDES': {
      // mirror x positions around 0.5 AND toggle which side each team is shown on
      const np = {};
      for (const [id, p] of Object.entries(state.positions)) {
        np[id] = { x: 1 - p.x, y: p.y };
      }
      return { ...state, positions: np, sidesSwapped: !state.sidesSwapped, changeSidePromptOpen: false };
    }
    case 'DISMISS_CHANGE_SIDE_FOREVER': {
      return { ...state, changeSidePromptOpen: false, changeSidePromptDismissed: true };
    }
    case 'CLOSE_CHANGE_SIDE_PROMPT': {
      return { ...state, changeSidePromptOpen: false };
    }
    case 'RENAME_PLAYER': {
      const { playerId, name } = action;
      const teams = { ...state.teams };
      for (const tk of ['e1', 'e2']) {
        teams[tk] = {
          ...teams[tk],
          players: teams[tk].players.map(p => p.id === playerId ? { ...p, name } : p),
        };
      }
      return { ...state, teams };
    }
    case 'RENAME_TEAM': {
      return {
        ...state,
        teams: { ...state.teams, [action.teamKey]: { ...state.teams[action.teamKey], name: action.name } },
      };
    }
    case 'SHOW_POPUP': {
      return { ...state, popup: action.popup };
    }
    case 'DISMISS_POPUP': {
      return { ...state, popup: null };
    }
    case 'SET_TIMELINE_VARIANT': {
      return { ...state, timelineVariant: action.variant };
    }
    case 'RESET': {
      return { ...INITIAL_STATE, timelineVariant: state.timelineVariant };
    }
    default: return state;
  }
}

function nextScoreAfter(state, winner) {
  const score = currentScore(state);
  return { e1: score.e1 + (winner === 'e1' ? 1 : 0), e2: score.e2 + (winner === 'e2' ? 1 : 0) };
}

function currentScore(state) {
  let e1 = 0, e2 = 0;
  for (const p of state.history) {
    if (p.winner === 'e1') e1++; else e2++;
  }
  return { e1, e2 };
}

// Replay history to compute who is serving & rotation indexes.
// Used when undoing.
function replayServerState(history, teams) {
  // Initial defaults match INITIAL_STATE: Léa (p3, e2 index 0) serves; e2's next = 1, e1's next = 0.
  let servingPlayerId = 'p3';
  let nextServerIndex = { e1: 0, e2: 1 };
  const teamOf = (pid) => teams.e1.players.some(p => p.id === pid) ? 'e1' : 'e2';

  for (const point of history) {
    const servingTeam = teamOf(servingPlayerId);
    if (point.winner === servingTeam) {
      // same server continues
    } else {
      const team = teams[point.winner];
      const idx = nextServerIndex[point.winner];
      servingPlayerId = team.players[idx % team.players.length].id;
      nextServerIndex = { ...nextServerIndex, [point.winner]: (idx + 1) % team.players.length };
    }
  }
  return { servingPlayerId, nextServerIndex };
}

function teamOfPlayer(state, playerId) {
  if (state.teams.e1.players.some(p => p.id === playerId)) return 'e1';
  if (state.teams.e2.players.some(p => p.id === playerId)) return 'e2';
  return null;
}

function playerById(state, playerId) {
  for (const tk of ['e1', 'e2']) {
    const p = state.teams[tk].players.find(p => p.id === playerId);
    if (p) return p;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────
// Match context
// ─────────────────────────────────────────────────────────────
const MatchCtx = createContext(null);

function MatchProvider({ children }) {
  const [state, dispatch] = useReducer(matchReducer, INITIAL_STATE);
  return <MatchCtx.Provider value={{ state, dispatch }}>{children}</MatchCtx.Provider>;
}

function useMatch() { return useContext(MatchCtx); }

// ─────────────────────────────────────────────────────────────
// Long-press + drag hook. Returns handlers to spread on a DOM node.
// onLongPress(event) fires after 450ms of stationary press.
// onDrag(event, {dx, dy}) fires on move after long-press triggers.
// onDragEnd(event, {dx, dy}) on release.
// onTap(event) fires on quick release without long-press or drag.
// ─────────────────────────────────────────────────────────────
function useLongPressDrag({ onLongPress, onDrag, onDragEnd, onTap, delay = 450, dragAfterLongPress = true } = {}) {
  const timerRef = useRef(null);
  const stateRef = useRef({ startX: 0, startY: 0, longPressed: false, dragging: false, moved: false });

  const clear = () => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
  };

  const handlers = {
    onPointerDown(e) {
      e.currentTarget.setPointerCapture?.(e.pointerId);
      const { clientX, clientY } = e;
      stateRef.current = { startX: clientX, startY: clientY, longPressed: false, dragging: false, moved: false };
      clear();
      timerRef.current = setTimeout(() => {
        stateRef.current.longPressed = true;
        onLongPress?.(e);
        if (dragAfterLongPress) stateRef.current.dragging = true;
      }, delay);
    },
    onPointerMove(e) {
      const s = stateRef.current;
      const dx = e.clientX - s.startX;
      const dy = e.clientY - s.startY;
      if (!s.longPressed && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
        // treated as a scroll/cancel, kill the long-press timer
        s.moved = true;
        clear();
      }
      if (s.dragging) {
        onDrag?.(e, { dx, dy });
      }
    },
    onPointerUp(e) {
      const s = stateRef.current;
      clear();
      const dx = e.clientX - s.startX;
      const dy = e.clientY - s.startY;
      if (s.dragging) {
        onDragEnd?.(e, { dx, dy });
      } else if (!s.longPressed && !s.moved) {
        onTap?.(e);
      }
      stateRef.current = { startX: 0, startY: 0, longPressed: false, dragging: false, moved: false };
    },
    onPointerCancel() {
      clear();
      stateRef.current = { startX: 0, startY: 0, longPressed: false, dragging: false, moved: false };
    },
  };
  return handlers;
}

Object.assign(window, {
  MatchProvider, useMatch, useLongPressDrag,
  currentScore, teamOfPlayer, playerById, INITIAL_STATE,
});
