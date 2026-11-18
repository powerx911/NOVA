-- NOVA competitive simulation: authenticated player identity, server-owned economy,
-- upgradeable assets, idempotent operations, safe public leaderboard and live activity.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to anon, authenticated;

create table if not exists public.nova_competitive_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 3 and 24),
  created_at timestamptz not null default now()
);
create unique index if not exists nova_competitive_profiles_name_ci
  on public.nova_competitive_profiles (lower(display_name));

create table if not exists public.nova_competitive_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  credits bigint not null default 24850 check (credits >= 0),
  energy integer not null default 76 check (energy between 0 and 100),
  influence bigint not null default 1240 check (influence >= 0),
  net_worth bigint not null default 186420 check (net_worth >= 0),
  power bigint not null default 2860 check (power >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.nova_competitive_assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  asset_code text not null check (asset_code in ('supply_hub','orion_lab','manufacturing')),
  level integer not null default 1 check (level between 1 and 30),
  base_income bigint not null check (base_income > 0),
  income_per_hour bigint not null check (income_per_hour > 0),
  base_value bigint not null check (base_value > 0),
  asset_value bigint not null check (asset_value > 0),
  updated_at timestamptz not null default now(),
  unique (user_id, asset_code)
);

create table if not exists public.nova_competitive_commands (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  command_id uuid not null,
  command_type text not null check (command_type in ('operation','asset_upgrade')),
  result jsonb not null,
  created_at timestamptz not null default now(),
  unique (user_id, command_id)
);

create table if not exists public.nova_competitive_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  command_id uuid not null,
  resource text not null check (resource in ('credits','energy','influence')),
  delta bigint not null,
  balance_after bigint not null check (balance_after >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.nova_competitive_activities (
  id bigint generated always as identity primary key,
  actor_name text not null,
  activity_type text not null check (activity_type in ('joined','operation','asset_upgrade')),
  headline text not null check (char_length(headline) between 3 and 180),
  created_at timestamptz not null default now()
);

create index if not exists nova_competitive_ledger_user_created_idx
  on public.nova_competitive_ledger (user_id, created_at desc);
create index if not exists nova_competitive_commands_user_created_idx
  on public.nova_competitive_commands (user_id, created_at desc);
create index if not exists nova_competitive_activities_created_idx
  on public.nova_competitive_activities (created_at desc);

alter table public.nova_competitive_profiles enable row level security;
alter table public.nova_competitive_wallets enable row level security;
alter table public.nova_competitive_assets enable row level security;
alter table public.nova_competitive_commands enable row level security;
alter table public.nova_competitive_ledger enable row level security;
alter table public.nova_competitive_activities enable row level security;

create policy "Players read own competitive profile"
  on public.nova_competitive_profiles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players read own competitive wallet"
  on public.nova_competitive_wallets for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players read own competitive assets"
  on public.nova_competitive_assets for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players read own competitive commands"
  on public.nova_competitive_commands for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players read own competitive ledger"
  on public.nova_competitive_ledger for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Anyone can read public NOVA activity"
  on public.nova_competitive_activities for select to anon, authenticated
  using (true);

revoke all on public.nova_competitive_profiles, public.nova_competitive_wallets,
  public.nova_competitive_assets, public.nova_competitive_commands,
  public.nova_competitive_ledger, public.nova_competitive_activities
  from public, anon, authenticated;
grant select on public.nova_competitive_profiles, public.nova_competitive_wallets,
  public.nova_competitive_assets, public.nova_competitive_commands,
  public.nova_competitive_ledger to authenticated;
grant select on public.nova_competitive_activities to anon, authenticated;

-- The profile name is supplied by the player, validated here, and never used for auth.
create or replace function private.nova_competitive_initialize(p_display_name text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_name text := trim(coalesce(p_display_name, ''));
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if char_length(v_name) not between 3 and 24 or v_name ~ '[[:cntrl:]]' then
    raise exception 'Display name must be 3 to 24 characters' using errcode = '22023';
  end if;

  insert into public.nova_competitive_profiles(user_id, display_name)
  values (v_user_id, v_name)
  on conflict (user_id) do nothing;

  if not exists (select 1 from public.nova_competitive_profiles where user_id = v_user_id) then
    raise exception 'Could not create player profile' using errcode = 'P0001';
  end if;

  insert into public.nova_competitive_wallets(user_id)
  values (v_user_id) on conflict (user_id) do nothing;

  insert into public.nova_competitive_assets
    (user_id, asset_code, level, base_income, income_per_hour, base_value, asset_value)
  values
    (v_user_id, 'supply_hub', 1, 420, 420, 2500, 2500),
    (v_user_id, 'orion_lab', 1, 280, 280, 1800, 1800),
    (v_user_id, 'manufacturing', 1, 540, 540, 3200, 3200)
  on conflict (user_id, asset_code) do nothing;

  insert into public.nova_competitive_activities(actor_name, activity_type, headline)
  values (v_name, 'joined', v_name || ' انضم إلى NOVA')
  on conflict do nothing;

  return jsonb_build_object('initialized', true);
end;
$$;

create or replace function private.nova_competitive_simulate(p_command_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_wallet public.nova_competitive_wallets%rowtype;
  v_reward bigint;
  v_result jsonb;
  v_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_command_id is null then
    raise exception 'Command id is required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text, 0));
  select result into v_existing from public.nova_competitive_commands
    where user_id = v_user_id and command_id = p_command_id;
  if found then return v_existing || jsonb_build_object('replayed', true); end if;

  select * into v_wallet from public.nova_competitive_wallets
    where user_id = v_user_id for update;
  if not found then raise exception 'Player is not initialized' using errcode = 'P0002'; end if;
  if v_wallet.energy < 10 then raise exception 'Insufficient energy' using errcode = '22023'; end if;

  v_reward := 250 + floor(v_wallet.power::numeric / 25)::bigint;
  update public.nova_competitive_wallets
    set energy = energy - 10,
        credits = credits + v_reward,
        influence = influence + 10,
        net_worth = net_worth + v_reward,
        updated_at = now()
    where user_id = v_user_id
    returning * into v_wallet;

  insert into public.nova_competitive_ledger(user_id, command_id, resource, delta, balance_after)
  values
    (v_user_id, p_command_id, 'energy', -10, v_wallet.energy),
    (v_user_id, p_command_id, 'credits', v_reward, v_wallet.credits),
    (v_user_id, p_command_id, 'influence', 10, v_wallet.influence);

  select display_name into v_name from public.nova_competitive_profiles where user_id = v_user_id;
  insert into public.nova_competitive_activities(actor_name, activity_type, headline)
  values (v_name, 'operation', v_name || ' أكمل عملية وحقق ' || v_reward::text || ' رصيد');

  v_result := jsonb_build_object('success', true, 'reward', v_reward, 'wallet', to_jsonb(v_wallet));
  insert into public.nova_competitive_commands(user_id, command_id, command_type, result)
  values (v_user_id, p_command_id, 'operation', v_result);
  return v_result;
end;
$$;

create or replace function private.nova_competitive_upgrade_asset(p_command_id uuid, p_asset_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_asset public.nova_competitive_assets%rowtype;
  v_wallet public.nova_competitive_wallets%rowtype;
  v_cost bigint;
  v_result jsonb;
  v_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_command_id is null or p_asset_id is null then
    raise exception 'Command id and asset id are required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text, 0));
  select result into v_existing from public.nova_competitive_commands
    where user_id = v_user_id and command_id = p_command_id;
  if found then return v_existing || jsonb_build_object('replayed', true); end if;

  select * into v_asset from public.nova_competitive_assets
    where id = p_asset_id and user_id = v_user_id for update;
  if not found then raise exception 'Asset not found or not owned by player' using errcode = 'P0002'; end if;
  if v_asset.level >= 30 then raise exception 'Asset is at maximum level' using errcode = '22023'; end if;

  select * into v_wallet from public.nova_competitive_wallets
    where user_id = v_user_id for update;
  if not found then raise exception 'Player is not initialized' using errcode = 'P0002'; end if;

  v_cost := 1800 * v_asset.level;
  if v_wallet.credits < v_cost then raise exception 'Insufficient credits' using errcode = '22023'; end if;

  update public.nova_competitive_assets
    set level = level + 1,
        income_per_hour = base_income * (level + 1),
        asset_value = asset_value + base_value,
        updated_at = now()
    where id = p_asset_id returning * into v_asset;

  update public.nova_competitive_wallets
    set credits = credits - v_cost,
        net_worth = net_worth + v_asset.base_value,
        power = power + 85,
        updated_at = now()
    where user_id = v_user_id returning * into v_wallet;

  insert into public.nova_competitive_ledger(user_id, command_id, resource, delta, balance_after)
  values (v_user_id, p_command_id, 'credits', -v_cost, v_wallet.credits);

  select display_name into v_name from public.nova_competitive_profiles where user_id = v_user_id;
  insert into public.nova_competitive_activities(actor_name, activity_type, headline)
  values (v_name, 'asset_upgrade', v_name || ' طوّر أحد أصوله إلى المستوى ' || v_asset.level::text);

  v_result := jsonb_build_object('success', true, 'cost', v_cost, 'asset', to_jsonb(v_asset), 'wallet', to_jsonb(v_wallet));
  insert into public.nova_competitive_commands(user_id, command_id, command_type, result)
  values (v_user_id, p_command_id, 'asset_upgrade', v_result);
  return v_result;
end;
$$;

create or replace function private.nova_competitive_leaderboard()
returns table(display_name text, net_worth bigint, power bigint, rank_position bigint)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.display_name, w.net_worth, w.power,
         dense_rank() over (order by w.net_worth desc, w.power desc) as rank_position
  from public.nova_competitive_profiles p
  join public.nova_competitive_wallets w on w.user_id = p.user_id
  order by w.net_worth desc, w.power desc
  limit 100;
$$;

revoke all on function private.nova_competitive_initialize(text) from public, anon, authenticated;
revoke all on function private.nova_competitive_simulate(uuid) from public, anon, authenticated;
revoke all on function private.nova_competitive_upgrade_asset(uuid, uuid) from public, anon, authenticated;
revoke all on function private.nova_competitive_leaderboard() from public, anon, authenticated;
grant execute on function private.nova_competitive_initialize(text) to authenticated;
grant execute on function private.nova_competitive_simulate(uuid) to authenticated;
grant execute on function private.nova_competitive_upgrade_asset(uuid, uuid) to authenticated;
grant execute on function private.nova_competitive_leaderboard() to anon, authenticated;

create or replace function public.nova_competitive_initialize(p_display_name text)
returns jsonb language sql security invoker
set search_path = pg_catalog, public, private
as $$ select private.nova_competitive_initialize(p_display_name); $$;
create or replace function public.nova_competitive_simulate(p_command_id uuid)
returns jsonb language sql security invoker
set search_path = pg_catalog, public, private
as $$ select private.nova_competitive_simulate(p_command_id); $$;
create or replace function public.nova_competitive_upgrade_asset(p_command_id uuid, p_asset_id uuid)
returns jsonb language sql security invoker
set search_path = pg_catalog, public, private
as $$ select private.nova_competitive_upgrade_asset(p_command_id, p_asset_id); $$;
create or replace function public.nova_competitive_leaderboard()
returns table(display_name text, net_worth bigint, power bigint, rank_position bigint)
language sql stable security invoker
set search_path = pg_catalog, public, private
as $$ select * from private.nova_competitive_leaderboard(); $$;

revoke all on function public.nova_competitive_initialize(text) from public, anon;
revoke all on function public.nova_competitive_simulate(uuid) from public, anon;
revoke all on function public.nova_competitive_upgrade_asset(uuid, uuid) from public, anon;
revoke all on function public.nova_competitive_leaderboard() from public;
grant execute on function public.nova_competitive_initialize(text) to authenticated;
grant execute on function public.nova_competitive_simulate(uuid) to authenticated;
grant execute on function public.nova_competitive_upgrade_asset(uuid, uuid) to authenticated;
grant execute on function public.nova_competitive_leaderboard() to anon, authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'nova_competitive_activities'
     ) then
    alter publication supabase_realtime add table public.nova_competitive_activities;
  end if;
end;
$$;
