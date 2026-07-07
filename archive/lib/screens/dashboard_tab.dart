import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_stats.dart';
import '../services/supabase_service.dart';

/// Player performance analytics, aggregated across every game:
///   - Round performance: games, rounds, wins, win %, avg score, and the
///     average opponent score on the rounds they win (ranked).
///   - Payout performance: net amount, and average payout split into
///     "individual winner" (sole recipient of a settlement) vs
///     "group winner" (split the pot with others) (ranked).
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late Future<List<PlayerStats>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final service = context.read<SupabaseService>();
    _future = service.computePlayerStats();
  }

  String _fmt(double? v, {int decimals = 1}) => v == null ? '—' : v.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(_load);
        await _future;
      },
      child: FutureBuilder<List<PlayerStats>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load analytics: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          }
          final stats = snapshot.data ?? [];
          final withRounds = stats.where((s) => s.roundsPlayed > 0).toList();
          if (withRounds.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No rounds played yet. Analytics will show up here once games get underway.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            );
          }

          final byOpponentScore = [...withRounds]
            ..sort((a, b) => (b.avgOpponentScoreOnWin ?? -1).compareTo(a.avgOpponentScoreOnWin ?? -1));

          final byPayout = [...stats]..sort((a, b) {
              final aTotal = (a.avgIndividualPayout ?? 0) + (a.avgGroupPayout ?? 0);
              final bTotal = (b.avgIndividualPayout ?? 0) + (b.avgGroupPayout ?? 0);
              return bTotal.compareTo(aTotal);
            });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Round performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                'Ranked by average opponent score on the rounds they win — '
                'higher means their wins tend to come against bigger point totals.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Rank')),
                    DataColumn(label: Text('Player')),
                    DataColumn(label: Text('Games')),
                    DataColumn(label: Text('Rounds')),
                    DataColumn(label: Text('Wins')),
                    DataColumn(label: Text('Win %')),
                    DataColumn(label: Text('Avg score')),
                    DataColumn(label: Text('Avg opp. score on win')),
                  ],
                  rows: [
                    for (var i = 0; i < byOpponentScore.length; i++)
                      DataRow(cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(byOpponentScore[i].name)),
                        DataCell(Text('${byOpponentScore[i].gamesPlayed}')),
                        DataCell(Text('${byOpponentScore[i].roundsPlayed}')),
                        DataCell(Text('${byOpponentScore[i].wins}')),
                        DataCell(Text('${byOpponentScore[i].winPercent.toStringAsFixed(0)}%')),
                        DataCell(Text(_fmt(byOpponentScore[i].avgScore))),
                        DataCell(Text(_fmt(byOpponentScore[i].avgOpponentScoreOnWin))),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text('Payout performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                'Individual = sole recipient of a settlement pot. '
                'Group = split the pot with other remaining players.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Rank')),
                    DataColumn(label: Text('Player')),
                    DataColumn(label: Text('Net ₹')),
                    DataColumn(label: Text('Avg individual payout')),
                    DataColumn(label: Text('Avg group payout')),
                  ],
                  rows: [
                    for (var i = 0; i < byPayout.length; i++)
                      DataRow(cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(byPayout[i].name)),
                        DataCell(Text(
                          '₹${byPayout[i].netAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: byPayout[i].netAmount >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        )),
                        DataCell(Text(
                          byPayout[i].avgIndividualPayout == null
                              ? '—'
                              : '₹${byPayout[i].avgIndividualPayout!.toStringAsFixed(2)}',
                        )),
                        DataCell(Text(
                          byPayout[i].avgGroupPayout == null
                              ? '—'
                              : '₹${byPayout[i].avgGroupPayout!.toStringAsFixed(2)}',
                        )),
                      ]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
