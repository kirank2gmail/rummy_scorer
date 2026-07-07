/// Represents the outcome of a single hand (round) of Points Rummy.
class GameRound {
  final String id;
  final int roundNumber;

  /// playerId -> points scored this round (winner = 0).
  final Map<String, int> scores;

  /// playerId -> how the score was arrived at, for display purposes only.
  /// e.g. "First Drop", "Middle Drop", "Winner", "Custom".
  final Map<String, String> scoreLabels;

  final String winnerId;

  GameRound({
    required this.id,
    required this.roundNumber,
    required this.scores,
    required this.scoreLabels,
    required this.winnerId,
  });

  /// Row for inserting/updating the `rounds` table. `game_id` is added by
  /// the caller since this model doesn't carry it.
  Map<String, dynamic> toRow() => {
        'id': id,
        'round_number': roundNumber,
        'scores': scores,
        'score_labels': scoreLabels,
        'winner_id': winnerId,
      };

  factory GameRound.fromRow(Map<String, dynamic> row) {
    return GameRound(
      id: row['id'] as String,
      roundNumber: row['round_number'] as int? ?? 0,
      scores: Map<String, int>.from(
        (row['scores'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
      ),
      scoreLabels: Map<String, String>.from(row['score_labels'] as Map? ?? {}),
      winnerId: row['winner_id'] as String? ?? '',
    );
  }
}
