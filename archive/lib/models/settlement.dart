/// A record of a settlement made at some point during a game.
/// [amounts]: playerId -> net amount at that settlement
/// (negative = paid into the pot, positive = received from the pot).
class Settlement {
  final String id;
  final int afterRound;
  final Map<String, double> amounts;

  Settlement({required this.id, required this.afterRound, required this.amounts});

  /// Row for inserting into the `settlements` table. `game_id` is added
  /// by the caller since this model doesn't carry it.
  Map<String, dynamic> toRow() => {
        'id': id,
        'after_round': afterRound,
        'amounts': amounts,
      };

  factory Settlement.fromRow(Map<String, dynamic> row) {
    final rawAmounts = Map<String, dynamic>.from(row['amounts'] as Map? ?? {});
    return Settlement(
      id: row['id'] as String,
      afterRound: row['after_round'] as int? ?? 0,
      amounts: rawAmounts.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }
}
