import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_config_defaults.dart';
import '../services/supabase_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _pointValueController = TextEditingController();
  final _maxScoreController = TextEditingController();
  final _maxGamePointsController = TextEditingController();
  final _firstDropController = TextEditingController();
  final _middleDropController = TextEditingController();
  bool _loadedOnce = false;

  @override
  void dispose() {
    _pointValueController.dispose();
    _maxScoreController.dispose();
    _maxGamePointsController.dispose();
    _firstDropController.dispose();
    _middleDropController.dispose();
    super.dispose();
  }

  void _populate(GameConfigDefaults d) {
    _pointValueController.text = d.pointValue.toString();
    _maxScoreController.text = d.maxScorePerHand.toString();
    _maxGamePointsController.text = d.maxGamePoints.toString();
    _firstDropController.text = d.firstDrop.toString();
    _middleDropController.text = d.middleDrop.toString();
  }

  Future<void> _save(SupabaseService service) async {
    final defaults = GameConfigDefaults(
      pointValue: double.tryParse(_pointValueController.text) ?? 1.0,
      maxScorePerHand: int.tryParse(_maxScoreController.text) ?? 80,
      maxGamePoints: int.tryParse(_maxGamePointsController.text) ?? 200,
      firstDrop: int.tryParse(_firstDropController.text) ?? 20,
      middleDrop: int.tryParse(_middleDropController.text) ?? 40,
    );
    await service.saveConfigDefaults(defaults);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Defaults saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<SupabaseService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Default Settings')),
      body: StreamBuilder<GameConfigDefaults>(
        stream: service.watchConfigDefaults(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_loadedOnce) {
            _loadedOnce = true;
            _populate(snapshot.data!);
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text(
                  'These defaults pre-fill the New Game screen. Each game can '
                  'still override any of them.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
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
                  controller: _maxScoreController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max score per hand (full count)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maxGamePointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max points (game elimination threshold)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _firstDropController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'First drop points',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _middleDropController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Middle drop points',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _save(service),
                    child: const Text('Save Defaults'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
