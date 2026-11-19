-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Original remote migration: nexora_core_schema_v1
-- Remote migration version: 20261118170627
-- Source evidence: Supabase postgres_logs, parsed.timestamp 2026-11-18 17:06:27.480 UTC
-- Recovered on: 2026-11-19
-- This file is intentionally outside supabase/migrations/.
-- It preserves the SQL body logged during the original POST /mcp execution.
-- Review and compare it against the production catalog before any future migration-history reconciliation.
-- No production DDL was executed during recovery.

create schema if not exists nexora;
revoke all on schema nexora from public, anon, authenticated;
grant usage on schema nexora to service_role;

create table nexora.player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null check (char_length(username) between 3 and 24),
  username_lower text not null unique,
  avatar_id text not null default 'strategist',
  title text not null default 'newcomer',
  level integer not null default 1 check (level >= 1),
  xp bigint not null default 0 check (xp >= 0),
  reputation bigint not null default 0 check (reputation >= 0),
  influence bigint not null default 0 check (influence >= 0),
  skill_points integer not null default 0 check (skill_points >= 0),
  skills jsonb not null default '{}'::jsonb,
  stats jsonb not null default '{}'::jsonb,
  org_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table nexora.player_private (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  language text not null default 'ar' check (language in ('ar','en')),
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table nexora.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance bigint not null default 2500 check (balance >= 0),
  total_earned bigint not null default 0 check (total_earned >= 0),
  total_spent bigint not null default 0 check (total_spent >= 0),
  last_tx_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table nexora.transactions (
  id text primary key,
  from_uid uuid references auth.users(id),
  to_uid uuid references auth.users(id),
  amount bigint not null check (amount >= 0),
  fee bigint not null default 0 check (fee >= 0),
  net_amount bigint not null check (net_amount >= 0),
  type text not null,
  reference_id text not null default '',
  description text not null default '',
  status text not null default 'completed' check (status = 'completed'),
  created_at timestamptz not null default now()
);

create table nexora.inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null,
  quantity bigint not null default 0 check (quantity >= 0),
  last_listing_id text,
  updated_at timestamptz not null default now(),
  primary key (user_id,item_id)
);

create table nexora.market_listings (
  id text primary key,
  seller_uid uuid not null references auth.users(id),
  seller_name text not null,
  item_id text not null,
  quantity integer not null check (quantity > 0),
  remaining_qty integer not null check (remaining_qty >= 0 and remaining_qty <= quantity),
  unit_price bigint not null check (unit_price > 0),
  status text not null default 'active' check (status in ('active','sold','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table nexora.market_orders (
  id text primary key,
  listing_id text not null references nexora.market_listings(id),
  buyer_uid uuid not null references auth.users(id),
  seller_uid uuid not null references auth.users(id),
  item_id text not null,
  quantity integer not null check (quantity > 0),
  unit_price bigint not null check (unit_price > 0),
  total_price bigint not null check (total_price > 0),
  tax_amount bigint not null default 0 check (tax_amount >= 0),
  tx_id text references nexora.transactions(id),
  created_at timestamptz not null default now()
);

create table nexora.companies (
  id text primary key,
  owner_uid uuid not null references auth.users(id),
  owner_name text not null,
  name text not null,
  sector text not null check (sector in ('trade','manufacturing','services','tech','logistics')),
  level integer not null default 1 check (level >= 1),
  capital bigint not null default 0 check (capital >= 0),
  employees_count integer not null default 0 check (employees_count >= 0),
  base_revenue_per_hour bigint not null default 0 check (base_revenue_per_hour >= 0),
  expense_per_hour bigint not null default 0 check (expense_per_hour >= 0),
  total_revenue bigint not null default 0 check (total_revenue >= 0),
  vault_level integer not null default 1 check (vault_level >= 1),
  vault_balance bigint not null default 0 check (vault_balance >= 0),
  level_upgrade_started_at timestamptz,
  level_upgrade_ends_at timestamptz,
  level_upgrade_target_level integer,
  level_upgrade_cost bigint,
  vault_upgrade_started_at timestamptz,
  vault_upgrade_ends_at timestamptz,
  vault_upgrade_target_level integer,
  auction_id text,
  auction_ends_at timestamptz,
  auction_status text,
  last_collected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table nexora.company_logs (
  id text primary key,
  company_id text not null references nexora.companies(id),
  owner_uid uuid not null references auth.users(id),
  action text not null,
  amount bigint not null default 0,
  details text not null default '',
  created_at timestamptz not null default now()
);

create table nexora.properties (
  id text primary key,
  owner_uid uuid not null references auth.users(id),
  name text not null,
  property_type text not null check (property_type in ('shop','office','facility')),
  level integer not null default 1 check (level >= 1),
  purchase_price bigint not null check (purchase_price >= 0),
  rent_per_hour bigint not null default 0 check (rent_per_hour >= 0),
  maintenance_per_hour bigint not null default 0 check (maintenance_per_hour >= 0),
  is_rented boolean not null default false,
  last_collected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table nexora.organizations (
  id text primary key,
  name text not null,
  tag text not null unique,
  description text not null default '',
  leader_uid uuid not null references auth.users(id),
  leader_name text not null,
  treasury_balance bigint not null default 0 check (treasury_balance >= 0),
  member_count integer not null default 1 check (member_count >= 0),
  reputation bigint not null default 0 check (reputation >= 0),
  level integer not null default 1 check (level >= 1),
  member_capacity integer not null default 20 check (member_capacity >= 1),
  join_mode text not null default 'request',
  research jsonb not null default '{}'::jsonb,
  upgrade_started_at timestamptz,
  upgrade_ends_at timestamptz,
  upgrade_target_level integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table nexora.player_profiles
  add constraint player_profiles_org_id_fkey
  foreign key (org_id) references nexora.organizations(id);

create table nexora.organization_members (
  org_id text not null references nexora.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  role text not null check (role in ('leader','deputy','officer','member')),
  permissions jsonb not null default '[]'::jsonb,
  joined_at timestamptz not null default now(),
  primary key (org_id,user_id)
);

create table nexora.organization_requests (
  id text primary key,
  org_id text not null references nexora.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table nexora.organization_transactions (
  id text primary key,
  org_id text not null references nexora.organizations(id),
  user_id uuid not null references auth.users(id),
  username text not null,
  type text not null check (type in ('deposit','withdraw','upgrade')),
  amount bigint not null check (amount >= 0),
  note text not null default '',
  created_at timestamptz not null default now()
);

create table nexora.player_missions (
  user_id uuid not null references auth.users(id) on delete cascade,
  mission_id text not null,
  category text not null,
  reward_credits bigint not null default 0 check (reward_credits >= 0),
  reward_xp bigint not null default 0 check (reward_xp >= 0),
  claimed_at timestamptz not null default now(),
  primary key (user_id,mission_id)
);

create table nexora.daily_claims (
  user_id uuid not null references auth.users(id) on delete cascade,
  date_key text not null,
  amount bigint not null check (amount >= 0),
  claimed_at timestamptz not null default now(),
  primary key (user_id,date_key)
);

create table nexora.contract_claims (
  user_id uuid not null references auth.users(id) on delete cascade,
  contract_id text not null,
  amount bigint not null check (amount >= 0),
  claimed_at timestamptz not null default now(),
  primary key (user_id,contract_id)
);

create table nexora.player_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id,achievement_id)
);

create table nexora.notifications (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null check (type in ('economy','market','org','mission','system')),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table nexora.world_events (
  id text primary key,
  title_ar text not null,
  title_en text not null,
  description_ar text not null,
  description_en text not null,
  effect_type text not null,
  target_item_id text,
  affected_sectors jsonb,
  price_multiplier numeric(12,4) not null default 1 check (price_multiplier >= 0),
  revenue_multiplier numeric(12,4),
  tax_delta numeric(12,4) not null default 0,
  stack_group text,
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create table nexora.audit_logs (
  id text primary key,
  user_id uuid references auth.users(id),
  action text not null,
  entity_type text not null default '',
  entity_id text not null default '',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table nexora.diagnostics_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','admin')),
  created_at timestamptz not null default now()
);

create table nexora.usernames (
  username_lower text primary key,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  username text not null,
  created_at timestamptz not null default now()
);

create or replace function nexora.reject_immutable_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, nexora
as $$
begin
  raise exception 'NEXORA immutable records cannot be updated or deleted';
end;
$$;

create trigger transactions_immutable before update or delete on nexora.transactions
for each row execute function nexora.reject_immutable_mutation();
create trigger company_logs_immutable before update or delete on nexora.company_logs
for each row execute function nexora.reject_immutable_mutation();
create trigger organization_transactions_immutable before update or delete on nexora.organization_transactions
for each row execute function nexora.reject_immutable_mutation();
create trigger player_missions_immutable before update or delete on nexora.player_missions
for each row execute function nexora.reject_immutable_mutation();
create trigger daily_claims_immutable before update or delete on nexora.daily_claims
for each row execute function nexora.reject_immutable_mutation();
create trigger contract_claims_immutable before update or delete on nexora.contract_claims
for each row execute function nexora.reject_immutable_mutation();
create trigger player_achievements_immutable before update or delete on nexora.player_achievements
for each row execute function nexora.reject_immutable_mutation();
create trigger audit_logs_immutable before update or delete on nexora.audit_logs
for each row execute function nexora.reject_immutable_mutation();

create index player_profiles_org_id_idx on nexora.player_profiles(org_id);
create index transactions_from_uid_created_at_idx on nexora.transactions(from_uid,created_at desc);
create index transactions_to_uid_created_at_idx on nexora.transactions(to_uid,created_at desc);
create index inventory_user_id_idx on nexora.inventory(user_id);
create index market_listings_status_created_at_idx on nexora.market_listings(status,created_at desc);
create index market_listings_seller_uid_idx on nexora.market_listings(seller_uid);
create index market_orders_buyer_uid_created_at_idx on nexora.market_orders(buyer_uid,created_at desc);
create index companies_owner_uid_idx on nexora.companies(owner_uid);
create index company_logs_owner_uid_created_at_idx on nexora.company_logs(owner_uid,created_at desc);
create index properties_owner_uid_idx on nexora.properties(owner_uid);
create index organization_members_user_id_idx on nexora.organization_members(user_id);
create index organization_requests_user_id_idx on nexora.organization_requests(user_id);
create index organization_transactions_org_id_created_at_idx on nexora.organization_transactions(org_id,created_at desc);
create index notifications_user_id_created_at_idx on nexora.notifications(user_id,created_at desc);
create index world_events_active_idx on nexora.world_events(active,starts_at,ends_at);

do $$
declare t text;
begin
  foreach t in array array[
    'player_profiles','player_private','wallets','transactions','inventory',
    'market_listings','market_orders','companies','company_logs','properties',
    'organizations','organization_members','organization_requests','organization_transactions',
    'player_missions','daily_claims','contract_claims','player_achievements',
    'notifications','world_events','audit_logs','diagnostics_admins','usernames'
  ] loop
    execute format('alter table nexora.%I enable row level security', t);
    execute format('revoke all on table nexora.%I from public, anon, authenticated', t);
    execute format('grant all on table nexora.%I to service_role', t);
  end loop;
end $$;

grant execute on function nexora.reject_immutable_mutation() to service_role;
;
