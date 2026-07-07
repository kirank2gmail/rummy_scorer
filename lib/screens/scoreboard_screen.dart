import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_session_provider.dart';
import '../services/supabase_service.dart';
import 'round_entry_screen.dart';
import 'summary_screen.dart';
import 'edit_round_screen.dart';

class ScoreboardScreen extends StatelessWidget {
  final String gameId;

  const ScoreboardScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameSessionProvider(
        service: context.read<SupabaseService>(),
        gameId: gameId,
      ),
      child: const _ScoreboardBody(),
    );
  }
}

class _ScoreboardBody extends StatelessWidget {
  const _ScoreboardBody();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameSessionProvider>();

    if (!game.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totals = game.totals;
    final eliminated = game.eliminatedPlayerIds;
    final activeCount = game.activePlayers.length;
    final gameOver = activeCount <= 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoreboard'),
        actions: [
          if (!game.isClosed)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last round',
              onPressed: game.rounds.isEmpty ? null : () => game.undoLastRound(),
            ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Settle up',
            onPressed: game.rounds.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SummaryScreen(gameId: game.gameId)),
                    ),
          ),
          if (!game.isClosed)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Close game',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Close this game?'),
                    content: const Text(
                      'It will move to Past Games and can no longer be scored. '
                      'Make sure everyone has settled up first.',
                    ),
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
            ),
        ],
      ),
      body: Column(
        children: [
          if (game.isClosed)
            Container(
              width: double.infinity,
              color: Colors.grey.shade300,
              padding: const EdgeInsets.all(10),
              child: const Text(
                'This game is closed (read-only).',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          if (eliminated.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      gameOver
                          ? (game.activePlayers.isNotEmpty
                              ? '${game.activePlayers.first.name} is the last player standing.'
                              : 'All players have crossed the max points limit.')
                          : 'Out (crossed ${game.maxGamePoints}): '
                              '${game.players.where((p) => eliminated.contains(p.id)).map((p) => p.name).join(', ')}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!game.isClosed)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SummaryScreen(gameId: game.gameId)),
                      ),
                      child: const Text('Settle'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: game.rounds.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No rounds played yet.\nTap + to score the first hand.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text('Player')),
                        const DataColumn(label: Text('Total')),
                        // Most recent round first.
                        ...game.rounds.reversed.map(
                          (r) => DataColumn(label: Text('R:${r.roundNumber}')),
                        ),
                      ],
                      rows: [
                        // One row per player, in original entry order.
                        ...game.players.map((p) {
                          final isEliminated = eliminated.contains(p.id);
                          return DataRow(cells: [
                            DataCell(Text(isEliminated ? '${p.name} (out)' : p.name)),
                            DataCell(Text(
                              '${totals[p.id] ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            ...game.rounds.reversed.map((round) {
                              if (!round.scores.containsKey(p.id)) {
                                return const DataCell(Text('—', style: TextStyle(color: Colors.grey)));
                              }
                              final pts = round.scores[p.id] ?? 0;
                              final isWinner = round.winnerId == p.id;
                              return DataCell(Text(
                                '$pts',
                                style: TextStyle(
                                  fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                                  color: isWinner ? Colors.green : null,
                                ),
                              ));
                            }),
                          ]);
                        }),
                        // Bottom action row: edit button per round column.
                        if (!game.isClosed)
                          DataRow(
                            color: WidgetStateProperty.all(Colors.grey.shade100),
                            cells: [
                              const DataCell(SizedBox.shrink()),
                              const DataCell(SizedBox.shrink()),
                              ...game.rounds.reversed.map((round) {
                                return DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    tooltip: 'Edit round ${round.roundNumber}',
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EditRoundScreen(
                                          gameId: game.gameId,
                                          roundId: round.id,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: game.isClosed
          ? null
          : FloatingActionButton.extended(
              onPressed: (game.rounds.isNotEmpty && gameOver)
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RoundEntryScreen(gameId: game.gameId)),
                      ),
              icon: const Icon(Icons.add),
              label: const Text('Score Round'),
            ),
    );
  }
}
