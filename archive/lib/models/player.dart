class Player {
  final String id;
  final String name;

  Player({required this.id, required this.name});

  /// Row for inserting into the `players` table.
  Map<String, dynamic> toRow() => {'id': id, 'name': name};

  factory Player.fromRow(Map<String, dynamic> row) {
    return Player(id: row['id'] as String, name: row['name'] as String);
  }

  /// Embedded form used inside a game row's `players` jsonb column, so the
  /// scoreboard doesn't need a separate lookup to show names.
  Map<String, dynamic> toEmbedded() => {'id': id, 'name': name};

  factory Player.fromEmbedded(Map<String, dynamic> data) {
    return Player(id: data['id'] as String, name: data['name'] as String);
  }
}
