-- Shared player market: inventory-backed listings and atomic peer-to-peer transfers.
alter table public.nova_competitive_commands
  drop constraint if exists nova_competitive_commands_command_type_check;
alter table public.nova_competitive_commands
  add constraint nova_competitive_commands_command_type_check
  check (command_type in ('operation','asset_upgrade','market_list','market_buy','market_cancel'));

alter table public.nova_competitive_activities
  drop constraint if exists nova_competitive_activities_activity_type_check;
alter table public.nova_competitive_activities
  add constraint nova_competitive_activities_activity_type_check
  check (activity_type in ('joined','operation','asset_upgrade','market_listing','market_sale'));

create table if not exists public.nova_competitive_inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_code text not null check (item_code in ('alloy','circuits','fuel','rare_chip')),
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, item_code)
);

create table if not exists public.nova_market_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  seller_name text not null,
  item_code text not null check (item_code in ('alloy','circuits','fuel','rare_chip')),
  quantity_total integer not null check (quantity_total between 1 and 10000),
  quantity_remaining integer not null check (quantity_remaining between 0 and quantity_total),
  unit_price bigint not null check (unit_price between 1 and 1000000),
  status text not null default 'active' check (status in ('active','sold','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nova_market_orders (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.nova_market_listings(id),
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  item_code text not null check (item_code in ('alloy','circuits','fuel','rare_chip')),
  quantity integer not null check (quantity between 1 and 10000),
  unit_price bigint not null check (unit_price between 1 and 1000000),
  total_price bigint not null check (total_price > 0),
  created_at timestamptz not null default now(),
  check (buyer_id <> seller_id)
);

create table if not exists public.nova_market_inventory_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.nova_market_listings(id),
  item_code text not null check (item_code in ('alloy','circuits','fuel','rare_chip')),
  delta integer not null,
  balance_after integer not null check (balance_after >= 0),
  created_at timestamptz not null default now()
);

create index if not exists nova_market_listings_active_idx
  on public.nova_market_listings (item_code, created_at desc)
  where status = 'active' and quantity_remaining > 0;
create index if not exists nova_market_orders_buyer_created_idx
  on public.nova_market_orders (buyer_id, created_at desc);
create index if not exists nova_market_orders_seller_created_idx
  on public.nova_market_orders (seller_id, created_at desc);
create index if not exists nova_market_inventory_ledger_user_created_idx
  on public.nova_market_inventory_ledger (user_id, created_at desc);

alter table public.nova_competitive_inventory enable row level security;
alter table public.nova_market_listings enable row level security;
alter table public.nova_market_orders enable row level security;
alter table public.nova_market_inventory_ledger enable row level security;

create policy "Players read own competitive inventory"
  on public.nova_competitive_inventory for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Anyone can read active NOVA market listings"
  on public.nova_market_listings for select to anon, authenticated
  using (status = 'active' and quantity_remaining > 0);
create policy "Players read their own market orders"
  on public.nova_market_orders for select to authenticated
  using ((select auth.uid()) = buyer_id or (select auth.uid()) = seller_id);
create policy "Players read their own market inventory ledger"
  on public.nova_market_inventory_ledger for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.nova_competitive_inventory, public.nova_market_listings,
  public.nova_market_orders, public.nova_market_inventory_ledger
  from public, anon, authenticated;
grant select on public.nova_competitive_inventory, public.nova_market_orders,
  public.nova_market_inventory_ledger to authenticated;
grant select on public.nova_market_listings to anon, authenticated;

-- Starter inventory is created by a private trigger when a player profile is initialized.
create or replace function private.nova_seed_competitive_inventory()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.nova_competitive_inventory(user_id, item_code, quantity)
  values
    (new.user_id, 'alloy', 340),
    (new.user_id, 'circuits', 86),
    (new.user_id, 'fuel', 125),
    (new.user_id, 'rare_chip', 4)
  on conflict (user_id, item_code) do nothing;
  return new;
end;
$$;
revoke all on function private.nova_seed_competitive_inventory() from public, anon, authenticated;
drop trigger if exists nova_seed_competitive_inventory on public.nova_competitive_profiles;
create trigger nova_seed_competitive_inventory
  after insert on public.nova_competitive_profiles
  for each row execute function private.nova_seed_competitive_inventory();

insert into public.nova_competitive_inventory(user_id, item_code, quantity)
select p.user_id, seed.item_code, seed.quantity
from public.nova_competitive_profiles p
cross join (values ('alloy',340),('circuits',86),('fuel',125),('rare_chip',4)) as seed(item_code,quantity)
on conflict (user_id, item_code) do nothing;

create or replace function private.nova_market_create_listing(
  p_command_id uuid, p_item_code text, p_quantity integer, p_unit_price bigint
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_available integer;
  v_remaining integer;
  v_name text;
  v_listing public.nova_market_listings%rowtype;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_command_id is null or p_item_code not in ('alloy','circuits','fuel','rare_chip')
     or p_quantity is null or p_quantity not between 1 and 10000
     or p_unit_price is null or p_unit_price not between 1 and 1000000 then
    raise exception 'Invalid market listing details' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text, 0));
  select result into v_existing from public.nova_competitive_commands
    where user_id = v_user_id and command_id = p_command_id;
  if found then return v_existing || jsonb_build_object('replayed', true); end if;

  select quantity into v_available from public.nova_competitive_inventory
    where user_id = v_user_id and item_code = p_item_code for update;
  if not found or v_available < p_quantity then
    raise exception 'Insufficient inventory' using errcode = '22023';
  end if;

  update public.nova_competitive_inventory
    set quantity = quantity - p_quantity, updated_at = now()
    where user_id = v_user_id and item_code = p_item_code
    returning quantity into v_remaining;

  select display_name into v_name from public.nova_competitive_profiles where user_id = v_user_id;
  insert into public.nova_market_listings
    (seller_id, seller_name, item_code, quantity_total, quantity_remaining, unit_price)
  values (v_user_id, v_name, p_item_code, p_quantity, p_quantity, p_unit_price)
  returning * into v_listing;

  insert into public.nova_market_inventory_ledger(user_id, listing_id, item_code, delta, balance_after)
  values (v_user_id, v_listing.id, p_item_code, -p_quantity, v_remaining);

  insert into public.nova_competitive_activities(actor_name, activity_type, headline)
  values (v_name, 'market_listing', v_name || ' عرض ' || p_quantity::text || ' من ' || p_item_code || ' في السوق');

  v_result := jsonb_build_object(
    'success', true, 'listing_id', v_listing.id,
    'item_code', p_item_code, 'quantity_remaining', p_quantity,
    'inventory_remaining', v_remaining
  );
  insert into public.nova_competitive_commands(user_id, command_id, command_type, result)
  values (v_user_id, p_command_id, 'market_list', v_result);
  return v_result;
end;
$$;

create or replace function private.nova_market_buy_listing(
  p_command_id uuid, p_listing_id uuid, p_quantity integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_listing public.nova_market_listings%rowtype;
  v_buyer_wallet public.nova_competitive_wallets%rowtype;
  v_seller_wallet public.nova_competitive_wallets%rowtype;
  v_total bigint;
  v_inventory integer;
  v_result jsonb;
  v_name text;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_command_id is null or p_listing_id is null or p_quantity is null or p_quantity not between 1 and 10000 then
    raise exception 'Invalid purchase details' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text, 0));
  select result into v_existing from public.nova_competitive_commands
    where user_id = v_user_id and command_id = p_command_id;
  if found then return v_existing || jsonb_build_object('replayed', true); end if;

  select * into v_listing from public.nova_market_listings
    where id = p_listing_id and status = 'active' and quantity_remaining > 0
    for update;
  if not found then raise exception 'Listing is no longer available' using errcode = 'P0002'; end if;
  if v_listing.seller_id = v_user_id then raise exception 'You cannot buy your own listing' using errcode = '22023'; end if;
  if p_quantity > v_listing.quantity_remaining then raise exception 'Requested quantity is no longer available' using errcode = '22023'; end if;

  v_total := p_quantity::bigint * v_listing.unit_price;

  -- Lock both wallets in deterministic order to prevent buyer/seller deadlocks.
  perform w.user_id from public.nova_competitive_wallets w
    where w.user_id in (v_user_id, v_listing.seller_id)
    order by w.user_id for update;

  select * into v_buyer_wallet from public.nova_competitive_wallets where user_id = v_user_id;
  select * into v_seller_wallet from public.nova_competitive_wallets where user_id = v_listing.seller_id;
  if v_buyer_wallet.user_id is null or v_seller_wallet.user_id is null then
    raise exception 'Buyer or seller wallet is missing' using errcode = 'P0002';
  end if;
  if v_buyer_wallet.credits < v_total then raise exception 'Insufficient credits' using errcode = '22023'; end if;

  update public.nova_competitive_wallets
    set credits = credits - v_total, updated_at = now()
    where user_id = v_user_id returning * into v_buyer_wallet;
  update public.nova_competitive_wallets
    set credits = credits + v_total, updated_at = now()
    where user_id = v_listing.seller_id returning * into v_seller_wallet;

  insert into public.nova_competitive_inventory(user_id, item_code, quantity)
  values (v_user_id, v_listing.item_code, p_quantity)
  on conflict (user_id, item_code)
  do update set quantity = public.nova_competitive_inventory.quantity + excluded.quantity, updated_at = now()
  returning quantity into v_inventory;

  update public.nova_market_listings
    set quantity_remaining = quantity_remaining - p_quantity,
        status = case when quantity_remaining - p_quantity = 0 then 'sold' else 'active' end,
        updated_at = now()
    where id = p_listing_id;

  insert into public.nova_market_orders(listing_id, buyer_id, seller_id, item_code, quantity, unit_price, total_price)
  values (p_listing_id, v_user_id, v_listing.seller_id, v_listing.item_code, p_quantity, v_listing.unit_price, v_total);

  insert into public.nova_competitive_ledger(user_id, command_id, resource, delta, balance_after)
  values
    (v_user_id, p_command_id, 'credits', -v_total, v_buyer_wallet.credits),
    (v_listing.seller_id, p_command_id, 'credits', v_total, v_seller_wallet.credits);

  insert into public.nova_market_inventory_ledger(user_id, listing_id, item_code, delta, balance_after)
  values (v_user_id, p_listing_id, v_listing.item_code, p_quantity, v_inventory);

  select display_name into v_name from public.nova_competitive_profiles where user_id = v_user_id;
  insert into public.nova_competitive_activities(actor_name, activity_type, headline)
  values (v_name, 'market_sale', v_name || ' اشترى ' || p_quantity::text || ' من ' || v_listing.item_code);

  v_result := jsonb_build_object(
    'success', true, 'quantity', p_quantity, 'total_price', v_total,
    'item_code', v_listing.item_code, 'wallet', to_jsonb(v_buyer_wallet)
  );
  insert into public.nova_competitive_commands(user_id, command_id, command_type, result)
  values (v_user_id, p_command_id, 'market_buy', v_result);
  return v_result;
end;
$$;

create or replace function private.nova_market_cancel_listing(p_command_id uuid, p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_listing public.nova_market_listings%rowtype;
  v_inventory integer;
  v_result jsonb;
  v_name text;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_command_id is null or p_listing_id is null then
    raise exception 'Command id and listing id are required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text, 0));
  select result into v_existing from public.nova_competitive_commands
    where user_id = v_user_id and command_id = p_command_id;
  if found then return v_existing || jsonb_build_object('replayed', true); end if;

  select * into v_listing from public.nova_market_listings
    where id = p_listing_id and seller_id = v_user_id
    for update;
  if not found then raise exception 'Listing not found or not owned by player' using errcode = 'P0002'; end if;
  if v_listing.status <> 'active' or v_listing.quantity_remaining <= 0 then
    raise exception 'Listing cannot be cancelled' using errcode = '22023';
  end if;

  insert into public.nova_competitive_inventory(user_id, item_code, quantity)
  values (v_user_id, v_listing.item_code, v_listing.quantity_remaining)
  on conflict (user_id, item_code)
  do update set quantity = public.nova_competitive_inventory.quantity + excluded.quantity, updated_at = now()
  returning quantity into v_inventory;

  update public.nova_market_listings set status = 'cancelled', updated_at = now()
    where id = p_listing_id;

  insert into public.nova_market_inventory_ledger(user_id, listing_id, item_code, delta, balance_after)
  values (v_user_id, p_listing_id, v_listing.item_code, v_listing.quantity_remaining, v_inventory);

  select display_name into v_name from public.nova_competitive_profiles where user_id = v_user_id;
  insert into public.nova_competitive_activities(actor_name, activity_type, headline)
  values (v_name, 'market_listing', v_name || ' ألغى عرضاً في السوق');

  v_result := jsonb_build_object('success', true, 'returned_quantity', v_listing.quantity_remaining, 'item_code', v_listing.item_code);
  insert into public.nova_competitive_commands(user_id, command_id, command_type, result)
  values (v_user_id, p_command_id, 'market_cancel', v_result);
  return v_result;
end;
$$;

revoke all on function private.nova_market_create_listing(uuid,text,integer,bigint) from public, anon, authenticated;
revoke all on function private.nova_market_buy_listing(uuid,uuid,integer) from public, anon, authenticated;
revoke all on function private.nova_market_cancel_listing(uuid,uuid) from public, anon, authenticated;
grant execute on function private.nova_market_create_listing(uuid,text,integer,bigint) to authenticated;
grant execute on function private.nova_market_buy_listing(uuid,uuid,integer) to authenticated;
grant execute on function private.nova_market_cancel_listing(uuid,uuid) to authenticated;

create or replace function public.nova_market_create_listing(
  p_command_id uuid, p_item_code text, p_quantity integer, p_unit_price bigint
)
returns jsonb language sql security invoker
set search_path = pg_catalog, public, private
as $$ select private.nova_market_create_listing(p_command_id,p_item_code,p_quantity,p_unit_price); $$;

create or replace function public.nova_market_buy_listing(
  p_command_id uuid, p_listing_id uuid, p_quantity integer
)
returns jsonb language sql security invoker
set search_path = pg_catalog, public, private
as $$ select private.nova_market_buy_listing(p_command_id,p_listing_id,p_quantity); $$;

create or replace function public.nova_market_cancel_listing(p_command_id uuid, p_listing_id uuid)
returns jsonb language sql security invoker
set search_path = pg_catalog, public, private
as $$ select private.nova_market_cancel_listing(p_command_id,p_listing_id); $$;

revoke all on function public.nova_market_create_listing(uuid,text,integer,bigint) from public, anon;
revoke all on function public.nova_market_buy_listing(uuid,uuid,integer) from public, anon;
revoke all on function public.nova_market_cancel_listing(uuid,uuid) from public, anon;
grant execute on function public.nova_market_create_listing(uuid,text,integer,bigint) to authenticated;
grant execute on function public.nova_market_buy_listing(uuid,uuid,integer) to authenticated;
grant execute on function public.nova_market_cancel_listing(uuid,uuid) to authenticated;
