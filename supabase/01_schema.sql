-- VocaBoost · Supabase schema
-- Run in the Supabase SQL Editor (Dashboard -> SQL Editor -> New query).
-- Safe to run more than once.

-- ---------------------------------------------------------------------------
-- 1. Vocabulary list (shared by every signed-in user)
-- ---------------------------------------------------------------------------
create table if not exists public.words (
  id      bigint generated always as identity primary key,
  word    text not null unique,
  meaning text not null default ''
);

comment on table public.words is 'Shared vocabulary list. Read-only for signed-in users.';

-- ---------------------------------------------------------------------------
-- 2. Words a user has saved. `type` marks where the word came from.
-- ---------------------------------------------------------------------------
create table if not exists public.saved_words (
  id         bigint generated always as identity primary key,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  word       text not null,
  meaning    text not null default '',
  type       text not null default 'extra' check (type in ('daily', 'extra', 'learned')),
  day        date not null default current_date,
  created_at timestamptz not null default now()
);

comment on table public.saved_words is 'Per-user saved vocabulary, grouped by day in Revision History.';
comment on column public.saved_words.day is 'Calendar day the word belongs to. Send this from the client so it matches the user local date; the default uses the database date (UTC).';

-- Rule: at most one 'daily' word per user per day.
-- Enforced by a partial unique index, so extras and learned words stay unlimited.
create unique index if not exists saved_words_one_daily_per_day
  on public.saved_words (user_id, day)
  where type = 'daily';

-- Supports the Revision History query: newest day first, newest row first.
create index if not exists saved_words_user_day_idx
  on public.saved_words (user_id, day desc, created_at desc);

-- ---------------------------------------------------------------------------
-- 3. Profile (one row per user)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  name    text not null default ''
);

comment on table public.profiles is 'Display name for a signed-in user.';

-- ---------------------------------------------------------------------------
-- 4. Row Level Security
-- ---------------------------------------------------------------------------
alter table public.words       enable row level security;
alter table public.saved_words enable row level security;
alter table public.profiles    enable row level security;

-- words: every signed-in user can read the list, nobody can change it from the client.
drop policy if exists "Signed-in users can read words" on public.words;
create policy "Signed-in users can read words"
  on public.words
  for select
  to authenticated
  using (true);

-- saved_words: a user can only see and change rows they own.
drop policy if exists "Users manage their own saved words" on public.saved_words;
create policy "Users manage their own saved words"
  on public.saved_words
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- profiles: a user can only see and change their own profile.
drop policy if exists "Users manage their own profile" on public.profiles;
create policy "Users manage their own profile"
  on public.profiles
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
