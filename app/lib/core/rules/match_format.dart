/// Rules of a beach-volley match format. Beach FIVB default is:
/// - Best of 3 sets (first to 2 sets wins the match).
/// - Sets 1 & 2 are played to 21 with a 2-point lead.
/// - A deciding set 3 is played to 15 with a 2-point lead.
/// - Sides swap every 7 points of total (sum of both teams) in sets to 21,
///   and every 5 in the tie-break.
class MatchFormat {
  const MatchFormat({
    this.setsToWin = 2,
    this.regularSetPoints = 21,
    this.decidingSetPoints = 15,
    this.winBy = 2,
    this.regularChangeSideEvery = 7,
    this.decidingChangeSideEvery = 5,
  });

  static const beachFivb = MatchFormat();

  final int setsToWin;
  final int regularSetPoints;
  final int decidingSetPoints;
  final int winBy;
  final int regularChangeSideEvery;
  final int decidingChangeSideEvery;

  int targetFor(int setNumber) =>
      _isDeciding(setNumber) ? decidingSetPoints : regularSetPoints;

  int changeSideEveryFor(int setNumber) =>
      _isDeciding(setNumber) ? decidingChangeSideEvery : regularChangeSideEvery;

  bool _isDeciding(int setNumber) => setNumber == setsToWin * 2 - 1;
}
