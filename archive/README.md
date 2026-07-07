# Points Rummy Scorer

Flutter app for scoring Points Rummy across a shared game night, synced
live across devices via Supabase (Postgres + Realtime).

## One-time setup

1. Create a project at https://supabase.com/dashboard
2. Go to **Project Settings -> API** and copy:
   - **Project URL** -> `supabaseUrl` in `lib/supabase_config.dart`
   - **anon public** key -> `supabaseAnonKey` in `lib/supabase_config.dart`
3. Go to the **SQL Editor**, paste the contents of `supabase/schema.sql`,
   and run it once. This creates all five tables, indexes, enables
   realtime on them, and sets up (wide-open, for now) row level security.
4. Go to **Database -> Replication** and double check `players`,
   `config_defaults`, `games`, `rounds`, and `settlements` are listed
   under realtime (the schema script enables this, but worth confirming).
5. `flutter pub get`
6. `flutter run`

## Schema

```
players(id, name, created_at)
config_defaults(id=1, point_value, max_score_per_hand, max_game_points, first_drop, middle_drop)
games(id, players jsonb, point_value, max_score_per_hand, max_game_points,
      first_drop, middle_drop, status, created_at, closed_at)
rounds(id, game_id -> games.id, round_number, scores jsonb, score_labels jsonb, winner_id, created_at)
settlements(id, game_id -> games.id, after_round, amounts jsonb, created_at)
```

IDs are generated **client-side** (UUIDs for players/rounds/settlements
via the `uuid` package, a timestamp string for games) rather than left
to Postgres defaults. This is deliberate groundwork for stage 2 (offline
support) -- a client can't wait on a server round-trip for an ID while
offline, so IDs need to exist before the write is even attempted.

## What's implemented (stage 1 of the Supabase migration -- online only)

Every feature from the Firebase version, now backed by Supabase:

- Home screen with **In Progress / Past Games / Dashboard** tabs
- **Players**: shared registry, add/remove
- **New Game**: pick players, override point value / max points / first
  drop / middle drop / full count per game (pre-filled from Config defaults)
- **Config screen**: edit the defaults every new game starts from
- **Game view (Scoreboard)**: players as rows (entry order), columns are
  Player · Total · R:N · R:N-1 · ... · R:1 (most recent first), with a
  row of per-round edit buttons at the bottom that recalculate totals
  live on save
- **Round entry / Edit Round**: table of Player | Score | W | D | MD --
  choosing one of the four per row disables the other three until
  toggled off; only one player can hold "W" at a time
- **Settle Up**: usable at any point in the game; auto-eliminated
  players are locked in as "out"; pot is suggested-split proportionally
  but every amount is editable; settlement history is recorded
- **Dashboard analytics**: per-player win %, avg score, avg opponent
  score on wins (ranked), net ₹, and avg individual vs. group payout
  (ranked) -- computed client-side from `rounds`/`settlements`/`games`

## What changed vs. the Firebase version

- **Realtime**: Supabase's `.stream()` API replaces Firestore snapshot
  listeners -- same live cross-device updates, different plumbing.
- **Dashboard analytics**: currently still aggregated client-side in
  Dart (same logic as before), even though this data is now relational.
  A natural follow-up optimization is moving this into a Postgres view
  or RPC function so the aggregation happens server-side instead of
  pulling every row to the device.
- **Offline support**: intentionally **not implemented yet**. Supabase's
  client is a REST + websocket client with no built-in local cache --
  unlike Firestore, a write attempted with no connection just fails.
  This is stage 2, planned as: local storage (Hive) as a write queue and
  read-through cache, `connectivity_plus` for immediate reconnect
  detection (plus a periodic backup poll), and client-generated IDs
  (already in place) so new games/rounds/settlements can be created
  offline and pushed up once back online.

## Coming in phase 2 (unrelated to the offline work above)

- Admin PIN gate -- a hidden way to unlock edit/create actions, with
  everyone else viewing read-only. Supabase Auth + row level security
  policies are a natural fit for this once it's built -- the current
  schema's RLS policies are wide open and should be tightened
  alongside it.
