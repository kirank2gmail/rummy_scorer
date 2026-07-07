import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_session_provider.dart';
import '../services/supabase_service.dart';

/// "Settle Up" screen. Can be opened at any point in the game -- the
/// scorekeeper marks who is settling out (owes into the pot), and the
/// pot is apportioned among the remaining players. A suggested split
/// (favoring lower scores) is pre-filled but every amount is editable.
/// Players who've auto-crossed the max points threshold are locked in
/// as settling out.
class SummaryScreen extends StatelessWidget {
  final String gameId;

  const SummaryScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameSessionProvider(
        service: context.read<SupabaseService>(),
        gameId: gameId,
      ),
      child: const _SummaryBody(),
    );
  }
}

class _SummaryBody extends StatefulWidget {
  const _SummaryBody();

  @override
  State<_SummaryBody> createState() => _SummaryBodyState();
}

class _SummaryBodyState extends State<_SummaryBody> {
  final Set<String> _outIds = {};
  final Map<String, TextEditingController> _shareControllers = {};
  bool _initialized = false;

  TextEditingController _controllerFor(String id) =>
      _shareControllers.putIfAbsent(id, () => TextEditingController(text: '0.00'));

  @override
  void dispose() {
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _potFor(GameSessionProvider game) {
    final t = game.totals;
    return _outIds.fold(0.0, (sum, id) => sum + (t[id] ?? 0) * game.pointValue);
  }

  void _applySuggestedSplit(GameSessionProvider game) {
    final remainingIds = game.players.where((p) => !_outIds.contains(p.id)).map((p) => p.id).toList();
    final pot = _potFor(game);
    final suggested = game.suggestedShares(pot, remainingIds);
    for (final id in remainingIds) {
      _controllerFor(id).text = (suggested[id] ?? 0).toStringAsFixed(2);
    }
  }

  void _toggleOut(GameSessionProvider game, String id, bool value) {
    setState(() {
      if (value) {
        _outIds.add(id);
      } else {
        _outIds.remove(id);
      }
      _applySuggestedSplit(game);
    });
  }

  double _enteredTotal(List<String> remainingIds) {
    return remainingIds.fold(0.0, (sum, id) {
      final v = double.tryParse(_controllerFor(id).text.trim()) ?? 0;
      return sum + v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameSessionProvider>();

    if (!game.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final eliminated = game.eliminatedPlayerIds;

    if (!_initialized) {
      _initialized = true;
      _outIds.addAll(eliminated);
      if (_outIds.isNotEmpty) {
        _applySuggestedSplit(game);
      }
    }

    final totals = game.totals;
    final remaining = game.players.where((p) => !_outIds.contains(p.id)).toList();
    final pot = _potFor(game);
    final enteredTotal = _enteredTotal(remaining.map((p) => p.id).toList());
    final mismatch = _outIds.isNotEmpty && (enteredTotal - pot).abs() > 0.01;

    return Scaffold(
      appBar: AppBar(title: const Text('Settle Up')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Step 1: Mark who is settling out (owes into the pot)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...game.players.map((p) {
            final isOut = _outIds.contains(p.id);
            final isAutoEliminated = eliminated.contains(p.id);
            final owed = (totals[p.id] ?? 0) * game.pointValue;
            return CheckboxListTile(
              value: isOut,
              onChanged: isAutoEliminated ? null : (v) => _toggleOut(game, p.id, v ?? false),
              title: Text(isAutoEliminated ? '${p.name} (out — crossed max points)' : p.name),
              subtitle: Text('${totals[p.id] ?? 0} points · owes ₹${owed.toStringAsFixed(2)}'),
            );
          }),
          const SizedBox(height: 16),
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Pot to distribute: ₹${pot.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (remaining.isNotEmpty && _outIds.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Step 2: Apportion the pot', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() => _applySuggestedSplit(game)),
                  child: const Text('Reset to suggested'),
                ),
              ],
            ),
            const Text(
              'Suggested split favors lower scores — edit any amount to apportion manually.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...remaining.map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(p.name)),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _controllerFor(p.id),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              'Entered total: ₹${enteredTotal.toStringAsFixed(2)} of ₹${pot.toStringAsFixed(2)}',
              style: TextStyle(
                color: mismatch ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_outIds.isEmpty || remaining.isEmpty || mismatch)
                  ? null
                  : () async {
                      final amounts = <String, double>{};
                      for (final id in _outIds) {
                        amounts[id] = -((totals[id] ?? 0) * game.pointValue);
                      }
                      for (final p in remaining) {
                        amounts[p.id] = double.tryParse(_controllerFor(p.id).text.trim()) ?? 0;
                      }
                      await game.recordSettlement(amounts);
                      setState(() {
                        // Auto-eliminated players stay locked in as out;
                        // only clear manually-selected ones.
                        _outIds
                          ..clear()
                          ..addAll(eliminated);
                        for (final c in _shareControllers.values) {
                          c.text = '0.00';
                        }
                      });
                    },
              child: const Text('Record Settlement & Continue Game'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Close this game?'),
                    content: const Text('It will move to Past Games and can no longer be scored.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Close Game')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await game.closeGame();
                  if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('End Game & Close'),
            ),
          ),
          if (game.settlements.isNotEmpty) ...[
            const Divider(height: 32),
            const Text('Past Settlements', style: TextStyle(fontWeight: FontWeight.bold)),
            ...game.settlements.reversed.map((s) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('After round ${s.afterRound}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...s.amounts.entries.map((e) {
                        final match = game.players.where((p) => p.id == e.key);
                        final name = match.isEmpty ? 'Unknown' : match.first.name;
                        final amt = e.value;
                        return Text(
                          '$name: ${amt >= 0 ? '+' : ''}₹${amt.toStringAsFixed(2)}',
                          style: TextStyle(color: amt >= 0 ? Colors.green : Colors.red),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
