import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../models/game_round.dart';
import '../models/settlement.dart';
import '../models/game_config_defaults.dart';
import '../models/game_session.dart';
import '../models/player_stats.dart';

const _uuid = Uuid();

/// Single point of contact with Supabase (Postgres + Realtime). Tables:
///   players(id, name, created_at)
///   config_defaults(id=1, point_value, max_score_per_hand, max_game_points,
///                    first_drop, middle_drop)
///   games(id, players jsonb, point_value, max_score_per_hand,
///         max_game_points, first_drop, middle_drop, status, created_at,
///         closed_at)
///   rounds(id, game_id, round_number, scores jsonb, score_labels jsonb,
///          winner_id, created_at)
///   settlements(id, game_id, after_round, amounts jsonb, created_at)
///
/// IDs are generated client-side (UUIDs for players/rounds/settlements,
/// a timestamp string for games) rather than left to server defaults --
/// this is deliberate groundwork for offline support later, since a
/// client can't wait on a server round-trip for an ID while offline.
class SupabaseService {
  final _db = Supabase.instance.client;

  // ---------- Players (shared registry) ----------

  Stream<List<Player>> watchPlayers() {
    return _db
        .from('players')
        .stream(primaryKey: ['id'])
        .order('name')
        .map((rows) => rows.map(Player.fromRow).toList());
  }

  Future<void> registerPlayer(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final existing = await _db.from('players').select('id').eq('name', trimmed).limit(1);
    if ((existing as List).isNotEmpty) return;
    await _db.from('players').insert({'id': _uuid.v4(), 'name': trimmed});
  }

  Future<void> removePlayer(String id) async {
    await _db.from('players').delete().eq('id', id);
  }

  // ---------- Config defaults ----------

  Stream<GameConfigDefaults> watchConfigDefaults() {
    return _db
        .from('config_defaults')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .map((rows) => GameConfigDefaults.fromRow(rows.isEmpty ? null : rows.first));
  }

  Future<void> saveConfigDefaults(GameConfigDefaults defaults) async {
    await _db.from('config_defaults').upsert(defaults.toRow());
  }

  // ---------- Games ----------

  Stream<List<GameSession>> watchGames({required GameStatus status}) {
    final statusStr = status == GameStatus.inProgress ? 'in_progress' : 'closed';
    return _db
        .from('games')
        .stream(primaryKey: ['id'])
        .eq('status', statusStr)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(GameSession.fromRow).toList());
  }

  Stream<GameSession?> watchGame(String gameId) {
    return _db
        .from('games')
        .stream(primaryKey: ['id'])
        .eq('id', gameId)
        .map((rows) => rows.isEmpty ? null : GameSession.fromRow(rows.first));
  }

  Future<String> createGame({
    required List<Player> players,
    required double pointValue,
    required int maxScorePerHand,
    required int maxGamePoints,
    required int firstDrop,
    required int middleDrop,
  }) async {
    final now = DateTime.now();
    // Timestamp-based ID (down to the millisecond) so games are
    // identifiable and sortable at a glance, and generated client-side
    // so it works offline too.
    final gameId = 'game_${DateFormat('yyyyMMdd_HHmmssSSS').format(now)}';
    final session = GameSession(
      id: gameId,
      players: players,
      pointValue: pointValue,
      maxScorePerHand: maxScorePerHand,
      maxGamePoints: maxGamePoints,
      firstDrop: firstDrop,
      middleDrop: middleDrop,
      status: GameStatus.inProgress,
      createdAt: now,
    );
    await _db.from('games').insert(session.toRow());
    return gameId;
  }

  Future<void> closeGame(String gameId) async {
    await _db.from('games').update({
      'status': 'closed',
      'closed_at': DateTime.now().toIso8601String(),
    }).eq('id', gameId);
  }

  // ---------- Rounds ----------

  Stream<List<GameRound>> watchRounds(String gameId) {
    return _db
        .from('rounds')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .order('round_number')
        .map((rows) => rows.map(GameRound.fromRow).toList());
  }

  Future<void> addRound({
    required String gameId,
    required int roundNumber,
    required Map<String, int> scores,
    required Map<String, String> labels,
    required String winnerId,
  }) async {
    final round = GameRound(
      id: _uuid.v4(),
      roundNumber: roundNumber,
      scores: scores,
      scoreLabels: labels,
      winnerId: winnerId,
    );
    await _db.from('rounds').insert({...round.toRow(), 'game_id': gameId});
  }

  Future<void> undoLastRound(String gameId) async {
    final rows = await _db
        .from('rounds')
        .select('id')
        .eq('game_id', gameId)
        .order('round_number', ascending: false)
        .limit(1);
    if ((rows as List).isNotEmpty) {
      await _db.from('rounds').delete().eq('id', rows.first['id'] as String);
    }
  }

  Future<void> updateRound({
    required String gameId,
    required String roundId,
    required int roundNumber,
    required Map<String, int> scores,
    required Map<String, String> labels,
    required String winnerId,
  }) async {
    final round = GameRound(
      id: roundId,
      roundNumber: roundNumber,
      scores: scores,
      scoreLabels: labels,
      winnerId: winnerId,
    );
    await _db.from('rounds').update(round.toRow()).eq('id', roundId);
  }

  // ---------- Settlements ----------

  Stream<List<Settlement>> watchSettlements(String gameId) {
    return _db
        .from('settlements')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .order('after_round')
        .map((rows) => rows.map(Settlement.fromRow).toList());
  }

  Future<void> recordSettlement({
    required String gameId,
    required int afterRound,
    required Map<String, double> amounts,
  }) async {
    final settlement = Settlement(id: _uuid.v4(), afterRound: afterRound, amounts: amounts);
    await _db.from('settlements').insert({...settlement.toRow(), 'game_id': gameId});
  }

  // ---------- Analytics ----------

  /// Aggregates round and settlement data across every game to produce
  /// per-player stats. Pulls all rows client-side and aggregates in Dart
  /// for now; if this grows slow at scale, the same logic translates
  /// directly into a Postgres view or RPC function.
  Future<List<PlayerStats>> computePlayerStats() async {
    final playerRows = await _db.from('players').select();
    final players = (playerRows as List).map((r) => Player.fromRow(r as Map<String, dynamic>)).toList();

    final roundRows = await _db.from('rounds').select();
    final settlementRows = await _db.from('settlements').select();
    final gameRows = await _db.from('games').select('id, players');

    final roundsPlayed = <String, int>{};
    final winsCount = <String, int>{};
    final scoreSum = <String, double>{};
    final scoreCount = <String, int>{};
    final opponentAvgOnWin = <String, List<double>>{};

    for (final row in (roundRows as List)) {
      final data = row as Map<String, dynamic>;
      final rawScores = Map<String, dynamic>.from(data['scores'] as Map? ?? {});
      final scores = rawScores.map((k, v) => MapEntry(k, (v as num).toDouble()));
      final winnerId = data['winner_id'] as String? ?? '';

      scores.forEach((playerId, pts) {
        roundsPlayed[playerId] = (roundsPlayed[playerId] ?? 0) + 1;
        scoreSum[playerId] = (scoreSum[playerId] ?? 0) + pts;
        scoreCount[playerId] = (scoreCount[playerId] ?? 0) + 1;
      });

      if (winnerId.isNotEmpty && scores.containsKey(winnerId)) {
        winsCount[winnerId] = (winsCount[winnerId] ?? 0) + 1;
        final others = scores.entries.where((e) => e.key != winnerId).map((e) => e.value).toList();
        if (others.isNotEmpty) {
          final avgOthers = others.reduce((a, b) => a + b) / others.length;
          opponentAvgOnWin.putIfAbsent(winnerId, () => []).add(avgOthers);
        }
      }
    }

    final netAmount = <String, double>{};
    final individualPayouts = <String, List<double>>{};
    final groupPayouts = <String, List<double>>{};

    for (final row in (settlementRows as List)) {
      final data = row as Map<String, dynamic>;
      final rawAmounts = Map<String, dynamic>.from(data['amounts'] as Map? ?? {});
      final amounts = rawAmounts.map((k, v) => MapEntry(k, (v as num).toDouble()));

      amounts.forEach((playerId, amt) {
        netAmount[playerId] = (netAmount[playerId] ?? 0) + amt;
      });

      final recipients = amounts.entries.where((e) => e.value > 0).toList();
      if (recipients.length == 1) {
        individualPayouts.putIfAbsent(recipients.first.key, () => []).add(recipients.first.value);
      } else if (recipients.length > 1) {
        for (final r in recipients) {
          groupPayouts.putIfAbsent(r.key, () => []).add(r.value);
        }
      }
    }

    final gamesPlayed = <String, int>{};
    for (final row in (gameRows as List)) {
      final data = row as Map<String, dynamic>;
      final embeddedPlayers = List<Map<String, dynamic>>.from(
        (data['players'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      for (final ep in embeddedPlayers) {
        final id = ep['id'] as String;
        gamesPlayed[id] = (gamesPlayed[id] ?? 0) + 1;
      }
    }

    double? avgOf(List<double>? list) {
      if (list == null || list.isEmpty) return null;
      return list.reduce((a, b) => a + b) / list.length;
    }

    return players.map((p) {
      final sc = scoreCount[p.id] ?? 0;
      return PlayerStats(
        playerId: p.id,
        name: p.name,
        gamesPlayed: gamesPlayed[p.id] ?? 0,
        roundsPlayed: roundsPlayed[p.id] ?? 0,
        wins: winsCount[p.id] ?? 0,
        avgScore: sc == 0 ? null : (scoreSum[p.id] ?? 0) / sc,
        avgOpponentScoreOnWin: avgOf(opponentAvgOnWin[p.id]),
        netAmount: netAmount[p.id] ?? 0,
        avgIndividualPayout: avgOf(individualPayouts[p.id]),
        avgGroupPayout: avgOf(groupPayouts[p.id]),
      );
    }).toList();
  }
}
