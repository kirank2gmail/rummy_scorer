import 'player.dart';

enum GameStatus { inProgress, closed }

/// One row in the `games` table. Players are embedded (id + name) in the
/// `players` jsonb column so the scoreboard can render without a separate
/// lookup; rounds and settlements live in their own tables, joined on
/// `game_id`.
class GameSession {
  final String id;
  final List<Player> players;
  final double pointValue;
  final int maxScorePerHand;
  final int maxGamePoints;
  final int firstDrop;
  final int middleDrop;
  final GameStatus status;
  final DateTime createdAt;
  final DateTime? closedAt;

  GameSession({
    required this.id,
    required this.players,
    required this.pointValue,
    required this.maxScorePerHand,
    required this.maxGamePoints,
    required this.firstDrop,
    required this.middleDrop,
    required this.status,
    required this.createdAt,
    this.closedAt,
  });

  Map<String, dynamic> toRow() => {
        'id': id,
        'players': players.map((p) => p.toEmbedded()).toList(),
        'point_value': pointValue,
        'max_score_per_hand': maxScorePerHand,
        'max_game_points': maxGamePoints,
        'first_drop': firstDrop,
        'middle_drop': middleDrop,
        'status': status == GameStatus.inProgress ? 'in_progress' : 'closed',
        'created_at': createdAt.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
      };

  factory GameSession.fromRow(Map<String, dynamic> row) {
    final rawPlayers = List<Map<String, dynamic>>.from(
      (row['players'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return GameSession(
      id: row['id'] as String,
      players: rawPlayers.map(Player.fromEmbedded).toList(),
      pointValue: (row['point_value'] as num?)?.toDouble() ?? 1.0,
      maxScorePerHand: row['max_score_per_hand'] as int? ?? 80,
      maxGamePoints: row['max_game_points'] as int? ?? 200,
      firstDrop: row['first_drop'] as int? ?? 20,
      middleDrop: row['middle_drop'] as int? ?? 40,
      status: (row['status'] as String? ?? 'in_progress') == 'closed'
          ? GameStatus.closed
          : GameStatus.inProgress,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      closedAt: row['closed_at'] != null ? DateTime.tryParse(row['closed_at'] as String) : null,
    );
  }
}
