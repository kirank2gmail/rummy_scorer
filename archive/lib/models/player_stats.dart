/// Aggregated analytics for one player, computed across every game.
class PlayerStats {
  final String playerId;
  final String name;
  final int gamesPlayed;
  final int roundsPlayed;
  final int wins;

  /// Average of this player's own round scores (winning rounds count as 0).
  final double? avgScore;

  /// When this player wins a round, the average score of the *other*
  /// players in that round, averaged across all their wins. Higher means
  /// their wins tend to come against bigger opponent point totals.
  final double? avgOpponentScoreOnWin;

  /// Sum of every settlement amount this player has been part of
  /// (positive = received, negative = paid in) -- their net position.
  final double netAmount;

  /// Average payout received in settlements where they were the sole
  /// recipient of the pot.
  final double? avgIndividualPayout;

  /// Average payout received in settlements where the pot was split
  /// among multiple recipients.
  final double? avgGroupPayout;

  PlayerStats({
    required this.playerId,
    required this.name,
    required this.gamesPlayed,
    required this.roundsPlayed,
    required this.wins,
    required this.avgScore,
    required this.avgOpponentScoreOnWin,
    required this.netAmount,
    required this.avgIndividualPayout,
    required this.avgGroupPayout,
  });

  double get winPercent => roundsPlayed == 0 ? 0 : (wins / roundsPlayed) * 100;
}
