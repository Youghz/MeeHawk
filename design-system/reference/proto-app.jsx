/* global React, ReactDOM, MH, MatchProvider, useMatch, useLongPressDrag, currentScore, teamOfPlayer, playerById, INITIAL_STATE, BallIcon */

const { useState, useRef, useEffect, useCallback } = React;

const ATTACK_TYPES = ['Cut', 'Line', 'Shot', 'Power', 'Ace', 'Bloc'];
const FAULT_TYPES = ['Service', 'Filet', 'Double', 'Out', 'Pied', 'Autre'];

// ─────────────────────────────────────────────────────────────
// Phone frame (simple, no device chrome — full screen)
// ─────────────────────────────────────────────────────────────
function PhoneShell({ children }) {
  const W = 402, H = 874;
  return (
    <div style={{
      width: W, height: H, background: MH.paper,
      borderRadius: 42, border: `10px solid ${MH.ink}`,
      boxShadow: '0 30px 60px rgba(0,0,0,0.25)',
      overflow: 'hidden', position: 'relative',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Status bar */}
      <div style={{
        height: 44, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 24px', fontSize: 14, fontWeight: 600, color: MH.ink,
        flexShrink: 0,
      }}>
        <span>9:41</span>
        <span style={{ display: 'flex', gap: 4 }}>
          <span>●●●●</span>
          <span>100%</span>
        </span>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
        {children}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Top: editable teams + scores
// ─────────────────────────────────────────────────────────────
function TopScore() {
  const { state, dispatch } = useMatch();
  const score = currentScore(state);
  const leftTk = state.sidesSwapped ? 'e2' : 'e1';
  const rightTk = state.sidesSwapped ? 'e1' : 'e2';

  const EditableText = ({ value, onChange, color, size, weight, placeholder }) => (
    <span
      contentEditable
      suppressContentEditableWarning
      onBlur={(e) => onChange(e.target.textContent.trim() || placeholder)}
      onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); e.target.blur(); } }}
      style={{
        fontFamily: MH.fontSans, fontSize: size, fontWeight: weight, color,
        outline: 'none', borderBottom: `1px dashed ${MH.rule}`, padding: '0 2px',
        minWidth: 30, display: 'inline-block',
      }}>
      {value}
    </span>
  );

  const TeamHead = ({ tk, align }) => {
    const team = state.teams[tk];
    const c = tk === 'e1' ? MH.them : MH.us;
    return (
      <div style={{ textAlign: align }}>
        <EditableText
          value={team.name}
          onChange={(v) => dispatch({ type: 'RENAME_TEAM', teamKey: tk, name: v })}
          color={c} size={12} weight={700}
          placeholder={tk === 'e1' ? 'Équipe 1' : 'Équipe 2'}
        />
        <div style={{ fontSize: 11, color: MH.pencil, marginTop: 2 }}>
          {team.players.map((p, i) => (
            <React.Fragment key={p.id}>
              {i > 0 && ' · '}
              <EditableText
                value={p.name}
                onChange={(v) => dispatch({ type: 'RENAME_PLAYER', playerId: p.id, name: v })}
                color={MH.pencil} size={11} weight={500}
                placeholder="Nom"
              />
            </React.Fragment>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div style={{
      display: 'flex', alignItems: 'center', padding: '10px 14px 12px',
      background: MH.paper, borderBottom: `1px solid ${MH.rule}`, gap: 8,
    }}>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 10 }}>
        <TeamHead tk={leftTk} align="right"/>
        <div style={{ fontSize: 34, fontWeight: 700, color: MH.ink, lineHeight: 1, minWidth: 32, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{score[leftTk]}</div>
      </div>
      <div style={{ color: MH.rule, fontSize: 18 }}>·</div>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ fontSize: 34, fontWeight: 700, color: MH.ink, lineHeight: 1, minWidth: 32, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{score[rightTk]}</div>
        <TeamHead tk={rightTk} align="left"/>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Serve banner + "Changer de côté" button
// ─────────────────────────────────────────────────────────────
function ServeBanner() {
  const { state } = useMatch();
  const server = playerById(state, state.servingPlayerId);
  const servingTeamKey = teamOfPlayer(state, state.servingPlayerId);
  const serverColor = servingTeamKey === 'e1' ? MH.them : MH.us;
  // Determine which visual side the server is on, accounting for sidesSwapped.
  const serverOnLeft = state.sidesSwapped ? (servingTeamKey === 'e2') : (servingTeamKey === 'e1');
  const isLeft = serverOnLeft;
  return (
    <div style={{ padding: '10px 14px 6px', display: 'flex' }}>
      <div style={{
        flex: 1,
        display: 'flex',
        justifyContent: isLeft ? 'center' : 'flex-start',
        visibility: isLeft ? 'visible' : 'hidden',
      }}>
        <ServerBadge color={serverColor} name={server?.name}/>
      </div>
      <div style={{
        flex: 1,
        display: 'flex',
        justifyContent: isLeft ? 'flex-end' : 'center',
        visibility: isLeft ? 'hidden' : 'visible',
      }}>
        <ServerBadge color={serverColor} name={server?.name}/>
      </div>
    </div>
  );
}

function ServerBadge({ color, name }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '4px 10px 4px 8px', background: MH.ballSoft,
      border: `1.5px solid ${MH.ball}`, borderRadius: 999,
      fontSize: 11, fontWeight: 600, color,
      whiteSpace: 'nowrap',
    }}>
      <BallIcon size={13}/> <span style={{color: MH.ball}}>Service</span> · {name || '—'}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Court — interactive: tap opponent side for serve reception, long-press for popups.
// ─────────────────────────────────────────────────────────────
function Court() {
  const { state, dispatch } = useMatch();
  const courtRef = useRef(null);
  const [servePoint, setServePoint] = useState(null);   // {x, y} in percent, local to current rally
  const [draggingId, setDraggingId] = useState(null);

  // Clear serve point when a new point is registered (history grows)
  useEffect(() => { setServePoint(null); }, [state.history.length]);

  // Long-press + drag on the court itself (not on a player) → attack/fault popup
  const courtPress = useLongPressDrag({
    onLongPress: (e) => {
      const rect = courtRef.current.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width;
      const y = (e.clientY - rect.top) / rect.height;
      // Ignore if interacting with a player dot (handled separately)
      if (e.target.closest('[data-role="player"]')) return;
      // The team visually on the left side of the court depends on sidesSwapped.
      // A long-press lands on a team's court → OPPOSITE team wins the point (attaque réussie chez l'adversaire).
      const isLeftSide = x < 0.5;
      const leftTeam = state.sidesSwapped ? 'e2' : 'e1';
      const rightTeam = state.sidesSwapped ? 'e1' : 'e2';
      const winner = isLeftSide ? rightTeam : leftTeam;
      dispatch({
        type: 'SHOW_POPUP',
        popup: { kind: 'attack', x, y, winner },
      });
    },
    onTap: (e) => {
      const rect = courtRef.current.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width;
      const y = (e.clientY - rect.top) / rect.height;
      if (e.target.closest('[data-role="player"]')) return;
      // Simple tap → set reception point (opposite side of server)
      setServePoint({ x, y });
    },
    delay: 420,
    dragAfterLongPress: false,
  });

  return (
    <div style={{ padding: '0 14px', position: 'relative' }}>
      <div
        ref={courtRef}
        {...courtPress}
        style={{
          position: 'relative', width: '100%', height: 300,
          background: MH.sand, border: `2px solid ${MH.ink}`, borderRadius: 6,
          overflow: 'hidden', touchAction: 'none', userSelect: 'none',
        }}>
        {/* Sand texture */}
        <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
          <defs>
            <pattern id="sandP" x="0" y="0" width="8" height="8" patternUnits="userSpaceOnUse">
              <circle cx="2" cy="2" r="0.6" fill={MH.pencil}/>
              <circle cx="6" cy="5" r="0.4" fill={MH.pencil}/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#sandP)"/>
        </svg>

        <div style={{ position: 'absolute', inset: 6, border: `1.5px dashed ${MH.inkSoft}`, opacity: 0.3, borderRadius: 2, pointerEvents: 'none' }}/>

        {/* Filet */}
        <div style={{ position: 'absolute', top: 0, bottom: 0, left: '50%', width: 3, background: MH.ink, transform: 'translateX(-50%)', pointerEvents: 'none' }}/>
        <div style={{
          position: 'absolute', top: 0, bottom: 0, left: '50%', width: 14, transform: 'translateX(-50%)',
          backgroundImage: `repeating-linear-gradient(0deg, ${MH.ink} 0 2px, transparent 2px 6px)`, opacity: 0.45, pointerEvents: 'none',
        }}/>

        {/* Team labels */}
        <div style={{ position: 'absolute', top: 8, left: 12, fontSize: 12, color: state.sidesSwapped ? MH.us : MH.them, fontWeight: 700, letterSpacing: 1.5, pointerEvents: 'none' }}>{(state.sidesSwapped ? state.teams.e2.name : state.teams.e1.name).toUpperCase()}</div>
        <div style={{ position: 'absolute', top: 8, right: 12, fontSize: 12, color: state.sidesSwapped ? MH.them : MH.us, fontWeight: 700, letterSpacing: 1.5, pointerEvents: 'none' }}>{(state.sidesSwapped ? state.teams.e1.name : state.teams.e2.name).toUpperCase()}</div>

        {/* Players */}
        {['p1','p2','p3','p4'].map(id => (
          <PlayerDot
            key={id}
            playerId={id}
            isDragging={draggingId === id}
            onDragStart={() => setDraggingId(id)}
            onDragEnd={() => setDraggingId(null)}
            courtRef={courtRef}
          />
        ))}

        {/* Serve reception marker */}
        {servePoint && (
          <div style={{
            position: 'absolute',
            left: `${servePoint.x * 100}%`, top: `${servePoint.y * 100}%`,
            transform: 'translate(-50%, -50%)',
            width: 36, height: 36, borderRadius: '50%',
            border: `2.5px solid ${MH.ball}`, background: MH.ballSoft,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            animation: 'meeHawkPulse 1.5s ease-in-out infinite',
            pointerEvents: 'none',
          }}>
            <BallIcon size={16}/>
          </div>
        )}
      </div>

      {/* Popup rendered above the court */}
      {state.popup?.kind === 'attack' && <AttackPopup/>}
      {state.popup?.kind === 'fault' && <FaultPopup/>}

      {/* Swap sides — below the court */}
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 8 }}>
        <button
          onClick={() => dispatch({ type: 'SWAP_SIDES' })}
          style={{
            all: 'unset', cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '5px 12px', border: `1.5px solid ${MH.ink}`,
            background: MH.paper, borderRadius: 999,
            fontSize: 11, fontWeight: 600, color: MH.ink,
          }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none">
            <path d="M4 12a8 8 0 0 1 14-5.3M20 4v4h-4" stroke={MH.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M20 12a8 8 0 0 1-14 5.3M4 20v-4h4" stroke={MH.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Changer de côté
        </button>
      </div>
    </div>
  );
}

function PlayerDot({ playerId, isDragging, onDragStart, onDragEnd, courtRef }) {
  const { state, dispatch } = useMatch();
  const player = playerById(state, playerId);
  const team = teamOfPlayer(state, playerId);
  const color = team === 'e1' ? MH.them : MH.us;
  const pos = state.positions[playerId];
  const isServer = state.servingPlayerId === playerId;
  const [localPos, setLocalPos] = useState(null);

  const handlers = useLongPressDrag({
    onLongPress: (e) => {
      // Haptic-ish visual: begin drag. First 450ms = decide if tap-fault or drag-reposition.
      // Mark draggable. Meanwhile if user doesn't move, we treat release as fault popup.
      onDragStart();
    },
    onDrag: (e, { dx, dy }) => {
      const rect = courtRef.current.getBoundingClientRect();
      const nx = Math.max(0.05, Math.min(0.95, pos.x + dx / rect.width));
      const ny = Math.max(0.1, Math.min(0.9, pos.y + dy / rect.height));
      setLocalPos({ x: nx, y: ny });
    },
    onDragEnd: (e, { dx, dy }) => {
      if (localPos) {
        dispatch({ type: 'MOVE_PLAYER', playerId, pos: localPos });
        setLocalPos(null);
      } else {
        // No drag movement → treat as fault popup for this player's team
        const tk = teamOfPlayer(state, playerId);
        dispatch({
          type: 'SHOW_POPUP',
          popup: {
            kind: 'fault', playerId,
            // winner = opposing team
            winner: tk === 'e1' ? 'e2' : 'e1',
          },
        });
      }
      onDragEnd();
    },
    delay: 450,
    dragAfterLongPress: true,
  });

  const displayPos = localPos || pos;

  return (
    <div
      data-role="player"
      {...handlers}
      style={{
        position: 'absolute',
        left: `${displayPos.x * 100}%`, top: `${displayPos.y * 100}%`,
        transform: 'translate(-50%, -50%)',
        minWidth: 52, padding: '6px 10px', borderRadius: 999,
        background: MH.paper, border: `2px solid ${color}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 11, fontWeight: 700, color,
        boxShadow: isServer ? `0 0 0 3px ${MH.ballSoft}` : 'none',
        zIndex: isDragging ? 5 : 2, whiteSpace: 'nowrap',
        touchAction: 'none', userSelect: 'none', cursor: 'pointer',
        opacity: isDragging ? 0.85 : 1,
        transition: isDragging ? 'none' : 'transform 0.15s ease',
      }}>
      {player.name}
      {isServer && (
        <div style={{ position: 'absolute', top: -14, left: '50%', transform: 'translateX(-50%)' }}>
          <BallIcon size={12}/>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Popups — attack & fault
// ─────────────────────────────────────────────────────────────
function AttackPopup() {
  const { state, dispatch } = useMatch();
  const { winner } = state.popup;
  const team = state.teams[winner];
  const color = winner === 'e1' ? MH.them : MH.us;
  const pick = (t) => {
    dispatch({
      type: 'ADD_POINT',
      winner,
      annotations: [{ type: 'attack', text: `Attaque ${t}`, team: winner }],
    });
  };
  return (
    <div
      onClick={(e) => { if (e.target === e.currentTarget) dispatch({ type: 'DISMISS_POPUP' }); }}
      style={{
        position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.35)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 10, animation: 'meeHawkFadeIn 0.12s ease-out',
      }}>
      <div style={{
        width: '88%', background: MH.paper, borderRadius: 14,
        padding: 14, border: `2px solid ${color}`,
      }}>
        <div style={{ fontSize: 10, fontWeight: 700, color, letterSpacing: 0.6, marginBottom: 2 }}>POINT {team.name.toUpperCase()}</div>
        <div style={{ fontSize: 15, fontWeight: 700, color: MH.ink, marginBottom: 10 }}>Type d'attaque</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
          {ATTACK_TYPES.map(t => (
            <button key={t} onClick={() => pick(t)} style={{
              all: 'unset', cursor: 'pointer', textAlign: 'center',
              padding: '10px 6px', border: `1.5px solid ${color}`,
              borderRadius: 8, fontSize: 12, fontWeight: 600, color,
            }}>{t}</button>
          ))}
        </div>
      </div>
    </div>
  );
}

function FaultPopup() {
  const { state, dispatch } = useMatch();
  const { winner, playerId } = state.popup;
  const team = state.teams[winner];
  const loserTeam = winner === 'e1' ? 'e2' : 'e1';
  const loserPlayer = playerById(state, playerId);
  const color = MH.them;
  const pick = (t) => {
    dispatch({
      type: 'ADD_POINT',
      winner,
      annotations: [
        { type: 'fault', text: `Faute ${t} · ${loserPlayer?.name}`, team: loserTeam },
      ],
    });
  };
  return (
    <div
      onClick={(e) => { if (e.target === e.currentTarget) dispatch({ type: 'DISMISS_POPUP' }); }}
      style={{
        position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.35)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 10, animation: 'meeHawkFadeIn 0.12s ease-out',
      }}>
      <div style={{
        width: '88%', background: MH.paper, borderRadius: 14,
        padding: 14, border: `2px solid ${color}`,
      }}>
        <div style={{ fontSize: 10, fontWeight: 700, color, letterSpacing: 0.6, marginBottom: 2 }}>FAUTE · {loserPlayer?.name?.toUpperCase()}</div>
        <div style={{ fontSize: 15, fontWeight: 700, color: MH.ink, marginBottom: 10 }}>Type de faute</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
          {FAULT_TYPES.map(t => (
            <button key={t} onClick={() => pick(t)} style={{
              all: 'unset', cursor: 'pointer', textAlign: 'center',
              padding: '10px 6px', border: `1.5px solid ${color}`,
              borderRadius: 8, fontSize: 12, fontWeight: 600, color,
            }}>{t}</button>
          ))}
        </div>
        <div style={{ fontSize: 10, color: MH.pencil, marginTop: 8, textAlign: 'center' }}>
          Point pour {team.name}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Timeline — tap on a point shows replay
// ─────────────────────────────────────────────────────────────
function Timeline() {
  const { state, dispatch } = useMatch();
  const { history, timelineVariant: variant } = state;
  const rowE1Ref = useRef(null);
  const rowE2Ref = useRef(null);

  // Auto-scroll both rows to the right edge whenever history grows.
  useEffect(() => {
    for (const ref of [rowE1Ref, rowE2Ref]) {
      const el = ref.current;
      if (el) el.scrollLeft = el.scrollWidth;
    }
  }, [history.length]);

  if (history.length === 0) {
    return (
      <div style={{ padding: '10px 14px 6px' }}>
        <div style={{ fontSize: 10, color: MH.pencil, textAlign: 'center', fontStyle: 'italic', padding: '8px 0' }}>
          Aucun point marqué — tap terrain adverse (service) ou long-press (attaque/faute)
        </div>
      </div>
    );
  }

  const select = (idx) => dispatch({ type: 'SELECT_POINT', index: idx });

  if (variant === 'bars') {
    const BAR_W = 20;
    const BAR_H = 16;

    const renderRow = (teamKey, label, color, rowRef) => (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ width: 22, fontSize: 9, color, fontWeight: 700, letterSpacing: 0.4 }}>{label}</span>
        <div
          ref={rowRef}
          style={{
            flex: 1, display: 'flex', gap: 2, flexWrap: 'nowrap',
            overflowX: 'auto', scrollBehavior: 'smooth',
            scrollbarWidth: 'none', msOverflowStyle: 'none',
          }}>
          {history.map((p, i) => {
            const active = state.selectedPointIndex === i;
            const isMine = p.winner === teamKey;
            const teamScore = p.scoreAfter[teamKey];
            return (
              <div key={i} onClick={() => select(i)} style={{
                width: BAR_W, height: BAR_H, borderRadius: 3, flexShrink: 0,
                background: isMine ? color : 'transparent',
                border: isMine ? 'none' : `1px dashed ${MH.rule}`,
                outline: active ? `1.5px solid ${MH.ink}` : 'none',
                outlineOffset: 1, cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 9, fontWeight: 700, fontVariantNumeric: 'tabular-nums',
                color: isMine ? MH.paper : MH.rule,
              }}>{isMine ? teamScore : ''}</div>
            );
          })}
        </div>
      </div>
    );

    return (
      <div style={{ padding: '8px 14px 2px' }}>
        <style>{`
          .mh-tl-row::-webkit-scrollbar { display: none; }
        `}</style>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
          <div className="mh-tl-row" style={{ display: 'contents' }}/>
          {renderRow('e1', 'E1', MH.them, rowE1Ref)}
          {renderRow('e2', 'E2', MH.us, rowE2Ref)}
        </div>
      </div>
    );
  }

  return <div style={{ padding: '8px 14px' }}><em style={{ fontSize: 10, color: MH.pencil }}>Variante: {variant} — bars only in proto</em></div>;
}

function HiddenBadge({ n }) {
  return (
    <span style={{
      flexShrink: 0, fontSize: 9, color: MH.pencil, fontWeight: 600,
      padding: '1px 5px', borderRadius: 3, background: MH.ruleSoft,
    }}>←{n}</span>
  );
}

// ─────────────────────────────────────────────────────────────
// Replay panel — shown when a point is selected
// ─────────────────────────────────────────────────────────────
function ReplayPanel() {
  const { state, dispatch } = useMatch();
  if (state.selectedPointIndex === null) return null;
  const point = state.history[state.selectedPointIndex];
  if (!point) return null;

  const winnerTeam = state.teams[point.winner];
  const color = point.winner === 'e1' ? MH.them : MH.us;

  return (
    <div style={{ padding: '0 14px 6px', animation: 'meeHawkFadeIn 0.15s ease-out' }}>
      <div style={{
        background: MH.ink, color: MH.paper, borderRadius: 10,
        padding: '10px 12px', position: 'relative',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
          <span style={{
            fontSize: 9, fontWeight: 700, letterSpacing: 0.6,
            padding: '1px 6px', borderRadius: 3,
            background: color, color: MH.paper,
          }}>ÉCHANGE {state.selectedPointIndex + 1}</span>
          <span style={{ fontSize: 10, opacity: 0.6, fontVariantNumeric: 'tabular-nums' }}>
            {point.scoreAfter.e1}–{point.scoreAfter.e2}
          </span>
          <div style={{ flex: 1 }}/>
          <span style={{
            fontSize: 9, fontWeight: 600, letterSpacing: 0.4,
            textTransform: 'uppercase', color: MH.ball,
          }}>Point {winnerTeam.name}</span>
          <button
            onClick={() => dispatch({ type: 'CLEAR_SELECTION' })}
            style={{
              all: 'unset', cursor: 'pointer', fontSize: 14, color: MH.paper,
              opacity: 0.5, padding: '0 4px',
            }}>×</button>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
          {point.annotations.length === 0 && (
            <div style={{ fontSize: 11, opacity: 0.6, fontStyle: 'italic' }}>
              Aucune annotation pour cet échange
            </div>
          )}
          {point.annotations.map((a, i) => (
            <div key={i} style={{ display: 'flex', gap: 6, fontSize: 11, lineHeight: 1.3 }}>
              <span style={{ opacity: 0.5 }}>·</span>
              <span>{a.text}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Notes (editable)
// ─────────────────────────────────────────────────────────────
function Notes() {
  const { state, dispatch } = useMatch();
  return (
    <div style={{ padding: '8px 14px 6px' }}>
      <div style={{
        display: 'flex', flexDirection: 'column', gap: 4,
        padding: '10px 12px 12px', background: MH.paper,
        border: `1.5px dashed ${MH.rule}`, borderRadius: 10,
        minHeight: 68,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none">
            <path d="M16 4l4 4-11 11H5v-4L16 4z" stroke={MH.pencil} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          <span style={{ fontSize: 9, fontWeight: 600, color: MH.pencil, letterSpacing: 0.5, textTransform: 'uppercase' }}>Notes</span>
        </div>
        <textarea
          value={state.notes}
          onChange={(e) => dispatch({ type: 'SET_NOTES', notes: e.target.value })}
          placeholder="Observations, conditions, tactique…"
          style={{
            flex: 1, border: 'none', outline: 'none', resize: 'none',
            fontFamily: MH.fontSans, fontSize: 13, color: MH.inkSoft, lineHeight: 1.4,
            background: 'transparent', padding: 0, width: '100%',
          }}
          rows={2}
        />
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Bottom actions
// ─────────────────────────────────────────────────────────────
function BottomActions() {
  const { state, dispatch } = useMatch();
  const leftTk = state.sidesSwapped ? 'e2' : 'e1';
  const rightTk = state.sidesSwapped ? 'e1' : 'e2';
  const btnStyle = (tk) => {
    const isE1 = tk === 'e1';
    return {
      all: 'unset', flex: 1, cursor: 'pointer',
      background: isE1 ? MH.themSoft : MH.usSoft,
      border: `2px solid ${isE1 ? MH.them : MH.us}`,
      borderRadius: 12, padding: '14px 8px', textAlign: 'center',
    };
  };
  const labelColor = (tk) => tk === 'e1' ? MH.them : MH.us;
  return (
    <div style={{ padding: '8px 14px 14px' }}>
      <div style={{ display: 'flex', gap: 10 }}>
        <button
          onClick={() => dispatch({ type: 'ADD_POINT', winner: leftTk, annotations: [{ type: 'manual', text: `+1 ${state.teams[leftTk].name} (manuel)` }] })}
          style={btnStyle(leftTk)}>
          <div style={{ fontSize: 10, fontWeight: 600, color: labelColor(leftTk), letterSpacing: 0.5 }}>+ POINT</div>
          <div style={{ fontSize: 15, fontWeight: 700, color: labelColor(leftTk) }}>{state.teams[leftTk].name}</div>
        </button>
        <button
          onClick={() => dispatch({ type: 'ADD_POINT', winner: rightTk, annotations: [{ type: 'manual', text: `+1 ${state.teams[rightTk].name} (manuel)` }] })}
          style={btnStyle(rightTk)}>
          <div style={{ fontSize: 10, fontWeight: 600, color: labelColor(rightTk), letterSpacing: 0.5 }}>+ POINT</div>
          <div style={{ fontSize: 15, fontWeight: 700, color: labelColor(rightTk) }}>{state.teams[rightTk].name}</div>
        </button>
      </div>
      <div style={{ height: 8 }}/>
      <button
        onClick={() => dispatch({ type: 'UNDO_POINT' })}
        disabled={state.history.length === 0}
        style={{
          all: 'unset', width: '100%', boxSizing: 'border-box', cursor: state.history.length === 0 ? 'not-allowed' : 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          padding: '10px 8px', border: `1.5px solid ${MH.inkSoft}`,
          background: MH.paper, borderRadius: 8,
          fontSize: 12, fontWeight: 600, color: MH.inkSoft,
          opacity: state.history.length === 0 ? 0.4 : 1,
        }}>↶ Annuler le dernier point</button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Help hint overlay (dismissible)
// ─────────────────────────────────────────────────────────────
function HelpHint() {
  const [open, setOpen] = useState(true);
  if (!open) {
    return (
      <button onClick={() => setOpen(true)} style={{
        all: 'unset', position: 'absolute', top: 8, right: 8,
        width: 22, height: 22, borderRadius: '50%',
        background: MH.ink, color: MH.paper,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 12, fontWeight: 700, cursor: 'pointer', zIndex: 20,
      }}>?</button>
    );
  }
  return (
    <div style={{
      position: 'absolute', top: 50, left: 14, right: 14,
      background: MH.ink, color: MH.paper, borderRadius: 10,
      padding: '10px 12px', zIndex: 20, fontSize: 11, lineHeight: 1.5,
      animation: 'meeHawkFadeIn 0.15s',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 6 }}>
        <strong style={{ fontSize: 11, letterSpacing: 0.5 }}>GESTES</strong>
        <div style={{ flex: 1 }}/>
        <button onClick={() => setOpen(false)} style={{
          all: 'unset', cursor: 'pointer', fontSize: 16, opacity: 0.6,
        }}>×</button>
      </div>
      <div>· <b>Appui</b> terrain adverse → réception</div>
      <div>· <b>Appui prolongé</b> terrain adverse → attaque (point)</div>
      <div>· <b>Appui prolongé</b> joueur → faute (point adverse)</div>
      <div>· <b>Appui prolongé + glisse</b> joueur → repositionner</div>
      <div>· <b>Appui</b> timeline → replay du point</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Tweaks panel
// ─────────────────────────────────────────────────────────────
// (left as a simple noop for now — timeline variant tweak could go here later)

// ─────────────────────────────────────────────────────────────
// Change-side prompt (beach volley — every 7 points)
// ─────────────────────────────────────────────────────────────
function ChangeSidePrompt() {
  const { state, dispatch } = useMatch();
  if (!state.changeSidePromptOpen) return null;
  const score = currentScore(state);
  const total = score.e1 + score.e2;
  return (
    <div style={{
      position: 'absolute', inset: 0, background: 'rgba(20,18,16,0.55)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      zIndex: 40, padding: 22, animation: 'meeHawkFadeIn 0.15s ease-out',
    }}>
      <div style={{
        width: '100%', background: MH.paper, borderRadius: 16,
        padding: '18px 16px 14px', border: `2px solid ${MH.ink}`,
        boxShadow: '0 20px 40px rgba(0,0,0,0.25)',
      }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '3px 9px', borderRadius: 999,
          background: MH.ballSoft, border: `1.5px solid ${MH.ball}`,
          fontSize: 10, fontWeight: 700, color: MH.ball, letterSpacing: 0.5,
        }}>
          <BallIcon size={11}/> {total} POINTS JOUÉS
        </div>
        <div style={{ fontSize: 18, fontWeight: 700, color: MH.ink, marginTop: 10, lineHeight: 1.25 }}>
          Changement de côté ?
        </div>
        <div style={{ fontSize: 12, color: MH.inkSoft, marginTop: 4, lineHeight: 1.45 }}>
          Au beach volley, les équipes changent de côté tous les 7 points pour équilibrer vent et soleil.
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 14 }}>
          <button
            onClick={() => dispatch({ type: 'SWAP_SIDES' })}
            style={{
              all: 'unset', cursor: 'pointer', textAlign: 'center',
              background: MH.ink, color: MH.paper, padding: '11px 10px',
              borderRadius: 10, fontSize: 13, fontWeight: 700,
            }}>
            Changer de côté
          </button>
          <button
            onClick={() => dispatch({ type: 'DISMISS_CHANGE_SIDE_FOREVER' })}
            style={{
              all: 'unset', cursor: 'pointer', textAlign: 'center',
              border: `1.5px solid ${MH.inkSoft}`, color: MH.ink,
              padding: '9px 10px', borderRadius: 10,
              fontSize: 12, fontWeight: 600,
            }}>
            Ne pas changer de côté
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Main App
// ─────────────────────────────────────────────────────────────
function Screen() {
  return (
    <div style={{ width: '100%', height: '100%', background: MH.paper, display: 'flex', flexDirection: 'column', position: 'relative' }}>
      <HelpHint/>
      <TopScore/>
      <ServeBanner/>
      <Court/>
      <Timeline/>
      <ReplayPanel/>
      <Notes/>
      <div style={{ flex: 1 }}/>
      <BottomActions/>
      <ChangeSidePrompt/>
    </div>
  );
}

function ProtoApp() {
  return (
    <MatchProvider>
      <PhoneShell>
        <Screen/>
      </PhoneShell>
    </MatchProvider>
  );
}

Object.assign(window, { ProtoApp });
