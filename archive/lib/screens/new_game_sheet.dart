import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/game_config_defaults.dart';
import '../services/supabase_service.dart';
import 'scoreboard_screen.dart';

class NewGameSheet extends StatefulWidget {
  const NewGameSheet({super.key});

  @override
  State<NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<NewGameSheet> {
  final Set<String> _selectedIds = {};
  final _pointValueController = TextEditingController();
  final _maxScoreController = TextEditingController();
  final _maxGamePointsController = TextEditingController();
  final _firstDropController = TextEditingController();
  final _middleDropController = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _pointValueController.dispose();
    _maxScoreController.dispose();
    _maxGamePointsController.dispose();
    _firstDropController.dispose();
    _middleDropController.dispose();
    super.dispose();
  }

  void _prefill(GameConfigDefaults d) {
    _pointValueController.text = d.pointValue.toString();
    _maxScoreController.text = d.maxScorePerHand.toString();
    _maxGamePointsController.text = d.maxGamePoints.toString();
    _firstDropController.text = d.firstDrop.toString();
    _middleDropController.text = d.middleDrop.toString();
  }

  Future<void> _startGame(SupabaseService service, List<Player> allPlayers) async {
    final selected = allPlayers.where((p) => _selectedIds.contains(p.id)).toList();
    final gameId = await service.createGame(
      players: selected,
      pointValue: double.tryParse(_pointValueController.text) ?? 1.0,
      maxScorePerHand: int.tryParse(_maxScoreController.text) ?? 80,
      maxGamePoints: int.tryParse(_maxGamePointsController.text) ?? 200,
      firstDrop: int.tryParse(_firstDropController.text) ?? 20,
      middleDrop: int.tryParse(_middleDropController.text) ?? 40,
    );
    if (mounted) {
      Navigator.of(context).pop(); // close the sheet
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ScoreboardScreen(gameId: gameId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SupabaseService>();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return StreamBuilder<GameConfigDefaults>(
          stream: service.watchConfigDefaults(),
          builder: (context, defaultsSnapshot) {
            if (!defaultsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!_prefilled) {
              _prefilled = true;
              _prefill(defaultsSnapshot.data!);
            }
            return StreamBuilder<List<Player>>(
              stream: service.watchPlayers(),
              builder: (context, playersSnapshot) {
                final allPlayers = playersSnapshot.data ?? [];
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const Text('New Game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('Select players', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (allPlayers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No registered players yet. Add some from the Players screen.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ...allPlayers.map((p) {
                        final isSelected = _selectedIds.contains(p.id);
                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          title: Text(p.name),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedIds.add(p.id);
                              } else {
                                _selectedIds.remove(p.id);
                              }
                            });
                          },
                        );
                      }),
                      const Divider(height: 32),
                      const Text('Game settings', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pointValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Point value (₹ per point)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _maxGamePointsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max points (elimination threshold)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _firstDropController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'First drop',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _middleDropController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Middle drop',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _maxScoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max score per hand (full count)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedIds.length < 2 ? null : () => _startGame(service, allPlayers),
                          child: const Text('Start Game'),
                        ),
                      ),
                      if (_selectedIds.length < 2)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Select at least 2 players.', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
