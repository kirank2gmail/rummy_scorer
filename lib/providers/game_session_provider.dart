import 'package:flutter/foundation.dart';
import '../models/game_round.dart';
import '../models/game_session.dart';
import '../models/player.dart';
import '../models/settlement.dart';
import '../services/supabase_service.dart';

/// Live view of a single game, backed by Supabase realtime listeners. Any device
/// with this provider open for the same gameId sees updates in real time.
class GameSessionProvider extends ChangeNotifier {
  final SupabaseService _service;
  final String gameId;

  GameSession? _session;
  List<GameRound> _rounds = [];
  List<Settlement> _settlements = [];

  GameSessionProvider({required SupabaseService service, required this.gameId}) : _service = service {
    _service.watchGame(gameId).listen((session) {
      _session = session;
      notifyListeners();
    });
    _service.watchRounds(gameId).listen((rounds) {
      _rounds = rounds;
      notifyListeners();
    });
    _service.watchSettlements(gameId).listen((settlements) {
      _settlements = settlements;
      notifyListeners();
    });
  }

  GameSession? get session => _session;
  List<Player> get players => _session?.players ?? [];
  List<GameRound> get rounds => _rounds;
  List<Settlement> get settlements => _settlements;
  double get pointValue => _session?.pointValue ?? 1.0;
  int get maxScorePerHand => _session?.maxScorePerHand ?? 80;
  int get maxGamePoints => _session?.maxGamePoints ?? 200;
  int get firstDrop => _session?.firstDrop ?? 20;
  int get middleDrop => _session?.middleDrop ?? 40;
  bool get isClosed => _session?.status == GameStatus.closed;
  bool get isLoaded => _session != null;

  Map<String, int> get totals {
    final totals = <String, int>{for (final p in players) p.id: 0};
    for (final round in _rounds) {
      round.scores.forEach((playerId, points) {
        totals[playerId] = (totals[playerId] ?? 0) + points;
      });
    }
    return totals;
  }

  Set<String> get eliminatedPlayerIds {
    final t = totals;
    return players.where((p) => (t[p.id] ?? 0) >= maxGamePoints).map((p) => p.id).toSet();
  }

  List<Player> get activePlayers {
    final eliminated = eliminatedPlayerIds;
    return players.where((p) => !eliminated.contains(p.id)).toList();
  }

  Map<String, double> suggestedShares(double pot, List<String> remainingIds) {
    if (remainingIds.isEmpty || pot <= 0) {
      return {for (final id in remainingIds) id: 0};
    }
    final t = totals;
    final weights = {for (final id in remainingIds) id: 1.0 / ((t[id] ?? 0) + 1)};
    final totalWeight = weights.values.fold(0.0, (a, b) => a + b);
    return {for (final id in remainingIds) id: pot * (weights[id]! / totalWeight)};
  }

  Future<void> addRound(Map<String, int> scores, Map<String, String> labels, String winnerId) {
    final clamped = <String, int>{
      for (final entry in scores.entries) entry.key: entry.value.clamp(0, maxScorePerHand),
    };
    return _service.addRound(
      gameId: gameId,
      roundNumber: _rounds.length + 1,
      scores: clamped,
      labels: labels,
      winnerId: winnerId,
    );
  }

  Future<void> undoLastRound() => _service.undoLastRound(gameId);

  Future<void> updateRound(
    String roundId,
    int roundNumber,
    Map<String, int> scores,
    Map<String, String> labels,
    String winnerId,
  ) {
    final clamped = <String, int>{
      for (final entry in scores.entries) entry.key: entry.value.clamp(0, maxScorePerHand),
    };
    return _service.updateRound(
      gameId: gameId,
      roundId: roundId,
      roundNumber: roundNumber,
      scores: clamped,
      labels: labels,
      winnerId: winnerId,
    );
  }

  Future<void> recordSettlement(Map<String, double> amounts) {
    return _service.recordSettlement(gameId: gameId, afterRound: _rounds.length, amounts: amounts);
  }

  Future<void> closeGame() => _service.closeGame(gameId);
}
