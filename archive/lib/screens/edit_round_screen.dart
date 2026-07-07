import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_round.dart';
import '../models/player.dart';
import '../providers/game_session_provider.dart';
import '../services/supabase_service.dart';

class EditRoundScreen extends StatelessWidget {
  final String gameId;
  final String roundId;

  const EditRoundScreen({super.key, required this.gameId, required this.roundId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameSessionProvider(
        service: context.read<SupabaseService>(),
        gameId: gameId,
      ),
      child: _EditRoundBody(roundId: roundId),
    );
  }
}

class _EditRoundBody extends StatefulWidget {
  final String roundId;

  const _EditRoundBody({required this.roundId});

  @override
  State<_EditRoundBody> createState() => _EditRoundBodyState();
}

/// Same per-row exclusive entry model as RoundEntryScreen: typing a custom
/// score, or tapping W / D / MD -- choosing one disables the other three
/// for that player until it's toggled off.
class _EditRoundBodyState extends State<_EditRoundBody> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _mode = {}; // 'none' | 'custom' | 'winner' | 'drop' | 'middleDrop'
  final Map<String, String> _labels = {};
  bool _prefilled = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String playerId) {
    return _controllers.putIfAbsent(playerId, () => TextEditingController());
  }

  String _modeFor(String playerId) => _mode[playerId] ?? 'none';

  void _prefill(GameRound round) {
    round.scores.forEach((playerId, points) {
      _controllerFor(playerId).text = points.toString();
      final label = round.scoreLabels[playerId] ?? 'Custom';
      _labels[playerId] = label;
      if (playerId == round.winnerId) {
        _mode[playerId] = 'winner';
      } else if (label == 'First Drop') {
        _mode[playerId] = 'drop';
      } else if (label == 'Middle Drop') {
        _mode[playerId] = 'middleDrop';
      } else {
        _mode[playerId] = 'custom';
      }
    });
  }

  void _setMode(GameSessionProvider game, Player p, String mode) {
    setState(() {
      final current = _modeFor(p.id);
      if (current == mode) {
        _mode[p.id] = 'none';
        _controllerFor(p.id).clear();
        return;
      }
      if (mode == 'winner') {
        for (final id in _mode.keys.toList()) {
          if (_mode[id] == 'winner') {
            _mode[id] = 'none';
            _controllerFor(id).clear();
          }
        }
        _controllerFor(p.id).text = '0';
        _labels[p.id] = 'Winner';
      } else if (mode == 'drop') {
        _controllerFor(p.id).text = game.firstDrop.toString();
        _labels[p.id] = 'First Drop';
      } else if (mode == 'middleDrop') {
        _controllerFor(p.id).text = game.middleDrop.toString();
        _labels[p.id] = 'Middle Drop';
      }
      _mode[p.id] = mode;
    });
  }

  void _onScoreChanged(String playerId, String text) {
    setState(() {
      if (text.trim().isEmpty) {
        _mode[playerId] = 'none';
      } else {
        _mode[playerId] = 'custom';
        _labels[playerId] = 'Custom';
      }
    });
  }

  bool _isReadyToSave(List<Player> players) {
    final winners = players.where((p) => _modeFor(p.id) == 'winner');
    if (winners.length != 1) return false;
    for (final p in players) {
      if (_modeFor(p.id) == 'winner') continue;
      final text = _controllerFor(p.id).text.trim();
      if (text.isEmpty || int.tryParse(text) == null) return false;
    }
    return true;
  }

  void _save(GameSessionProvider game, GameRound round, List<Player> players) {
    final winner = players.firstWhere((p) => _modeFor(p.id) == 'winner');
    final scores = <String, int>{};
    final labels = <String, String>{};
    for (final p in players) {
      scores[p.id] = int.tryParse(_controllerFor(p.id).text.trim()) ?? 0;
      labels[p.id] = _labels[p.id] ?? 'Custom';
    }
    game.updateRound(round.id, round.roundNumber, scores, labels, winner.id);
    Navigator.of(context).pop();
  }

  Widget _modeButton(BuildContext context, GameSessionProvider game, Player p, String mode, String label) {
    final current = _modeFor(p.id);
    final isActive = current == mode;
    final isBlocked = current != 'none' && current != mode;
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: isBlocked ? null : () => _setMode(game, p, mode),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isBlocked ? Colors.grey.shade300 : Colors.grey.shade400),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : (isBlocked ? Colors.grey.shade400 : Colors.black87),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameSessionProvider>();

    if (!game.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    GameRound? round;
    for (final r in game.rounds) {
      if (r.id == widget.roundId) {
        round = r;
        break;
      }
    }

    if (round == null) {
      return const Scaffold(body: Center(child: Text('Round not found.')));
    }

    // Only the players who were actually scored in this round --
    // preserves the original table order.
    final players = game.players.where((p) => round!.scores.containsKey(p.id)).toList();

    if (!_prefilled) {
      _prefilled = true;
      _prefill(round);
    }

    return Scaffold(
      appBar: AppBar(title: Text('Edit Round ${round.roundNumber}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Player', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                SizedBox(width: 64, child: Text('Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                SizedBox(width: 34, child: Text('W', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                SizedBox(width: 6),
                SizedBox(width: 34, child: Text('D', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                SizedBox(width: 6),
                SizedBox(width: 34, child: Text('MD', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: players.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = players[index];
                final current = _modeFor(p.id);
                final fieldEnabled = current == 'none' || current == 'custom';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontSize: 14))),
                      SizedBox(
                        width: 64,
                        height: 36,
                        child: TextField(
                          controller: _controllerFor(p.id),
                          enabled: fieldEnabled,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (text) => _onScoreChanged(p.id, text),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _modeButton(context, game, p, 'winner', 'W'),
                      const SizedBox(width: 6),
                      _modeButton(context, game, p, 'drop', 'D'),
                      const SizedBox(width: 6),
                      _modeButton(context, game, p, 'middleDrop', 'MD'),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isReadyToSave(players) ? () => _save(game, round!, players) : null,
                child: const Text('Confirm & Recalculate'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
