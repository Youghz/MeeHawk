This clip shows beach volleyball rally #{rally_num} (approx. {duration:.0f}s including a few seconds of margin on each side).

Your tasks:
1. Determine the winner from visual cues only:
   - Ball lands in bounds on opponent's side → attacking team wins.
   - Ball hits the net or lands out → last-touching team loses, opponent wins.
   - If the winning action is not clearly visible, set needs_review=true and explain in review_note.

2. Annotate every ball touch in chronological order:
   - Server starting position: is_server_position=True (player stationary before serve)
   - Every touch: serve, reception, set, attack, block, dig, fault

SHORT RALLY CASES — handle correctly, never invent extra touches:
   • Service fault (serve hits net or lands out):
     → 2 touches only: is_server_position + serve(is_outside=True). Winner = receiving team.
   • Service ace (serve lands untouched in opponent's court):
     → 2 touches only: is_server_position + serve(is_outside=False). Winner = serving team.

Coordinate system: (0,0)=top-left corner, (1,1)=bottom-right corner.
Court sides: e1 = left half (x ≈ 0–0.5) · e2 = right half (x ≈ 0.5–1).
Players: p1 p2 for e1 · p3 p4 for e2.
