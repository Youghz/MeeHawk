/**
 * Top-down schematic view of a beach volleyball court (16m x 8m).
 * Players are shown as colored dots at their projected positions.
 *
 * Props:
 *   players: [{ id, x, y, color }]  — x/y in meters (0,0 = top-left)
 *   width: SVG width in px (default 200)
 */

const COURT_W = 8;   // meters
const COURT_L = 16;  // meters
const PAD = 1;        // meters of padding around the court

const PLAYER_RADIUS = 0.4; // meters

export default function CourtView({ players = [], width = 220 }) {
  const totalW = COURT_W + PAD * 2;
  const totalL = COURT_L + PAD * 2;
  const aspectRatio = totalL / totalW;
  const height = width * aspectRatio;

  // Convert meters to SVG coordinates
  const scale = width / totalW;
  const toX = (m) => (m + PAD) * scale;
  const toY = (m) => (m + PAD) * scale;

  const courtX = toX(0);
  const courtY = toY(0);
  const courtW = COURT_W * scale;
  const courtL = COURT_L * scale;
  const netY = toY(COURT_L / 2);

  return (
    <div className="court-view">
      <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
        {/* Background */}
        <rect width={width} height={height} fill="#1a1a2e" rx="8" />

        {/* Sand */}
        <rect
          x={courtX} y={courtY}
          width={courtW} height={courtL}
          fill="#c2956a" opacity="0.25"
          rx="2"
        />

        {/* Court outline */}
        <rect
          x={courtX} y={courtY}
          width={courtW} height={courtL}
          fill="none" stroke="#c2956a" strokeWidth="2"
          rx="2"
        />

        {/* Net (dashed line at center) */}
        <line
          x1={courtX} y1={netY}
          x2={courtX + courtW} y2={netY}
          stroke="#e0e0e0" strokeWidth="2" strokeDasharray="6,3"
        />

        {/* Net label */}
        <text
          x={courtX + courtW + 6} y={netY + 4}
          fill="#666" fontSize="10" fontFamily="sans-serif"
        >
          net
        </text>

        {/* Side labels */}
        <text x={courtX + courtW / 2} y={courtY - 4} textAnchor="middle"
          fill="#555" fontSize="9" fontFamily="sans-serif">8m</text>
        <text x={courtX - 4} y={courtY + courtL / 2} textAnchor="end"
          fill="#555" fontSize="9" fontFamily="sans-serif"
          transform={`rotate(-90, ${courtX - 6}, ${courtY + courtL / 2})`}>16m</text>

        {/* Players */}
        {players.map((p) => {
          // Clamp to court bounds for display
          const px = Math.max(0, Math.min(COURT_W, p.x));
          const py = Math.max(0, Math.min(COURT_L, p.y));
          return (
            <g key={p.id}>
              <circle
                cx={toX(px)} cy={toY(py)}
                r={PLAYER_RADIUS * scale}
                fill={p.color} opacity="0.9"
                stroke="#fff" strokeWidth="1.5"
              />
              <text
                x={toX(px)} y={toY(py) + 1}
                textAnchor="middle" dominantBaseline="middle"
                fill="#fff" fontSize="10" fontWeight="bold" fontFamily="sans-serif"
              >
                {p.id}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}
