/// Layout constants shared by the court widget and anything that has to line
/// up with it (server banner, player dots).
///
/// The court is drawn as an inner playing area inset by [kCourtMargin] inside
/// an outer band. Taps in that band mean "out of bounds" or, on the serving
/// team's side, "server position" — so the margin is a hit-testing constant as
/// much as a visual one.
library;

/// Width of the out-of-bounds band around the playing area, in logical pixels.
const kCourtMargin = 28.0;

/// Widest the court is ever drawn. Past this the court stops growing and
/// centres instead, so it stays thumb-reachable on a tablet.
const kCourtMaxWidth = 720.0;
