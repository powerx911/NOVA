-- NOVA first server-authoritative player foundation.
-- Apply only after this migration is reviewed and merged through GitHub.
create extension if not exists pgcrypto;

create table if not exists public.nova_player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 3 and 24),
  created_at timestamptz not null default now()
);

create table if not exists public.nova_player_economy (
  user_id uuid primary key references auth.users(id) on delete cascade,
  food bigint not null default 1200 check (food >= 0),
  wood bigint not null default 900 check (wood >= 0),
  stone bigint not null default 700 check (stone >= 0),
  iron bigint not null default 350 check (iron >= 0),
  gold bigint not null default 250 check (gold >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.nova_castles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  kingdom_id text not null default 'kingdom-1',
  castle_name text not null default 'قلعة البداية',
  map_x integer not null default (floor(random() * 1000)::integer),
  map_y integer not null default (floor(random() * 1000)::integer),
  created_at timestamptz not null default now(),
  unique (kingdom_id, map_x, map_y)
);

create table if not exists public.nova_buildings (
  id uuid primary key default gen_random_uuid(),
  castle_id uuid not null references public.nova_castles(id) on delete cascade,
  building_type text not null check (building_type in ('town_hall', 'farm', 'lumber_mill', 'quarry', 'iron_mine', 'barracks')),
  level integer not null default 1 check (level between 1 and 30),
  updated_at timestamptz not null default now(),
  unique (castle_id, building_type)
);

create table if not exists public.nova_command_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  command_id uuid not null,
  command_type text not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  unique (user_id, command_id)
);

create table if not exists public.nova_resource_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  command_id uuid not null,
  resource text not null check (resource in ('food', 'wood', 'stone', 'iron', 'gold')),
  delta bigint not null,
  balance_after bigint not null check (balance_after >= 0),
  created_at timestamptz not null default now()
);

create index if not exists nova_resource_ledger_user_created_idx
  on public.nova_resource_ledger (user_id, created_at desc);
create index if not exists nova_command_receipts_user_created_idx
  on public.nova_command_receipts (user_id, created_at desc);

alter table public.nova_player_profiles enable row level security;
alter table public.nova_player_economy enable row level security;
alter table public.nova_castles enable row level security;
alter table public.nova_buildings enable row level security;
alter table public.nova_command_receipts enable row level security;
alter table public.nova_resource_ledger enable row level security;

create policy "Players can read their own profile"
  on public.nova_player_profiles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players can create their own profile"
  on public.nova_player_profiles for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Players can rename their own profile"
  on public.nova_player_profiles for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Players can read their own economy"
  on public.nova_player_economy for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players can read their own castle"
  on public.nova_castles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players can read buildings in their own castle"
  on public.nova_buildings for select to authenticated
  using (exists (
    select 1 from public.nova_castles c
    where c.id = castle_id and c.user_id = (select auth.uid())
  ));
create policy "Players can read their own command receipts"
  on public.nova_command_receipts for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Players can read their own resource ledger"
  on public.nova_resource_ledger for select to authenticated
  using ((select auth.uid()) = user_id);

-- Clients may create a profile, but initial balances/castle/buildings are granted only here.
create or replace function public.nova_initialize_player(p_display_name text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_castle_id uuid;
  v_attempt integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_display_name is null or char_length(trim(p_display_name)) not between 3 and 24 then
    raise exception 'Display name must be 3 to 24 characters' using errcode = '22023';
  end if;

  insert into public.nova_player_profiles (user_id, display_name)
  values (v_user_id, trim(p_display_name))
  on conflict (user_id) do nothing;

  insert into public.nova_player_economy (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  for v_attempt in 1..20 loop
    insert into public.nova_castles (user_id)
    values (v_user_id)
    on conflict do nothing
    returning id into v_castle_id;
    if v_castle_id is not null then
      exit;
    end if;
    select id into v_castle_id from public.nova_castles where user_id = v_user_id;
    if v_castle_id is not null then
      exit;
    end if;
  end loop;
  if v_castle_id is null then
    raise exception 'Could not allocate a free castle location' using errcode = 'P0001';
  end if;

  insert into public.nova_buildings (castle_id, building_type)
  values
    (v_castle_id, 'town_hall'),
    (v_castle_id, 'farm'),
    (v_castle_id, 'lumber_mill'),
    (v_castle_id, 'quarry'),
    (v_castle_id, 'iron_mine'),
    (v_castle_id, 'barracks')
  on conflict (castle_id, building_type) do nothing;

  return jsonb_build_object('initialized', true, 'castle_id', v_castle_id);
end;
$$;

-- All economy mutation happens in this single transaction. The client supplies only
-- an idempotency key and building id; costs and ownership are resolved server-side.
create or replace function public.nova_upgrade_building(
  p_command_id uuid,
  p_building_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_receipt jsonb;
  v_castle_id uuid;
  v_building_type text;
  v_level integer;
  v_wood_cost bigint;
  v_stone_cost bigint;
  v_iron_cost bigint;
  v_food_cost bigint;
  v_wood bigint;
  v_stone bigint;
  v_iron bigint;
  v_food bigint;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_command_id is null or p_building_id is null then
    raise exception 'Command id and building id are required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || p_command_id::text, 0));

  select result into v_receipt
  from public.nova_command_receipts
  where user_id = v_user_id and command_id = p_command_id;
  if found then
    return v_receipt || jsonb_build_object('replayed', true);
  end if;

  select b.castle_id, b.building_type, b.level
    into v_castle_id, v_building_type, v_level
  from public.nova_buildings b
  join public.nova_castles c on c.id = b.castle_id
  where b.id = p_building_id and c.user_id = v_user_id
  for update of b;

  if not found then
    raise exception 'Building not found or not owned by player' using errcode = 'P0002';
  end if;
  if v_level >= 30 then
    raise exception 'Building is already at maximum level' using errcode = '22023';
  end if;

  v_wood_cost := 100 * v_level;
  v_stone_cost := 80 * v_level;
  v_iron_cost := case when v_building_type in ('town_hall', 'barracks', 'iron_mine') then 25 * v_level else 10 * v_level end;
  v_food_cost := 40 * v_level;

  select food, wood, stone, iron
    into v_food, v_wood, v_stone, v_iron
  from public.nova_player_economy
  where user_id = v_user_id
  for update;

  if not found then
    raise exception 'Player economy is not initialized' using errcode = 'P0002';
  end if;
  if v_food < v_food_cost or v_wood < v_wood_cost or v_stone < v_stone_cost or v_iron < v_iron_cost then
    raise exception 'Insufficient resources' using errcode = '22023';
  end if;

  update public.nova_player_economy
  set food = food - v_food_cost,
      wood = wood - v_wood_cost,
      stone = stone - v_stone_cost,
      iron = iron - v_iron_cost,
      updated_at = now()
  where user_id = v_user_id
  returning food, wood, stone, iron into v_food, v_wood, v_stone, v_iron;

  update public.nova_buildings
  set level = level + 1, updated_at = now()
  where id = p_building_id
  returning level into v_level;

  insert into public.nova_resource_ledger (user_id, command_id, resource, delta, balance_after)
  values
    (v_user_id, p_command_id, 'food', -v_food_cost, v_food),
    (v_user_id, p_command_id, 'wood', -v_wood_cost, v_wood),
    (v_user_id, p_command_id, 'stone', -v_stone_cost, v_stone),
    (v_user_id, p_command_id, 'iron', -v_iron_cost, v_iron);

  v_result := jsonb_build_object(
    'success', true,
    'building_id', p_building_id,
    'building_type', v_building_type,
    'level', v_level,
    'cost', jsonb_build_object('food', v_food_cost, 'wood', v_wood_cost, 'stone', v_stone_cost, 'iron', v_iron_cost),
    'resources', jsonb_build_object('food', v_food, 'wood', v_wood, 'stone', v_stone, 'iron', v_iron)
  );

  insert into public.nova_command_receipts (user_id, command_id, command_type, result)
  values (v_user_id, p_command_id, 'upgrade_building', v_result);

  return v_result;
end;
$$;

revoke all on function public.nova_initialize_player(text) from public, anon;
revoke all on function public.nova_upgrade_building(uuid, uuid) from public, anon;
grant execute on function public.nova_initialize_player(text) to authenticated;
grant execute on function public.nova_upgrade_building(uuid, uuid) to authenticated;

revoke all on public.nova_player_profiles, public.nova_player_economy, public.nova_castles,
  public.nova_buildings, public.nova_command_receipts, public.nova_resource_ledger
  from public, anon, authenticated;

grant select, insert, update on public.nova_player_profiles to authenticated;
grant select on public.nova_player_economy, public.nova_castles, public.nova_buildings,
  public.nova_command_receipts, public.nova_resource_ledger to authenticated;
