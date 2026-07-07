import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_session.dart';
import '../services/supabase_service.dart';
import 'players_screen.dart';
import 'config_screen.dart';
import 'new_game_sheet.dart';
import 'scoreboard_screen.dart';
import 'dashboard_tab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Points Rummy'),
          actions: [
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Players',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlayersScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Default Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConfigScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New Game',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const NewGameSheet(),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'In Progress'),
              Tab(text: 'Past Games'),
              Tab(text: 'Dashboard'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GamesListTab(status: GameStatus.inProgress),
            _GamesListTab(status: GameStatus.closed),
            DashboardTab(),
          ],
        ),
      ),
    );
  }
}

class _GamesListTab extends StatelessWidget {
  final GameStatus status;

  const _GamesListTab({required this.status});

  @override
  Widget build(BuildContext context) {
    final service = context.read<SupabaseService>();

    return StreamBuilder<List<GameSession>>(
      stream: service.watchGames(status: status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final games = snapshot.data ?? [];
        if (games.isEmpty) {
          return Center(
            child: Text(
              status == GameStatus.inProgress
                  ? 'No games in progress.\nTap + to start one.'
                  : 'No past games yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }
        return ListView.builder(
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            final names = game.players.map((p) => p.name).join(', ');
            return ListTile(
              title: Text(names),
              subtitle: Text(
                '${game.players.length} players · ₹${game.pointValue}/pt · max ${game.maxGamePoints}',
              ),
              trailing: status == GameStatus.closed
                  ? Text(
                      game.closedAt != null
                          ? '${game.closedAt!.day}/${game.closedAt!.month}/${game.closedAt!.year}'
                          : '',
                      style: const TextStyle(color: Colors.grey),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ScoreboardScreen(gameId: game.id)),
              ),
            );
          },
        );
      },
    );
  }
}
