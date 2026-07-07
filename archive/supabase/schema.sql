-- Points Rummy Scorer -- Supabase schema
-- Run this once in your project's SQL editor (Dashboard -> SQL Editor -> New query).

create extension if not exists pgcrypto;

create table if not exists players (
  id text primary key,             -- client-generated UUID (see uuid package in the app)
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists config_defaults (
  id int primary key default 1,
  point_value numeric not null default 1,
  max_score_per_hand int not null default 80,
  max_game_points int not null default 200,
  first_drop int not null default 20,
  middle_drop int not null default 40,
  constraint single_row check (id = 1)
);
insert into config_defaults (id) values (1) on conflict (id) do nothing;

create table if not exists games (
  id text primary key,             -- timestamped id, e.g. game_20260707_154230123
  players jsonb not null,          -- embedded snapshot: [{"id":..,"name":..}, ...]
  point_value numeric not null,
  max_score_per_hand int not null,
  max_game_points int not null,
  first_drop int not null,
  middle_drop int not null,
  status text not null default 'in_progress' check (status in ('in_progress', 'closed')),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create table if not exists rounds (
  id text primary key,             -- client-generated UUID
  game_id text not null references games(id) on delete cascade,
  round_number int not null,
  scores jsonb not null,           -- {"playerId": points}
  score_labels jsonb not null,     -- {"playerId": "Winner" | "First Drop" | "Middle Drop" | "Custom"}
  winner_id text not null,
  created_at timestamptz not null default now()
);

create table if not exists settlements (
  id text primary key,             -- client-generated UUID
  game_id text not null references games(id) on delete cascade,
  after_round int not null,
  amounts jsonb not null,          -- {"playerId": netAmount}  (negative = paid in, positive = received)
  created_at timestamptz not null default now()
);

create index if not exists rounds_game_id_idx on rounds(game_id);
create index if not exists settlements_game_id_idx on settlements(game_id);
create index if not exists games_status_idx on games(status);

-- Realtime: required for live cross-device updates (the equivalent of
-- Firestore's snapshot listeners).
alter publication supabase_realtime add table players, config_defaults, games, rounds, settlements;

-- Row Level Security. Wide open for now since there's no auth yet --
-- phase 2 (admin PIN / roles) should replace these with real policies
-- restricting writes, e.g. only allowing writes from an authenticated
-- admin role while everyone can still read.
alter table players enable row level security;
alter table config_defaults enable row level security;
alter table games enable row level security;
alter table rounds enable row level security;
alter table settlements enable row level security;

create policy "open read/write players" on players for all using (true) with check (true);
create policy "open read/write config" on config_defaults for all using (true) with check (true);
create policy "open read/write games" on games for all using (true) with check (true);
create policy "open read/write rounds" on rounds for all using (true) with check (true);
create policy "open read/write settlements" on settlements for all using (true) with check (true);
