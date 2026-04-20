// MeeHawk — Wireframe match (gestures version)
// - Service: tap sur le côté adverse = point de réception
// - Point gagnant: long-press sur le terrain adverse → popup types d'attaque
// - Faute: long-press sur un joueur NOUS → popup types de faute
// - Pas de zones prédéfinies sur le terrain

const W = { w: 390, h: 844 };

function AppBar() {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '10px 8px 8px', borderBottom: `1px solid ${MH.ruleSoft}`, background: MH.paper,
    }}>
      <button style={{ all: 'unset', cursor: 'pointer', padding: 8 }}>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
          <path d="M18 6L6 18M6 6l12 12" stroke={MH.inkSoft} strokeWidth="2" strokeLinecap="round"/>
        </svg>
      </button>
      <div style={{ fontFamily: MH.fontSans, fontSize: 12, fontWeight: 500, color: MH.inkSoft, letterSpacing: 0.3 }}>
        SET 1 · 21 pts
      </div>
      <button style={{ all: 'unset', cursor: 'pointer', padding: 8 }}>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
          <path d="M3 12a9 9 0 1 0 3-6.7M3 3v6h6" stroke={MH.inkSoft} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </button>
    </div>
  );
}

function Score() {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', padding: '10px 14px 12px',
      background: MH.paper, borderBottom: `1px solid ${MH.rule}`, gap: 8,
    }}>
      {/* Equipe 1 */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 10 }}>
        <div style={{ textAlign: 'right' }}>
          <div style={{
            fontFamily: MH.fontSans, fontSize: 11, fontWeight: 700, color: MH.them, letterSpacing: 0.6,
            display: 'inline-flex', alignItems: 'center', gap: 4,
          }}>
            <span>ÉQUIPE 1</span>
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none"><path d="M16 4l4 4-11 11H5v-4L16 4z" stroke={MH.pencil} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div style={{ fontFamily: MH.fontSans, fontSize: 10, color: MH.pencil, marginTop: 2 }}>
            <span style={{ borderBottom: `1px dashed ${MH.rule}` }}>Ana</span>
            {' · '}
            <span style={{ borderBottom: `1px dashed ${MH.rule}` }}>Sara</span>
          </div>
        </div>
        <div style={{ fontFamily: MH.fontSans, fontSize: 34, fontWeight: 700, color: MH.ink, lineHeight: 1, minWidth: 32, textAlign: 'center' }}>11</div>
      </div>
      <div style={{ color: MH.rule, fontFamily: MH.fontSans, fontSize: 18 }}>·</div>
      {/* Equipe 2 */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ fontFamily: MH.fontSans, fontSize: 34, fontWeight: 700, color: MH.ink, lineHeight: 1, minWidth: 32, textAlign: 'center' }}>14</div>
        <div>
          <div style={{
            fontFamily: MH.fontSans, fontSize: 11, fontWeight: 700, color: MH.us, letterSpacing: 0.6,
            display: 'inline-flex', alignItems: 'center', gap: 4,
          }}>
            <span>ÉQUIPE 2</span>
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none"><path d="M16 4l4 4-11 11H5v-4L16 4z" stroke={MH.pencil} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div style={{ fontFamily: MH.fontSans, fontSize: 10, color: MH.pencil, marginTop: 2 }}>
            <span style={{ borderBottom: `1px dashed ${MH.rule}` }}>Léa</span>
            {' · '}
            <span style={{ borderBottom: `1px dashed ${MH.rule}` }}>Marie</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Court — paysage, sans zones. Montre les gestes possibles selon le mode d'affichage.
// mode = 'serve' (ligne trace) | 'attack' (long-press adv) | 'fault' (long-press us) | 'idle'
// ─────────────────────────────────────────────────────────────
function Court({ height = 220, mode = 'serve' }) {
  return (
    <div style={{
      position: 'relative', width: '100%', height,
      background: MH.sand, border: `2px solid ${MH.ink}`, borderRadius: 6, overflow: 'hidden',
    }}>
      {/* Sand texture */}
      <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
        <defs>
          <pattern id="sand3" x="0" y="0" width="8" height="8" patternUnits="userSpaceOnUse">
            <circle cx="2" cy="2" r="0.6" fill={MH.pencil}/>
            <circle cx="6" cy="5" r="0.4" fill={MH.pencil}/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#sand3)"/>
      </svg>

      <div style={{ position: 'absolute', inset: 6, border: `1.5px dashed ${MH.inkSoft}`, opacity: 0.3, borderRadius: 2 }}/>

      {/* Filet */}
      <div style={{ position: 'absolute', top: 0, bottom: 0, left: '50%', width: 3, background: MH.ink, transform: 'translateX(-50%)' }}/>
      <div style={{
        position: 'absolute', top: 0, bottom: 0, left: '50%', width: 14, transform: 'translateX(-50%)',
        backgroundImage: `repeating-linear-gradient(0deg, ${MH.ink} 0 2px, transparent 2px 6px)`, opacity: 0.45,
      }}/>

      {/* Camp labels — sporty, condensed, uppercase */}
      <div style={{ position: 'absolute', top: 8, left: 12, fontFamily: MH.fontSans, fontSize: 12, color: MH.them, fontWeight: 700, letterSpacing: 1.5 }}>ÉQUIPE 1</div>
      <div style={{ position: 'absolute', top: 8, right: 12, fontFamily: MH.fontSans, fontSize: 12, color: MH.us, fontWeight: 700, letterSpacing: 1.5 }}>ÉQUIPE 2</div>

      {/* Players — full names, centered symmetrically. Long-press on a player = reposition. */}
      <Dot x={0.25} y={0.35} label="Ana" color={MH.them}/>
      <Dot x={0.25} y={0.70} label="Sara" color={MH.them}/>
      <Dot x={0.75} y={0.35} label="Léa" color={MH.us} serving={mode === 'serve'} pulseIf={mode === 'fault'}/>
      <Dot x={0.75} y={0.70} label="Marie" color={MH.us} dragHint={mode === 'idle' || mode === 'reposition'}/>

      {/* MODE: serve — simple tap on opposite court = réception point */}
      {mode === 'serve' && (
        <div style={{
          position: 'absolute', left: '32%', top: '58%', transform: 'translate(-50%, -50%)',
          width: 36, height: 36, borderRadius: '50%',
          border: `2.5px solid ${MH.ball}`, background: MH.ballSoft,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          animation: 'meeHawkPulse 1.5s ease-in-out infinite',
        }}>
          <BallIcon size={16}/>
        </div>
      )}

      {/* MODE: attack — long-press on adversary court */}
      {mode === 'attack' && (
        <div style={{
          position: 'absolute', left: '35%', top: '55%', transform: 'translate(-50%, -50%)',
          width: 44, height: 44, borderRadius: '50%',
          border: `2.5px solid ${MH.ball}`, background: MH.ballSoft,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          animation: 'meeHawkPulse 1.5s ease-in-out infinite',
        }}>
          <div style={{
            width: 18, height: 18, borderRadius: '50%',
            background: MH.ball, opacity: 0.8,
          }}/>
        </div>
      )}

      {/* MODE: fault — long-press on our player (Léa pulses) */}
      {mode === 'fault' && (
        <div style={{
          position: 'absolute', left: '76%', top: '55%', transform: 'translate(-50%, -50%)',
          width: 50, height: 50, borderRadius: '50%',
          border: `2.5px solid ${MH.them}`, background: 'transparent',
          animation: 'meeHawkPulse 1.5s ease-in-out infinite', pointerEvents: 'none',
        }}/>
      )}
    </div>
  );
}

function Dot({ x, y, label, color, serving = false, pulseIf = false, dragHint = false }) {
  // Pill now holds a full name
  const paddingH = serving ? 10 : 8;
  return (
    <div style={{
      position: 'absolute', left: `${x * 100}%`, top: `${y * 100}%`,
      transform: 'translate(-50%, -50%)',
      minWidth: 48, padding: `5px ${paddingH}px`, borderRadius: 999,
      background: MH.paper, border: `2px solid ${color}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
      fontFamily: MH.fontSans, fontSize: 11, fontWeight: 700, color,
      boxShadow: serving ? `0 0 0 3px ${MH.ballSoft}` : 'none',
      zIndex: 2, whiteSpace: 'nowrap',
    }}>
      {label}
      {dragHint && (
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.55 }}>
          <circle cx="9" cy="6" r="1.3" fill={color}/><circle cx="15" cy="6" r="1.3" fill={color}/>
          <circle cx="9" cy="12" r="1.3" fill={color}/><circle cx="15" cy="12" r="1.3" fill={color}/>
          <circle cx="9" cy="18" r="1.3" fill={color}/><circle cx="15" cy="18" r="1.3" fill={color}/>
        </svg>
      )}
      {serving && (
        <div style={{ position: 'absolute', top: -14, left: '50%', transform: 'translateX(-50%)' }}>
          <BallIcon size={12}/>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Popup d'attaque (long-press sur terrain adverse)
// ─────────────────────────────────────────────────────────────
function AttackPopup({ anchorX = '22%', anchorY = '55%' }) {
  const types = [
    { id: 'cut', label: 'Cut' },
    { id: 'line', label: 'Line' },
    { id: 'shot', label: 'Shot' },
    { id: 'power', label: 'Power' },
    { id: 'ace', label: 'Ace' },
    { id: 'block', label: 'Bloc' },
  ];
  return (
    <div style={{
      position: 'absolute', left: anchorX, top: anchorY,
      transform: 'translate(-50%, -115%)',
      background: MH.paper, border: `2px solid ${MH.ink}`, borderRadius: 12,
      padding: 10, minWidth: 200,
      boxShadow: '0 8px 24px rgba(0,0,0,0.18)', zIndex: 10,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
        <div style={{ width: 8, height: 8, borderRadius: '50%', background: MH.ball }}/>
        <MonoLabel size={9} color={MH.inkSoft}>Point gagnant — type d'attaque</MonoLabel>
      </div>
      {/* Player switcher */}
      <div style={{ display: 'flex', gap: 4, marginBottom: 8 }}>
        <button style={{
          all: 'unset', cursor: 'pointer', flex: 1,
          padding: '5px 8px', textAlign: 'center',
          border: `1.5px solid ${MH.us}`, background: MH.usSoft,
          borderRadius: 6, fontFamily: MH.fontSans, fontSize: 11, fontWeight: 700, color: MH.us,
        }}>Léa</button>
        <button style={{
          all: 'unset', cursor: 'pointer', flex: 1,
          padding: '5px 8px', textAlign: 'center',
          border: `1.5px solid ${MH.rule}`, background: MH.paper,
          borderRadius: 6, fontFamily: MH.fontSans, fontSize: 11, fontWeight: 500, color: MH.inkSoft,
        }}>Marie</button>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 4 }}>
        {types.map(t => (
          <button key={t.id} style={{
            all: 'unset', cursor: 'pointer',
            padding: '8px 6px', textAlign: 'center',
            border: `1.5px solid ${MH.ink}`, background: t.id === 'line' ? MH.ballSoft : MH.paper,
            borderColor: t.id === 'line' ? MH.ball : MH.ink,
            color: t.id === 'line' ? MH.ball : MH.ink,
            borderRadius: 6, fontFamily: MH.fontSans, fontSize: 12, fontWeight: 600,
          }}>{t.label}</button>
        ))}
      </div>
      {/* Pointer tail */}
      <div style={{
        position: 'absolute', left: '50%', bottom: -8,
        transform: 'translateX(-50%) rotate(45deg)',
        width: 14, height: 14, background: MH.paper,
        borderRight: `2px solid ${MH.ink}`, borderBottom: `2px solid ${MH.ink}`,
      }}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Popup de faute (long-press sur joueur NOUS)
// ─────────────────────────────────────────────────────────────
function FaultPopup({ anchorX = '76%', anchorY = '55%' }) {
  const types = [
    { id: 'serve', label: 'Service', important: true },
    { id: 'net', label: 'Filet' },
    { id: 'double', label: 'Double' },
    { id: 'out', label: 'Out' },
    { id: 'foot', label: 'Pied' },
    { id: 'other', label: 'Autre' },
  ];
  return (
    <div style={{
      position: 'absolute', left: anchorX, top: anchorY,
      transform: 'translate(-50%, -115%)',
      background: MH.paper, border: `2px solid ${MH.them}`, borderRadius: 12,
      padding: 10, minWidth: 190,
      boxShadow: '0 8px 24px rgba(0,0,0,0.18)', zIndex: 10,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
        <div style={{ width: 8, height: 8, borderRadius: '50%', background: MH.them }}/>
        <MonoLabel size={9} color={MH.them}>Faute — Léa</MonoLabel>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 4 }}>
        {types.map(t => (
          <button key={t.id} style={{
            all: 'unset', cursor: 'pointer',
            padding: '8px 6px', textAlign: 'center',
            border: `1.5px solid ${t.important ? MH.them : MH.rule}`,
            background: t.important ? MH.themSoft : MH.paper,
            color: t.important ? MH.them : MH.ink,
            borderRadius: 6, fontFamily: MH.fontSans, fontSize: 12, fontWeight: 600,
          }}>{t.label}</button>
        ))}
      </div>
      <div style={{
        position: 'absolute', left: '50%', bottom: -8,
        transform: 'translateX(-50%) rotate(45deg)',
        width: 14, height: 14, background: MH.paper,
        borderRight: `2px solid ${MH.them}`, borderBottom: `2px solid ${MH.them}`,
      }}/>
    </div>
  );
}

// Instruction coachmark (bottom)
function GestureHint({ mode }) {
  const hints = {
    serve: { icon: '●', text: 'Tape le côté adverse pour marquer le point de réception' },
    attack: { icon: '●', text: 'Appui long sur le terrain adverse → choisir type d\'attaque' },
    fault: { icon: '●', text: 'Appui long sur un de tes joueurs → type de faute' },
    reposition: { icon: '⤳', text: 'Appui long maintenu sur un joueur → glisse pour repositionner' },
    idle: { icon: '✎', text: 'Trace, appuie, annote' },
  };
  const h = hints[mode] || hints.idle;
  return (
    <div style={{
      padding: '10px 14px', background: MH.paper,
      display: 'flex', alignItems: 'center', gap: 10,
      border: `1.5px dashed ${MH.rule}`, borderRadius: 10, margin: '10px 14px 0',
    }}>
      <div style={{
        width: 28, height: 28, borderRadius: '50%', background: MH.ballSoft,
        border: `1.5px solid ${MH.ball}`, display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: MH.fontSans, fontSize: 14, color: MH.ball, fontWeight: 700,
      }}>{h.icon}</div>
      <div style={{ fontFamily: MH.fontSans, fontSize: 12, color: MH.ink, lineHeight: 1.35 }}>{h.text}</div>
    </div>
  );
}

// Big point buttons at bottom
function NoteField() {
  return (
    <div style={{ padding: '8px 14px 6px' }}>
      <div style={{
        display: 'flex', flexDirection: 'column', gap: 4,
        padding: '10px 12px 12px', background: MH.paper,
        border: `1.5px dashed ${MH.rule}`, borderRadius: 10,
        minHeight: 68,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
            <path d="M16 4l4 4-11 11H5v-4L16 4z" stroke={MH.pencil} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          <span style={{
            fontFamily: MH.fontSans, fontSize: 9, fontWeight: 600, color: MH.pencil,
            letterSpacing: 0.5, textTransform: 'uppercase',
          }}>Notes</span>
        </div>
        <span style={{
          flex: 1, fontFamily: MH.fontSans, fontSize: 13, color: MH.inkSoft, lineHeight: 1.4,
        }}>
          Vent de dos, Ana fatigue au filet. Marie très solide en défense auj.
        </span>
      </div>
    </div>
  );
}

// Replay panel — appears when user taps a point in the timeline. Shows what happened during that exchange.
function PointReplay() {
  return (
    <div style={{ padding: '0 14px 8px' }}>
      <div style={{
        background: MH.ink, color: MH.paper, borderRadius: 10,
        padding: '10px 12px', position: 'relative',
      }}>
        {/* Pointer up to the timeline */}
        <div style={{
          position: 'absolute', top: -6, left: '32%',
          width: 10, height: 10, background: MH.ink,
          transform: 'rotate(45deg)',
        }}/>

        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
          <span style={{
            fontFamily: MH.fontSans, fontSize: 9, fontWeight: 700, letterSpacing: 0.6,
            padding: '1px 6px', borderRadius: 3,
            background: MH.us, color: MH.paper,
          }}>ÉCHANGE 14</span>
          <span style={{ fontFamily: MH.fontSans, fontSize: 10, opacity: 0.6 }}>8–7</span>
          <div style={{ flex: 1 }}/>
          <span style={{
            fontFamily: MH.fontSans, fontSize: 9, fontWeight: 600, letterSpacing: 0.4,
            textTransform: 'uppercase', color: MH.ball,
          }}>Point Équipe 2</span>
        </div>

        {/* Annotations list */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
          <div style={{ display: 'flex', gap: 6, fontFamily: MH.fontSans, fontSize: 11, lineHeight: 1.3 }}>
            <span style={{ opacity: 0.5 }}>·</span>
            <span>Service <b style={{ color: MH.ball }}>Léa</b> → réception longue côté Ana</span>
          </div>
          <div style={{ display: 'flex', gap: 6, fontFamily: MH.fontSans, fontSize: 11, lineHeight: 1.3 }}>
            <span style={{ opacity: 0.5 }}>·</span>
            <span>Attaque <b style={{ color: MH.us }}>Marie</b> — <i>Cut</i> gagnant diagonale</span>
          </div>
          <div style={{ display: 'flex', gap: 6, fontFamily: MH.fontHand, fontSize: 13, color: MH.ballSoft, lineHeight: 1.25, marginTop: 2 }}>
            <span style={{ opacity: 0.5 }}>✎</span>
            <span>Sara mal placée, appel trop tard</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function PointsTimeline({ variant = 'bars', activeIndex = null }) {
  // Derived from score history: automatically reflects the point counter + its history.
  const fullHistory = ['us','them','us','us','them','us','them','them','us','them','us','us','us','them','them','us','us','them','us','us','us','them','us','them','us','them','us','us','them','us','us','them','us'];
  // Adaptive: keep slots >= 10px; if too many points, scroll horizontally with auto-scroll to the right.
  const MAX_VISIBLE = 22;
  const hidden = Math.max(0, fullHistory.length - MAX_VISIBLE);
  const history = hidden > 0 ? fullHistory.slice(-MAX_VISIBLE) : fullHistory;

  const HiddenBadge = () => hidden > 0 ? (
    <span style={{
      flexShrink: 0, fontFamily: MH.fontSans, fontSize: 9, color: MH.pencil, fontWeight: 600,
      padding: '1px 5px', borderRadius: 3, background: MH.ruleSoft,
    }}>←{hidden}</span>
  ) : null;

  if (variant === 'bars') {
    // Two parallel rows. Point goes on the side of the team that won the rally.
    return (
      <div style={{ padding: '8px 14px 2px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          {/* Équipe 1 (top) */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ width: 22, fontFamily: MH.fontSans, fontSize: 9, color: MH.them, fontWeight: 700, letterSpacing: 0.4 }}>E1</span>
            <HiddenBadge/>
            <div style={{ flex: 1, display: 'flex', gap: 2 }}>
              {history.map((p, i) => {
                const active = activeIndex === i;
                return (
                  <div key={i} style={{
                    flex: '1 1 0', minWidth: 4, height: 10, borderRadius: 2,
                    background: p === 'them' ? MH.them : 'transparent',
                    border: p === 'them' ? 'none' : `1px dashed ${MH.rule}`,
                    boxShadow: active && p === 'them' ? `0 0 0 2px ${MH.paper}, 0 0 0 3px ${MH.ink}` : 'none',
                    outline: active && p !== 'them' ? `1.5px solid ${MH.ink}` : 'none',
                  }}/>
                );
              })}
            </div>
          </div>
          {/* Équipe 2 (bottom) */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ width: 22, fontFamily: MH.fontSans, fontSize: 9, color: MH.us, fontWeight: 700, letterSpacing: 0.4 }}>E2</span>
            {hidden > 0 && <span style={{ width: 22 }}/>}
            <div style={{ flex: 1, display: 'flex', gap: 2 }}>
              {history.map((p, i) => {
                const active = activeIndex === i;
                return (
                  <div key={i} style={{
                    flex: '1 1 0', minWidth: 4, height: 10, borderRadius: 2,
                    background: p === 'us' ? MH.us : 'transparent',
                    border: p === 'us' ? 'none' : `1px dashed ${MH.rule}`,
                    boxShadow: active && p === 'us' ? `0 0 0 2px ${MH.paper}, 0 0 0 3px ${MH.ink}` : 'none',
                    outline: active && p !== 'us' ? `1.5px solid ${MH.ink}` : 'none',
                  }}/>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (variant === 'dots') {
    // Two rows of dots; dot on the winner's row, empty slot on the loser's.
    return (
      <div style={{ padding: '8px 14px 2px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 22, fontFamily: MH.fontSans, fontSize: 9, color: MH.them, fontWeight: 700 }}>E1</span>
            <div style={{ flex: 1, display: 'flex', gap: 2, alignItems: 'center' }}>
              {history.map((p, i) => (
                <div key={i} style={{ flex: '1 1 0', display: 'flex', justifyContent: 'center' }}>
                  <div style={{
                    width: 8, height: 8, borderRadius: '50%',
                    background: p === 'them' ? MH.them : 'transparent',
                    border: p === 'them' ? 'none' : `1px solid ${MH.ruleSoft}`,
                  }}/>
                </div>
              ))}
            </div>
          </div>
          <div style={{ height: 1, background: MH.ruleSoft, marginLeft: 28 }}/>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 22, fontFamily: MH.fontSans, fontSize: 9, color: MH.us, fontWeight: 700 }}>E2</span>
            <div style={{ flex: 1, display: 'flex', gap: 2, alignItems: 'center' }}>
              {history.map((p, i) => (
                <div key={i} style={{ flex: '1 1 0', display: 'flex', justifyContent: 'center' }}>
                  <div style={{
                    width: 8, height: 8, borderRadius: '50%',
                    background: p === 'us' ? MH.us : 'transparent',
                    border: p === 'us' ? 'none' : `1px solid ${MH.ruleSoft}`,
                  }}/>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (variant === 'ticks') {
    // Central baseline, each rally is a vertical tick going UP (E1) or DOWN (E2).
    return (
      <div style={{ padding: '10px 14px 4px' }}>
        <div style={{ position: 'relative', height: 32, display: 'flex', alignItems: 'center' }}>
          <div style={{ position: 'absolute', left: 0, right: 0, top: '50%', height: 1, background: MH.ink, opacity: 0.4 }}/>
          <div style={{ display: 'flex', gap: 2, width: '100%', height: '100%', position: 'relative' }}>
            {history.map((p, i) => (
              <div key={i} style={{ flex: '1 1 0', minWidth: 3, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
                {p === 'them' && <div style={{ width: '100%', maxWidth: 6, height: 14, background: MH.them, borderRadius: 1, marginBottom: 16 }}/>}
                {p === 'us' && <div style={{ width: '100%', maxWidth: 6, height: 14, background: MH.us, borderRadius: 1, marginTop: 16 }}/>}
              </div>
            ))}
          </div>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: MH.fontSans, fontSize: 9, color: MH.pencil, marginTop: -2 }}>
          <span style={{ color: MH.them }}>↑ Équipe 1</span>
          <span style={{ color: MH.us }}>↓ Équipe 2</span>
        </div>
      </div>
    );
  }

  if (variant === 'stacked') {
    // Single row; position-within-slot tells the story: top half = E1, bottom half = E2.
    return (
      <div style={{ padding: '10px 14px 2px' }}>
        <div style={{ display: 'flex', alignItems: 'stretch', gap: 2, height: 22 }}>
          {history.map((p, i) => (
            <div key={i} style={{
              flex: '1 1 0', minWidth: 4, display: 'flex', flexDirection: 'column',
              background: MH.paper, border: `1px solid ${MH.ruleSoft}`, borderRadius: 2, overflow: 'hidden',
            }}>
              <div style={{ flex: 1, background: p === 'them' ? MH.them : 'transparent' }}/>
              <div style={{ flex: 1, background: p === 'us' ? MH.us : 'transparent' }}/>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return null;
}

function PointButtons() {
  return (
    <div style={{ display: 'flex', gap: 10 }}>
      <button style={{
        all: 'unset', flex: 1, cursor: 'pointer',
        background: MH.themSoft, border: `2px solid ${MH.them}`,
        borderRadius: 12, padding: '14px 8px', textAlign: 'center',
      }}>
        <div style={{ fontFamily: MH.fontSans, fontSize: 10, fontWeight: 600, color: MH.them, letterSpacing: 0.5 }}>+ POINT</div>
        <div style={{ fontFamily: MH.fontSans, fontSize: 15, fontWeight: 700, color: MH.them }}>Équipe 1</div>
      </button>
      <button style={{
        all: 'unset', flex: 1, cursor: 'pointer',
        background: MH.usSoft, border: `2px solid ${MH.us}`,
        borderRadius: 12, padding: '14px 8px', textAlign: 'center',
      }}>
        <div style={{ fontFamily: MH.fontSans, fontSize: 10, fontWeight: 600, color: MH.us, letterSpacing: 0.5 }}>+ POINT</div>
        <div style={{ fontFamily: MH.fontSans, fontSize: 15, fontWeight: 700, color: MH.us }}>Équipe 2</div>
      </button>
    </div>
  );
}

function QuickActions() {
  return (
    <div>
      <button style={{
        all: 'unset', width: '100%', boxSizing: 'border-box', cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        padding: '10px 8px', border: `1.5px solid ${MH.inkSoft}`,
        background: MH.paper, borderRadius: 8,
        fontFamily: MH.fontSans, fontSize: 12, fontWeight: 600, color: MH.inkSoft,
      }}>↶ Annuler le dernier point</button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Screens — 3 states: serve / attack-popup / fault-popup
// ─────────────────────────────────────────────────────────────
function Screen({ mode = 'serve', timeline = 'bars', replay = false }) {
  const modeLabels = {
    serve: 'Service — tape le point de réception',
    attack: 'Point gagnant — appui long',
    fault: 'Faute — appui long sur joueur',
    reposition: 'Repositionner — appui long maintenu',
  };
  return (
    <div style={{ width: '100%', height: '100%', background: MH.paper, display: 'flex', flexDirection: 'column' }}>
      <AppBar/>
      <Score/>

      <div style={{ padding: '10px 14px 6px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '4px 10px 4px 8px', background: MH.ballSoft,
          border: `1.5px solid ${MH.ball}`, borderRadius: 999,
          fontFamily: MH.fontSans, fontSize: 11, fontWeight: 600, color: MH.ball,
        }}>
          <BallIcon size={13}/> Léa sert
        </div>
        <div style={{ flex: 1 }}/>
        <button style={{
          all: 'unset', cursor: 'pointer',
          display: 'inline-flex', alignItems: 'center', gap: 5,
          padding: '4px 10px', border: `1.5px solid ${MH.ink}`,
          background: MH.paper, borderRadius: 999,
          fontFamily: MH.fontSans, fontSize: 11, fontWeight: 600, color: MH.ink,
        }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none">
            <path d="M4 12a8 8 0 0 1 14-5.3M20 4v4h-4" stroke={MH.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M20 12a8 8 0 0 1-14 5.3M4 20v-4h4" stroke={MH.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Changer de côté
        </button>
      </div>

      <div style={{ padding: '0 14px', position: 'relative' }}>
        <Court height={300} mode={mode}/>
        {mode === 'attack' && <AttackPopup anchorX="35%" anchorY="52%"/>}
        {mode === 'fault' && <FaultPopup anchorX="76%" anchorY="52%"/>}
        {mode === 'reposition' && <RepositionGhost/>}
      </div>

      <PointsTimeline variant={timeline} activeIndex={replay ? 13 : null}/>

      {replay && <PointReplay/>}

      <NoteField/>

      <div style={{ flex: 1 }}/>

      <div style={{ padding: '8px 14px 14px' }}>
        <PointButtons/>
        <div style={{ height: 8 }}/>
        <QuickActions/>
      </div>
    </div>
  );
}

// Legend — explains gestures & court reading
function Legend() {
  const item = (swatch, text) => (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, fontFamily: MH.fontSans, fontSize: 12, color: MH.inkSoft }}>
      <div style={{ width: 38, flexShrink: 0, display: 'flex', justifyContent: 'center', paddingTop: 2 }}>{swatch}</div>
      <div>{text}</div>
    </div>
  );
  return (
    <div style={{
      width: 320, padding: 20, background: MH.paper,
      border: `2px solid ${MH.ink}`, borderRadius: 12,
      display: 'flex', flexDirection: 'column', gap: 12,
    }}>
      <HandLabel size={20} script>Lecture du terrain</HandLabel>
      <div style={{ fontFamily: MH.fontSans, fontSize: 11, color: MH.pencil, marginTop: -8 }}>
        Paysage · Équipe 1 à gauche · Équipe 2 à droite
      </div>

      {item(
        <div style={{ width: 22, height: 22, borderRadius: '50%', border: `2px solid ${MH.us}`, background: MH.paper, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: MH.fontSans, fontSize: 11, fontWeight: 700, color: MH.us, boxShadow: `0 0 0 3px ${MH.ballSoft}` }}>L</div>,
        'Joueur au ballon = il sert (halo orange).',
      )}
      {item(
        <div style={{ display: 'flex', gap: 3 }}>
          <div style={{ padding: '2px 6px', borderRadius: 999, border: `2px solid ${MH.us}`, fontFamily: MH.fontSans, fontSize: 9, fontWeight: 700, color: MH.us }}>Marie</div>
        </div>,
        'Pastilles joueurs avec nom complet · vert = Équipe 2, rouge = Équipe 1.',
      )}
      {item(
        <div style={{ width: 24, height: 22, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><circle cx="9" cy="6" r="1.3" fill={MH.inkSoft}/><circle cx="15" cy="6" r="1.3" fill={MH.inkSoft}/><circle cx="9" cy="12" r="1.3" fill={MH.inkSoft}/><circle cx="15" cy="12" r="1.3" fill={MH.inkSoft}/><circle cx="9" cy="18" r="1.3" fill={MH.inkSoft}/><circle cx="15" cy="18" r="1.3" fill={MH.inkSoft}/></svg>
        </div>,
        'Poignée : appui long maintenu = glisser pour repositionner.',
      )}
      {item(
        <div style={{ width: 4, height: 22, background: MH.ink }}/>,
        'Filet (ligne verticale centrale).',
      )}
    </div>
  );
}

// Gestures reference card
function GestureCard() {
  const gesture = (glyph, title, desc, color) => (
    <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start', marginBottom: 14 }}>
      <div style={{
        width: 38, height: 38, borderRadius: 10, flexShrink: 0,
        background: MH.paper, border: `2px solid ${color}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 18, color,
      }}>{glyph}</div>
      <div>
        <div style={{ fontFamily: MH.fontSans, fontSize: 13, fontWeight: 700, color: MH.ink }}>{title}</div>
        <div style={{ fontFamily: MH.fontSans, fontSize: 12, color: MH.inkSoft, marginTop: 2, lineHeight: 1.4 }}>{desc}</div>
      </div>
    </div>
  );
  return (
    <div style={{
      width: 320, padding: 20, background: MH.paper,
      border: `2px solid ${MH.ink}`, borderRadius: 12,
    }}>
      <HandLabel size={20} script>Gestes d'annotation</HandLabel>
      <div style={{ marginTop: 14 }}>
        {gesture('●', 'Service', 'Tape le côté adverse pour marquer le point de réception de la balle.', MH.ball)}
        {gesture('●', 'Point gagnant', 'Appui long sur le terrain adverse → pop-up type d\'attaque (Cut, Line, Shot, Power, Ace, Bloc).', MH.us)}
        {gesture('●', 'Faute', 'Appui long sur un joueur de ton équipe → pop-up type de faute (Service, Filet, Double, Out, Pied, Autre).', MH.them)}
        {gesture('⤳', 'Repositionner', 'Appui long maintenu sur un joueur puis glisse pour changer sa position sur le terrain.', MH.ink)}
      </div>
    </div>
  );
}

// Reposition ghost — shows a player being dragged to a new spot
function RepositionGhost() {
  return (
    <>
      {/* Ghost target position */}
      <div style={{
        position: 'absolute', left: '62%', top: '45%', transform: 'translate(-50%, -50%)',
        minWidth: 48, padding: '5px 8px', borderRadius: 999,
        background: MH.paper, border: `2px dashed ${MH.us}`,
        fontFamily: MH.fontSans, fontSize: 11, fontWeight: 700, color: MH.us,
        opacity: 0.55, textAlign: 'center',
      }}>Marie</div>
      {/* Drag trail */}
      <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}>
        <path d="M 62% 45% Q 68% 58% 75% 70%" stroke={MH.us} strokeWidth="1.5" strokeDasharray="3 3" fill="none" opacity="0.6"/>
      </svg>
      {/* Hint bubble */}
      <div style={{
        position: 'absolute', left: '55%', top: '24%', transform: 'translate(-50%, 0)',
        padding: '5px 9px', background: MH.ink, color: MH.paper,
        fontFamily: MH.fontSans, fontSize: 10, fontWeight: 600,
        borderRadius: 6, whiteSpace: 'nowrap',
      }}>Glisse pour repositionner</div>
    </>
  );
}

Object.assign(window, { W, Screen, Legend, GestureCard });
