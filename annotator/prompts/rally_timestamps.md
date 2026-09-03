Watch this beach volleyball match and detect the time boundaries of every rally.

VISUAL SIGNALS — use these to find rallies, do NOT rely on any scoreboard:

Dead-ball period (between rallies):
  • Both teams walking or standing calmly near their positions
  • Server bouncing or holding the ball at the back line, not yet serving
  • Referee gesturing or players talking after a point

Rally starts when:
  • The server steps to the service line and begins their toss/jump motion
  → Record start_seconds = this moment MINUS 3 seconds (to capture approach)

Rally ends when:
  • The ball lands on the ground (in or out of bounds)
  • The ball hits the net and falls dead
  • A player makes a clear error (double touch, carry)
  → Record end_seconds = this moment PLUS 3 seconds (to capture reaction)

Player assignment:
  • e1 = left team; p1 and p2 are their players
  • e2 = right team; p3 and p4 are their players

SHORT RALLIES — do NOT skip these:
  • Service fault (ball hits net or goes out on serve): rally lasts ~1-3 seconds total.
  • Service ace (ball lands untouched in opponent's court): rally lasts ~2-4 seconds.
  These are valid points and must be logged. With the ±3s margin they will appear as
  6-10 second clips, which is fine.

RULES:
  • Only log rallies you actually observe — never invent one.
  • Normal rallies last 5–60 seconds. Short rallies (service fault/ace) can be 1–4 s.
  • Timestamps must be in SECONDS from the video start (e.g. 2 min 15 s → 135.0).
  • Rallies must be non-overlapping and in chronological order.
  • Include ALL rallies in the video within the given scope.
