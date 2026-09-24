-- Tabla de partidas: ranking del reto diario + analítica de balance.
-- Correr UNA vez en Supabase → SQL Editor → New query → Run.
-- (El juego funciona sin esto: el ranking dice "no disponible" y las
--  partidas simplemente no se registran.)

create table if not exists public.runs (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  player_name text not null check (char_length(player_name) between 1 and 20),
  hero        text not null,
  map         text not null,
  difficulty  text not null,
  wave        int  not null check (wave between 0 and 1000),
  time_sec    real not null,
  kills       int  not null,
  victory     boolean not null,
  daily_date  date,            -- null = partida normal; fecha = reto diario
  score       int  not null,
  build       jsonb            -- armas/pasivas/evoluciones de la partida
);

alter table public.runs enable row level security;

-- Cualquiera puede leer (ranking público); sólo se insertan partidas propias.
drop policy if exists "runs readable" on public.runs;
create policy "runs readable" on public.runs for select using (true);
drop policy if exists "insert own runs" on public.runs;
create policy "insert own runs" on public.runs for insert to authenticated
  with check (auth.uid() = user_id);

create index if not exists runs_daily_score_idx on public.runs (daily_date, score desc);
create index if not exists runs_created_idx on public.runs (created_at desc);

-- Consultas útiles para balancear:
-- ¿En qué oleada muere la gente?
--   select map, difficulty, wave, count(*) from runs where not victory
--   group by 1,2,3 order by 1,2,3;
-- ¿Qué héroes ganan más?
--   select hero, avg(wave), sum(victory::int) from runs group by hero;
-- ¿Qué evoluciones se consiguen?
--   select jsonb_array_elements_text(build->'evolutions') evo, count(*)
--   from runs group by evo order by 2 desc;
