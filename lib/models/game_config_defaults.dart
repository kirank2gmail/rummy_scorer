/// Default scoring settings, editable on the Config screen. These are
/// pre-filled into the New Game sheet each time, but can be overridden
/// per game without changing the defaults. Backed by the single-row
/// `config_defaults` table (id = 1).
class GameConfigDefaults {
  final double pointValue;
  final int maxScorePerHand; // "full count" cap for a single hand
  final int maxGamePoints; // elimination threshold for the whole game
  final int firstDrop;
  final int middleDrop;

  const GameConfigDefaults({
    this.pointValue = 1.0,
    this.maxScorePerHand = 80,
    this.maxGamePoints = 200,
    this.firstDrop = 20,
    this.middleDrop = 40,
  });

  Map<String, dynamic> toRow() => {
        'id': 1,
        'point_value': pointValue,
        'max_score_per_hand': maxScorePerHand,
        'max_game_points': maxGamePoints,
        'first_drop': firstDrop,
        'middle_drop': middleDrop,
      };

  factory GameConfigDefaults.fromRow(Map<String, dynamic>? row) {
    if (row == null) return const GameConfigDefaults();
    return GameConfigDefaults(
      pointValue: (row['point_value'] as num?)?.toDouble() ?? 1.0,
      maxScorePerHand: row['max_score_per_hand'] as int? ?? 80,
      maxGamePoints: row['max_game_points'] as int? ?? 200,
      firstDrop: row['first_drop'] as int? ?? 20,
      middleDrop: row['middle_drop'] as int? ?? 40,
    );
  }
}
