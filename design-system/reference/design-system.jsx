// MeeHawk design system — mid-fi sketchy, Google-inspired simplicity
// Volleyball-sport aesthetic, warm sand court + ink black + one terracotta accent.

const MH = {
  // Palette
  sand:      '#F5F1E8',   // court-sand background
  paper:     '#FFFEFB',   // card surface
  ink:       '#1A1A1A',   // primary text / strokes
  inkSoft:   '#3D3D3D',   // secondary text
  pencil:    '#6B6B6B',   // tertiary / hints
  rule:      '#D4CFC1',   // hairline rules, court lines
  ruleSoft:  '#E8E2D2',   // very subtle dividers

  // Accent (volley / whistle)
  ball:      '#E4662A',   // terracotta-orange, the volleyball
  ballSoft:  '#FBE9DD',   // tinted bg

  // Semantic — teams / outcomes
  us:        '#2E7D57',   // court green
  usSoft:    '#DDEEE3',
  them:      '#B33A3A',   // opponent red
  themSoft:  '#F3DADA',

  // Quality scale (for reception / attack quality)
  good:      '#2E7D57',
  mid:       '#C88A2E',
  bad:       '#B33A3A',

  // Type
  fontSans: '"Google Sans", "Roboto", system-ui, -apple-system, sans-serif',
  fontHand: '"Caveat", "Comic Sans MS", cursive',
  fontMono: '"Rubik", "Google Sans", system-ui, sans-serif',

  // Spacing rhythm
  s1: 4, s2: 8, s3: 12, s4: 16, s5: 20, s6: 24, s8: 32, s10: 40,

  // Sketchy borders (the "hand-drawn" feel)
  strokeDashed: '2px dashed #1A1A1A',
  strokeThin:   '1.5px solid #1A1A1A',
  strokeThick:  '2.5px solid #1A1A1A',
};

// Sketchy rectangle — slight wobble via filter, rounded corners, ink stroke
function SketchBox({ children, style = {}, dashed = false, thick = false, fill = MH.paper, radius = 10 }) {
  return (
    <div style={{
      background: fill,
      border: dashed ? `2px dashed ${MH.ink}` : (thick ? `2.5px solid ${MH.ink}` : `1.8px solid ${MH.ink}`),
      borderRadius: radius,
      position: 'relative',
      ...style,
    }}>
      {children}
    </div>
  );
}

// Handwritten label — for sketchy callouts. Default is now softer/less manuscrit:
// Caveat stays reserved for labels/annotations on the court itself; general hints
// use Google Sans italic.
function HandLabel({ children, color = MH.ink, size = 18, style = {}, script = false }) {
  return (
    <span style={{
      fontFamily: script ? MH.fontHand : MH.fontSans,
      fontSize: size, lineHeight: 1.1,
      color, fontWeight: script ? 600 : 500,
      fontStyle: script ? 'normal' : 'italic',
      letterSpacing: script ? 0 : -0.2,
      ...style,
    }}>{children}</span>
  );
}

// Monospace label — small-caps style info
function MonoLabel({ children, color = MH.pencil, size = 10, style = {} }) {
  return (
    <span style={{
      fontFamily: MH.fontMono,
      fontSize: size, letterSpacing: 1,
      textTransform: 'uppercase',
      color, fontWeight: 500,
      ...style,
    }}>{children}</span>
  );
}

// Pill-style chip button, sketchy
function Chip({ children, active = false, color = MH.ink, style = {}, onClick }) {
  return (
    <div onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      padding: '6px 12px',
      border: `1.8px solid ${color}`,
      borderRadius: 999,
      background: active ? color : 'transparent',
      color: active ? MH.paper : color,
      fontFamily: MH.fontSans, fontSize: 13, fontWeight: 600,
      cursor: onClick ? 'pointer' : 'default',
      userSelect: 'none',
      ...style,
    }}>{children}</div>
  );
}

// Simple volleyball glyph — circle with two arcs
function BallIcon({ size = 20, color = MH.ball }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="10" stroke={color} strokeWidth="1.8" fill="none"/>
      <path d="M4 8c3 2 10 3 16-2" stroke={color} strokeWidth="1.4" fill="none" strokeLinecap="round"/>
      <path d="M7 21c-1-4 1-11 6-16" stroke={color} strokeWidth="1.4" fill="none" strokeLinecap="round"/>
      <path d="M22 14c-5 1-12 0-16 6" stroke={color} strokeWidth="1.4" fill="none" strokeLinecap="round"/>
    </svg>
  );
}

Object.assign(window, { MH, SketchBox, HandLabel, MonoLabel, Chip, BallIcon });
