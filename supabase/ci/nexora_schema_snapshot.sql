-- CI-ONLY, DATA-FREE snapshot of the NOVA nexora schema.
-- Generated from PostgreSQL catalogs using read-only queries against production on 2026-11-19.
-- This is NOT a deployable migration and must never be applied to production.

create schema if not exists nexora;

-- Tables
create table nexora.audit_logs (
  id text not null,
  user_id text,
  action text not null,
  entity_type text default ''::text not null,
  entity_id text default ''::text not null,
  details jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.chat_rate_limits (
  id text not null,
  last_sent_at timestamp with time zone
);

create table nexora.companies (
  id text not null,
  owner_uid text not null,
  owner_name text not null,
  name text not null,
  sector text not null,
  level integer default 1 not null,
  capital bigint default 0 not null,
  employees_count integer default 0 not null,
  base_revenue_per_hour bigint default 0 not null,
  expense_per_hour bigint default 0 not null,
  total_revenue bigint default 0 not null,
  vault_level integer default 1 not null,
  vault_balance bigint default 0 not null,
  level_upgrade_started_at timestamp with time zone,
  level_upgrade_ends_at timestamp with time zone,
  level_upgrade_target_level integer,
  level_upgrade_cost bigint,
  vault_upgrade_started_at timestamp with time zone,
  vault_upgrade_ends_at timestamp with time zone,
  vault_upgrade_target_level integer,
  auction_id text,
  auction_ends_at timestamp with time zone,
  auction_status text,
  last_collected_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  is_deleted boolean default false not null,
  deleted_at timestamp with time zone
);

create table nexora.company_auction_bids (
  id text not null,
  auction_id text not null,
  bidder_uid text not null,
  bidder_name text not null,
  amount bigint not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.company_auction_escrows (
  auction_id text not null,
  bidder_uid text not null,
  amount bigint not null,
  status text default 'reserved'::text not null,
  updated_at timestamp with time zone default now() not null
);

create table nexora.company_auctions (
  id text not null,
  company_id text,
  company_name text not null,
  company_sector text not null,
  company_level integer not null,
  seller_uid text not null,
  seller_name text not null,
  starting_price bigint not null,
  current_price bigint not null,
  highest_bidder_uid text,
  highest_bidder_name text,
  starts_at timestamp with time zone default now() not null,
  ends_at timestamp with time zone not null,
  status text default 'active'::text not null,
  winning_bid bigint,
  settled_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  asset_type text default 'company'::text not null,
  factory_id text
);

create table nexora.company_logs (
  id text not null,
  company_id text not null,
  owner_uid text not null,
  action text not null,
  amount bigint default 0 not null,
  details text default ''::text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.contract_claims (
  user_id text not null,
  contract_id text not null,
  amount bigint not null,
  claimed_at timestamp with time zone default now() not null
);

create table nexora.conversation_messages (
  id text not null,
  conversation_id text not null,
  sender_uid text not null,
  sender_name text not null,
  message_text text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.conversations (
  id text not null,
  participants text[] not null,
  participant_names jsonb default '{}'::jsonb not null,
  participant_avatars jsonb default '{}'::jsonb not null,
  last_message text default ''::text not null,
  last_message_at timestamp with time zone default now() not null,
  last_sender_uid text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table nexora.daily_claims (
  user_id text not null,
  date_key text not null,
  amount bigint not null,
  claimed_at timestamp with time zone default now() not null
);

create table nexora.diagnostics_admins (
  user_id text not null,
  role text default 'owner'::text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.factories (
  id text not null,
  owner_uid text not null,
  owner_name text not null,
  name text not null,
  resource_id text not null,
  level integer default 1 not null,
  skill_level integer default 0 not null,
  is_active boolean default true not null,
  warehouse_qty bigint default 0 not null,
  production_remainder numeric(12,6) default 0 not null,
  operating_cost_remainder numeric(12,6) default 0 not null,
  last_produced_at timestamp with time zone default now() not null,
  upgrade_started_at timestamp with time zone,
  upgrade_ends_at timestamp with time zone,
  upgrade_target_level integer,
  upgrade_cost bigint,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  warehouse_level integer default 1 not null,
  warehouse_upgrade_started_at timestamp with time zone,
  warehouse_upgrade_ends_at timestamp with time zone,
  warehouse_upgrade_target_level integer,
  warehouse_upgrade_cost bigint,
  auction_id text,
  auction_ends_at timestamp with time zone,
  auction_status text
);

create table nexora.global_chat_messages (
  id text not null,
  sender_uid text not null,
  sender_name text not null,
  avatar_id text default 'strategist'::text not null,
  message_text text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.inventory (
  user_id text not null,
  item_id text not null,
  quantity bigint default 0 not null,
  last_listing_id text,
  updated_at timestamp with time zone default now() not null
);

create table nexora.market_listings (
  id text not null,
  seller_uid text not null,
  seller_name text not null,
  item_id text not null,
  quantity integer not null,
  remaining_qty integer not null,
  unit_price bigint not null,
  status text default 'active'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table nexora.market_orders (
  id text not null,
  listing_id text not null,
  buyer_uid text not null,
  seller_uid text not null,
  item_id text not null,
  quantity integer not null,
  unit_price bigint not null,
  total_price bigint not null,
  tax_amount bigint default 0 not null,
  tx_id text,
  created_at timestamp with time zone default now() not null
);

create table nexora.notifications (
  id text not null,
  user_id text not null,
  title text not null,
  body text default ''::text not null,
  type text not null,
  is_read boolean default false not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.organization_invites (
  id text not null,
  org_id text not null,
  org_name text not null,
  org_tag text not null,
  target_uid text not null,
  inviter_uid text not null,
  inviter_name text not null,
  status text not null,
  created_at timestamp with time zone default now() not null,
  responded_at timestamp with time zone
);

create table nexora.organization_members (
  org_id text not null,
  user_id text not null,
  username text not null,
  role text not null,
  permissions jsonb default '[]'::jsonb not null,
  joined_at timestamp with time zone default now() not null
);

create table nexora.organization_requests (
  id text not null,
  org_id text not null,
  user_id text not null,
  username text not null,
  status text default 'pending'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table nexora.organization_transactions (
  id text not null,
  org_id text not null,
  user_id text not null,
  username text not null,
  type text not null,
  amount bigint not null,
  note text default ''::text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.organizations (
  id text not null,
  name text not null,
  tag text not null,
  description text default ''::text not null,
  leader_uid text not null,
  leader_name text not null,
  treasury_balance bigint default 0 not null,
  member_count integer default 1 not null,
  reputation bigint default 0 not null,
  level integer default 1 not null,
  member_capacity integer default 20 not null,
  join_mode text default 'request'::text not null,
  research jsonb default '{}'::jsonb not null,
  upgrade_started_at timestamp with time zone,
  upgrade_ends_at timestamp with time zone,
  upgrade_target_level integer,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table nexora.player_achievements (
  user_id text not null,
  achievement_id text not null,
  unlocked_at timestamp with time zone default now() not null
);

create table nexora.player_missions (
  user_id text not null,
  mission_id text not null,
  category text not null,
  reward_credits bigint default 0 not null,
  reward_xp bigint default 0 not null,
  claimed_at timestamp with time zone default now() not null
);

create table nexora.player_presence (
  user_id text not null,
  online_since timestamp with time zone default now() not null,
  last_seen_at timestamp with time zone default now() not null
);

create table nexora.player_private (
  user_id text not null,
  email text default ''::text not null,
  language text default 'ar'::text not null,
  notifications_enabled boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table nexora.player_profiles (
  user_id text not null,
  username text not null,
  username_lower text not null,
  avatar_id text default 'strategist'::text not null,
  title text default 'newcomer'::text not null,
  level integer default 1 not null,
  xp bigint default 0 not null,
  reputation bigint default 0 not null,
  influence bigint default 0 not null,
  skill_points integer default 0 not null,
  skills jsonb default '{}'::jsonb not null,
  stats jsonb default '{}'::jsonb not null,
  org_id text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table nexora.player_reports (
  id text not null,
  reporter_uid text not null,
  target_uid text not null,
  reason text not null,
  status text default 'open'::text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.transactions (
  id text not null,
  from_uid text,
  to_uid text,
  amount bigint not null,
  fee bigint default 0 not null,
  net_amount bigint not null,
  type text not null,
  reference_id text default ''::text not null,
  description text default ''::text not null,
  status text default 'completed'::text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.user_blocks (
  id text not null,
  owner_uid text not null,
  target_uid text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.usernames (
  username_lower text not null,
  uid text not null,
  username text not null,
  created_at timestamp with time zone default now() not null
);

create table nexora.wallets (
  user_id text not null,
  balance bigint default 2500 not null,
  total_earned bigint default 0 not null,
  total_spent bigint default 0 not null,
  last_tx_id text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table nexora.world_events (
  id text not null,
  title_ar text not null,
  title_en text not null,
  description_ar text not null,
  description_en text not null,
  effect_type text not null,
  target_item_id text,
  affected_sectors jsonb,
  price_multiplier numeric(12,4) default 1 not null,
  revenue_multiplier numeric(12,4),
  tax_delta numeric(12,4) default 0 not null,
  stack_group text,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  active boolean default false not null,
  created_at timestamp with time zone default now() not null
);

-- Constraints
alter table nexora.audit_logs add constraint audit_logs_pkey PRIMARY KEY (id);
alter table nexora.chat_rate_limits add constraint chat_rate_limits_pkey PRIMARY KEY (id);
alter table nexora.companies add constraint companies_pkey PRIMARY KEY (id);
alter table nexora.company_auction_bids add constraint company_auction_bids_pkey PRIMARY KEY (id);
alter table nexora.company_auction_escrows add constraint company_auction_escrows_pkey PRIMARY KEY (auction_id, bidder_uid);
alter table nexora.company_auctions add constraint company_auctions_pkey PRIMARY KEY (id);
alter table nexora.company_logs add constraint company_logs_pkey PRIMARY KEY (id);
alter table nexora.contract_claims add constraint contract_claims_pkey PRIMARY KEY (user_id, contract_id);
alter table nexora.conversation_messages add constraint conversation_messages_pkey PRIMARY KEY (id);
alter table nexora.conversations add constraint conversations_pkey PRIMARY KEY (id);
alter table nexora.daily_claims add constraint daily_claims_pkey PRIMARY KEY (user_id, date_key);
alter table nexora.diagnostics_admins add constraint diagnostics_admins_pkey PRIMARY KEY (user_id);
alter table nexora.factories add constraint factories_pkey PRIMARY KEY (id);
alter table nexora.global_chat_messages add constraint global_chat_messages_pkey PRIMARY KEY (id);
alter table nexora.inventory add constraint inventory_pkey PRIMARY KEY (user_id, item_id);
alter table nexora.market_listings add constraint market_listings_pkey PRIMARY KEY (id);
alter table nexora.market_orders add constraint market_orders_pkey PRIMARY KEY (id);
alter table nexora.notifications add constraint notifications_pkey PRIMARY KEY (id);
alter table nexora.organization_invites add constraint organization_invites_pkey PRIMARY KEY (id);
alter table nexora.organization_members add constraint organization_members_pkey PRIMARY KEY (org_id, user_id);
alter table nexora.organization_requests add constraint organization_requests_pkey PRIMARY KEY (id);
alter table nexora.organization_transactions add constraint organization_transactions_pkey PRIMARY KEY (id);
alter table nexora.organizations add constraint organizations_pkey PRIMARY KEY (id);
alter table nexora.organizations add constraint organizations_tag_key UNIQUE (tag);
alter table nexora.player_achievements add constraint player_achievements_pkey PRIMARY KEY (user_id, achievement_id);
alter table nexora.player_missions add constraint player_missions_pkey PRIMARY KEY (user_id, mission_id);
alter table nexora.player_presence add constraint player_presence_pkey PRIMARY KEY (user_id);
alter table nexora.player_private add constraint player_private_pkey PRIMARY KEY (user_id);
alter table nexora.player_profiles add constraint player_profiles_pkey PRIMARY KEY (user_id);
alter table nexora.player_profiles add constraint player_profiles_username_lower_key UNIQUE (username_lower);
alter table nexora.player_reports add constraint player_reports_pkey PRIMARY KEY (id);
alter table nexora.transactions add constraint transactions_pkey PRIMARY KEY (id);
alter table nexora.user_blocks add constraint user_blocks_owner_uid_target_uid_key UNIQUE (owner_uid, target_uid);
alter table nexora.user_blocks add constraint user_blocks_pkey PRIMARY KEY (id);
alter table nexora.usernames add constraint usernames_pkey PRIMARY KEY (username_lower);
alter table nexora.usernames add constraint usernames_user_id_key UNIQUE (uid);
alter table nexora.wallets add constraint wallets_pkey PRIMARY KEY (user_id);
alter table nexora.world_events add constraint world_events_pkey PRIMARY KEY (id);
alter table nexora.companies add constraint companies_base_revenue_per_hour_check CHECK ((base_revenue_per_hour >= 0));
alter table nexora.companies add constraint companies_capital_check CHECK ((capital >= 0));
alter table nexora.companies add constraint companies_employees_count_check CHECK ((employees_count >= 0));
alter table nexora.companies add constraint companies_expense_per_hour_check CHECK ((expense_per_hour >= 0));
alter table nexora.companies add constraint companies_level_check CHECK ((level >= 1));
alter table nexora.companies add constraint companies_sector_check CHECK ((sector = ANY (ARRAY['trade'::text, 'manufacturing'::text, 'services'::text, 'tech'::text, 'logistics'::text])));
alter table nexora.companies add constraint companies_total_revenue_check CHECK ((total_revenue >= 0));
alter table nexora.companies add constraint companies_vault_balance_check CHECK ((vault_balance >= 0));
alter table nexora.companies add constraint companies_vault_level_check CHECK ((vault_level >= 1));
alter table nexora.company_auction_bids add constraint company_auction_bids_amount_check CHECK ((amount > 0));
alter table nexora.company_auction_bids add constraint company_auction_bids_auction_id_fkey FOREIGN KEY (auction_id) REFERENCES nexora.company_auctions(id);
alter table nexora.company_auction_escrows add constraint company_auction_escrows_amount_check CHECK ((amount > 0));
alter table nexora.company_auction_escrows add constraint company_auction_escrows_auction_id_fkey FOREIGN KEY (auction_id) REFERENCES nexora.company_auctions(id);
alter table nexora.company_auction_escrows add constraint company_auction_escrows_status_check CHECK ((status = ANY (ARRAY['reserved'::text, 'refunded'::text, 'released'::text])));
alter table nexora.company_auctions add constraint company_auctions_asset_level_check CHECK ((company_level >= 50));
alter table nexora.company_auctions add constraint company_auctions_asset_type_check CHECK ((asset_type = ANY (ARRAY['company'::text, 'factory'::text])));
alter table nexora.company_auctions add constraint company_auctions_check CHECK ((ends_at > starts_at));
alter table nexora.company_auctions add constraint company_auctions_company_id_fkey FOREIGN KEY (company_id) REFERENCES nexora.companies(id) ON DELETE SET NULL;
alter table nexora.company_auctions add constraint company_auctions_current_price_check CHECK ((current_price > 0));
alter table nexora.company_auctions add constraint company_auctions_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES nexora.factories(id) ON DELETE SET NULL;
alter table nexora.company_auctions add constraint company_auctions_starting_price_check CHECK ((starting_price > 0));
alter table nexora.company_auctions add constraint company_auctions_status_check CHECK ((status = ANY (ARRAY['active'::text, 'sold'::text, 'unsold'::text, 'cancelled'::text])));
alter table nexora.company_logs add constraint company_logs_company_id_fkey FOREIGN KEY (company_id) REFERENCES nexora.companies(id);
alter table nexora.contract_claims add constraint contract_claims_amount_check CHECK ((amount >= 0));
alter table nexora.conversation_messages add constraint conversation_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES nexora.conversations(id) ON DELETE CASCADE;
alter table nexora.conversation_messages add constraint conversation_messages_message_text_check CHECK (((length(message_text) >= 1) AND (length(message_text) <= 1000)));
alter table nexora.conversations add constraint conversations_participants_check CHECK ((cardinality(participants) = 2));
alter table nexora.daily_claims add constraint daily_claims_amount_check CHECK ((amount >= 0));
alter table nexora.diagnostics_admins add constraint diagnostics_admins_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text])));
alter table nexora.factories add constraint factories_level_check CHECK (((level >= 1) AND (level <= 100)));
alter table nexora.factories add constraint factories_name_check CHECK (((char_length(name) >= 2) AND (char_length(name) <= 48)));
alter table nexora.factories add constraint factories_operating_cost_remainder_check CHECK (((operating_cost_remainder >= (0)::numeric) AND (operating_cost_remainder < (1)::numeric)));
alter table nexora.factories add constraint factories_production_remainder_check CHECK (((production_remainder >= (0)::numeric) AND (production_remainder < (1)::numeric)));
alter table nexora.factories add constraint factories_resource_id_check CHECK ((resource_id = ANY (ARRAY['silicon_ore'::text, 'copper_wire'::text, 'energy_cells'::text, 'crude_alloy'::text, 'carbon_fiber'::text, 'rare_minerals'::text])));
alter table nexora.factories add constraint factories_skill_level_check CHECK (((skill_level >= 0) AND (skill_level <= 10)));
alter table nexora.factories add constraint factories_warehouse_level_check CHECK (((warehouse_level >= 1) AND (warehouse_level <= 5)));
alter table nexora.factories add constraint factories_warehouse_qty_check CHECK ((warehouse_qty >= 0));
alter table nexora.global_chat_messages add constraint global_chat_messages_message_text_check CHECK (((length(message_text) >= 1) AND (length(message_text) <= 280)));
alter table nexora.inventory add constraint inventory_quantity_check CHECK ((quantity >= 0));
alter table nexora.market_listings add constraint market_listings_check CHECK (((remaining_qty >= 0) AND (remaining_qty <= quantity)));
alter table nexora.market_listings add constraint market_listings_quantity_check CHECK ((quantity > 0));
alter table nexora.market_listings add constraint market_listings_status_check CHECK ((status = ANY (ARRAY['active'::text, 'sold'::text, 'cancelled'::text])));
alter table nexora.market_listings add constraint market_listings_unit_price_check CHECK ((unit_price > 0));
alter table nexora.market_orders add constraint market_orders_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES nexora.market_listings(id);
alter table nexora.market_orders add constraint market_orders_quantity_check CHECK ((quantity > 0));
alter table nexora.market_orders add constraint market_orders_tax_amount_check CHECK ((tax_amount >= 0));
alter table nexora.market_orders add constraint market_orders_total_price_check CHECK ((total_price > 0));
alter table nexora.market_orders add constraint market_orders_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES nexora.transactions(id);
alter table nexora.market_orders add constraint market_orders_unit_price_check CHECK ((unit_price > 0));
alter table nexora.notifications add constraint notifications_type_check CHECK ((type = ANY (ARRAY['economy'::text, 'market'::text, 'org'::text, 'mission'::text, 'system'::text])));
alter table nexora.organization_invites add constraint organization_invites_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'rejected'::text, 'cancelled'::text])));
alter table nexora.organization_members add constraint organization_members_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id) ON DELETE CASCADE;
alter table nexora.organization_members add constraint organization_members_role_check CHECK ((role = ANY (ARRAY['leader'::text, 'deputy'::text, 'officer'::text, 'member'::text])));
alter table nexora.organization_requests add constraint organization_requests_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id) ON DELETE CASCADE;
alter table nexora.organization_requests add constraint organization_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])));
alter table nexora.organization_transactions add constraint organization_transactions_amount_check CHECK ((amount >= 0));
alter table nexora.organization_transactions add constraint organization_transactions_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id);
alter table nexora.organization_transactions add constraint organization_transactions_type_check CHECK ((type = ANY (ARRAY['deposit'::text, 'withdraw'::text, 'upgrade'::text])));
alter table nexora.organizations add constraint organizations_level_check CHECK ((level >= 1));
alter table nexora.organizations add constraint organizations_member_capacity_check CHECK ((member_capacity >= 1));
alter table nexora.organizations add constraint organizations_member_count_check CHECK ((member_count >= 0));
alter table nexora.organizations add constraint organizations_reputation_check CHECK ((reputation >= 0));
alter table nexora.organizations add constraint organizations_treasury_balance_check CHECK ((treasury_balance >= 0));
alter table nexora.player_missions add constraint player_missions_reward_credits_check CHECK ((reward_credits >= 0));
alter table nexora.player_missions add constraint player_missions_reward_xp_check CHECK ((reward_xp >= 0));
alter table nexora.player_private add constraint player_private_language_check CHECK ((language = ANY (ARRAY['ar'::text, 'en'::text])));
alter table nexora.player_profiles add constraint player_profiles_influence_check CHECK ((influence >= 0));
alter table nexora.player_profiles add constraint player_profiles_level_check CHECK ((level >= 1));
alter table nexora.player_profiles add constraint player_profiles_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id);
alter table nexora.player_profiles add constraint player_profiles_reputation_check CHECK ((reputation >= 0));
alter table nexora.player_profiles add constraint player_profiles_skill_points_check CHECK ((skill_points >= 0));
alter table nexora.player_profiles add constraint player_profiles_username_check CHECK (((char_length(username) >= 3) AND (char_length(username) <= 24)));
alter table nexora.player_profiles add constraint player_profiles_xp_check CHECK ((xp >= 0));
alter table nexora.player_reports add constraint player_reports_check CHECK ((reporter_uid <> target_uid));
alter table nexora.player_reports add constraint player_reports_reason_check CHECK ((reason = ANY (ARRAY['harassment'::text, 'spam'::text, 'inappropriate'::text, 'impersonation'::text, 'other'::text])));
alter table nexora.player_reports add constraint player_reports_status_check CHECK ((status = ANY (ARRAY['open'::text, 'reviewing'::text, 'closed'::text])));
alter table nexora.transactions add constraint transactions_amount_check CHECK ((amount >= 0));
alter table nexora.transactions add constraint transactions_fee_check CHECK ((fee >= 0));
alter table nexora.transactions add constraint transactions_net_amount_check CHECK ((net_amount >= 0));
alter table nexora.transactions add constraint transactions_status_check CHECK ((status = 'completed'::text));
alter table nexora.user_blocks add constraint user_blocks_check CHECK ((owner_uid <> target_uid));
alter table nexora.wallets add constraint wallets_balance_check CHECK ((balance >= 0));
alter table nexora.wallets add constraint wallets_total_earned_check CHECK ((total_earned >= 0));
alter table nexora.wallets add constraint wallets_total_spent_check CHECK ((total_spent >= 0));
alter table nexora.world_events add constraint world_events_price_multiplier_check CHECK ((price_multiplier >= (0)::numeric));

-- Non-constraint indexes
CREATE INDEX companies_owner_active_idx ON nexora.companies USING btree (owner_uid, is_deleted);
CREATE INDEX companies_owner_uid_idx ON nexora.companies USING btree (owner_uid);
CREATE INDEX company_auction_bids_auction_idx ON nexora.company_auction_bids USING btree (auction_id, created_at DESC);
CREATE INDEX company_auction_escrows_bidder_idx ON nexora.company_auction_escrows USING btree (bidder_uid, status);
CREATE INDEX company_auctions_active_ends_idx ON nexora.company_auctions USING btree (status, ends_at);
CREATE UNIQUE INDEX company_auctions_factory_active_unique ON nexora.company_auctions USING btree (factory_id) WHERE ((factory_id IS NOT NULL) AND (status = 'active'::text));
CREATE INDEX company_auctions_seller_idx ON nexora.company_auctions USING btree (seller_uid, created_at DESC);
CREATE INDEX company_logs_company_id_idx ON nexora.company_logs USING btree (company_id);
CREATE INDEX company_logs_owner_uid_created_at_idx ON nexora.company_logs USING btree (owner_uid, created_at DESC);
CREATE INDEX conversation_messages_order_idx ON nexora.conversation_messages USING btree (conversation_id, created_at DESC);
CREATE INDEX conversations_last_message_at_idx ON nexora.conversations USING btree (last_message_at DESC);
CREATE INDEX conversations_participants_gin_idx ON nexora.conversations USING gin (participants);
CREATE UNIQUE INDEX factories_auction_id_unique ON nexora.factories USING btree (auction_id) WHERE (auction_id IS NOT NULL);
CREATE INDEX factories_owner_created_idx ON nexora.factories USING btree (owner_uid, created_at);
CREATE INDEX global_chat_created_idx ON nexora.global_chat_messages USING btree (created_at DESC);
CREATE INDEX inventory_user_id_idx ON nexora.inventory USING btree (user_id);
CREATE INDEX market_listings_seller_uid_idx ON nexora.market_listings USING btree (seller_uid);
CREATE INDEX market_listings_status_created_at_idx ON nexora.market_listings USING btree (status, created_at DESC);
CREATE INDEX market_orders_buyer_uid_created_at_idx ON nexora.market_orders USING btree (buyer_uid, created_at DESC);
CREATE INDEX market_orders_listing_id_idx ON nexora.market_orders USING btree (listing_id);
CREATE INDEX market_orders_tx_id_idx ON nexora.market_orders USING btree (tx_id);
CREATE INDEX notifications_user_id_created_at_idx ON nexora.notifications USING btree (user_id, created_at DESC);
CREATE INDEX org_invites_target_status_idx ON nexora.organization_invites USING btree (target_uid, status);
CREATE INDEX organization_members_user_id_idx ON nexora.organization_members USING btree (user_id);
CREATE UNIQUE INDEX organization_requests_one_pending_per_user_org ON nexora.organization_requests USING btree (org_id, user_id) WHERE (status = 'pending'::text);
CREATE INDEX organization_requests_user_id_idx ON nexora.organization_requests USING btree (user_id);
CREATE INDEX organization_transactions_org_id_created_at_idx ON nexora.organization_transactions USING btree (org_id, created_at DESC);
CREATE INDEX player_presence_last_seen_idx ON nexora.player_presence USING btree (last_seen_at DESC);
CREATE INDEX player_profiles_org_id_idx ON nexora.player_profiles USING btree (org_id);
CREATE INDEX player_reports_status_created_idx ON nexora.player_reports USING btree (status, created_at DESC);
CREATE INDEX transactions_from_uid_created_at_idx ON nexora.transactions USING btree (from_uid, created_at DESC);
CREATE INDEX transactions_to_uid_created_at_idx ON nexora.transactions USING btree (to_uid, created_at DESC);
CREATE INDEX world_events_active_idx ON nexora.world_events USING btree (active, starts_at, ends_at);

-- Functions in original creation order
CREATE OR REPLACE FUNCTION nexora.reject_immutable_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'nexora'
AS $function$
begin
  raise exception 'NEXORA immutable records cannot be updated or deleted';
end;
$function$


CREATE OR REPLACE FUNCTION nexora.create_player_character(p_uid text, p_email text, p_username text, p_avatar_id text, p_language text DEFAULT 'ar'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_username text := btrim(p_username);
  v_lower text;
  v_title text;
  v_notification_id text := 'ntf_' || gen_random_uuid()::text;
BEGIN
  IF p_uid IS NULL OR length(p_uid) < 1 OR length(p_uid) > 128 THEN
    RAISE EXCEPTION 'INVALID_USER';
  END IF;
  IF v_username !~ '^[a-zA-Z0-9_]{3,24}$' THEN
    RAISE EXCEPTION 'INVALID_USERNAME';
  END IF;
  IF p_language NOT IN ('ar','en') THEN
    RAISE EXCEPTION 'INVALID_LANGUAGE';
  END IF;

  v_lower := lower(v_username);
  v_title := CASE WHEN p_language = 'ar' THEN 'مؤسس طموح' ELSE 'Executive Founder' END;

  IF EXISTS (SELECT 1 FROM nexora.player_profiles WHERE user_id = p_uid) THEN
    RAISE EXCEPTION 'PROFILE_EXISTS';
  END IF;

  INSERT INTO nexora.usernames(username_lower,uid,username)
  VALUES (v_lower,p_uid,v_username);

  INSERT INTO nexora.player_profiles(
    user_id,username,username_lower,avatar_id,title,level,xp,reputation,influence,
    skill_points,skills,stats,org_id
  ) VALUES (
    p_uid,v_username,v_lower,p_avatar_id,v_title,1,0,10,5,0,
    '{"trade":0,"management":0,"industry":0,"negotiation":0,"finance":0,"leadership":0}'::jsonb,
    '{"missionsCompleted":0,"tradesCount":0,"companiesOwned":0,"totalProduced":0}'::jsonb,
    null
  );

  INSERT INTO nexora.player_private(user_id,email,language,notifications_enabled)
  VALUES (p_uid,coalesce(p_email,''),p_language,true);

  INSERT INTO nexora.wallets(user_id,balance,total_earned,total_spent,last_tx_id)
  VALUES (p_uid,2500,2500,0,'init_' || p_uid);

  INSERT INTO nexora.notifications(id,user_id,title,body,type,is_read)
  VALUES (
    v_notification_id,
    p_uid,
    CASE WHEN p_language='ar' THEN 'مرحباً بك في NOVA' ELSE 'Welcome to NOVA' END,
    CASE WHEN p_language='ar' THEN 'تم إيداع $2,500 في محفظتك. ابدأ رحلتك الآن.' ELSE '$2,500 credited to your wallet. Your journey begins now.' END,
    'system',
    false
  );

  RETURN jsonb_build_object('ok',true,'user_id',p_uid,'username',v_username,'starting_credits',2500);
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'USERNAME_TAKEN';
END;
$function$


CREATE OR REPLACE FUNCTION nexora.claim_daily_stipend(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_date text := to_char(now() at time zone 'UTC','YYYY-MM-DD');
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_amount bigint;
  v_xp bigint;
  v_level integer := 1;
  v_remaining bigint;
  v_step bigint;
  v_levels_gained integer;
  v_leadership numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_notification text := 'ntf_' || gen_random_uuid()::text;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_amount := least(1500, greatest(450, 450 + (v_profile.level - 1) * 35 + coalesce((v_profile.skills->>'finance')::integer,0) * 25));
  if exists(select 1 from nexora.daily_claims where user_id=p_uid and date_key=v_date) then
    raise exception 'ALREADY_CLAIMED_TODAY';
  end if;

  insert into nexora.daily_claims(user_id,date_key,amount) values(p_uid,v_date,v_amount);
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_amount,0,v_amount,'daily_stipend',p_uid || '_' || v_date,'Daily operational stipend (' || v_date || ')','completed');

  update nexora.wallets set balance=balance+v_amount,total_earned=total_earned+v_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;

  v_xp := v_profile.xp + 40;
  v_remaining := v_xp;
  while v_level < 200 loop
    v_step := 200 + (v_level - 1) * 120;
    exit when v_remaining < v_step;
    v_remaining := v_remaining - v_step;
    v_level := v_level + 1;
  end loop;
  v_levels_gained := greatest(0,v_level-v_profile.level);
  v_leadership := 1 + coalesce((v_profile.skills->>'leadership')::numeric,0) * 0.1;

  update nexora.player_profiles
  set xp=v_xp,
      level=v_level,
      skill_points=skill_points + v_levels_gained * 2,
      reputation=reputation + round(2 * v_leadership)::bigint,
      influence=influence + round(1 * v_leadership)::bigint,
      updated_at=now()
  where user_id=p_uid;

  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  values(v_notification,p_uid,'Daily Stipend Credited','+$' || v_amount::text || ' & +40 XP','economy',false);

  return jsonb_build_object('ok',true,'amount',v_amount,'xp_gain',40,'date_key',v_date);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.upgrade_player_skill(p_uid text, p_skill text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_current integer;
begin
  if p_skill not in ('trade','management','industry','negotiation','finance','leadership') then
    raise exception 'INVALID_SKILL';
  end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_profile.skill_points < 1 then raise exception 'NO_SKILL_POINTS'; end if;
  v_current := coalesce((v_profile.skills->>p_skill)::integer,0);
  if v_current >= 10 then raise exception 'SKILL_MAXED'; end if;
  update nexora.player_profiles
  set skill_points=skill_points-1,
      skills=jsonb_set(coalesce(skills,'{}'::jsonb),array[p_skill],to_jsonb(v_current+1),true),
      updated_at=now()
  where user_id=p_uid;
  return jsonb_build_object('ok',true,'skill',p_skill,'level',v_current+1);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.transfer_credits(p_uid text, p_recipient_username text, p_amount bigint, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_to_uid text;
  v_from nexora.wallets%rowtype;
  v_to nexora.wallets%rowtype;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_notification text := 'ntf_' || gen_random_uuid()::text;
  v_amount bigint := p_amount;
  v_note text := left(coalesce(btrim(p_note),''),180);
  v_recipient_name text;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  select uid,username into v_to_uid,v_recipient_name
  from nexora.usernames where username_lower=lower(btrim(p_recipient_username));
  if v_to_uid is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
  if v_to_uid=p_uid then raise exception 'SELF_OR_MISSING_RECIPIENT'; end if;

  perform 1 from nexora.wallets
  where user_id in (p_uid,v_to_uid)
  order by user_id
  for update;

  select * into v_from from nexora.wallets where user_id=p_uid;
  select * into v_to from nexora.wallets where user_id=v_to_uid;
  if v_from.user_id is null or v_to.user_id is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
  if v_amount > v_from.balance then raise exception 'INSUFFICIENT_FUNDS'; end if;

  update nexora.wallets set balance=balance-v_amount,total_spent=total_spent+v_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.wallets set balance=balance+v_amount,total_earned=total_earned+v_amount,last_tx_id=v_tx,updated_at=now() where user_id=v_to_uid;

  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,v_to_uid,v_amount,0,v_amount,'transfer',v_to_uid,coalesce(nullif(v_note,''),'Transfer to ' || v_recipient_name),'completed');

  insert into nexora.audit_logs(id,user_id,action,entity_type,entity_id,details)
  values('aud_' || gen_random_uuid()::text,p_uid,'wallet_transfer','transaction',v_tx,jsonb_build_object('recipient_uid',v_to_uid,'amount',v_amount));

  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  values(v_notification,p_uid,'Transfer Sent','-$' || v_amount::text || ' -> ' || v_recipient_name,'economy',false);

  return jsonb_build_object('ok',true,'transaction_id',v_tx,'amount',v_amount);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.create_market_listing(p_uid text, p_item_id text, p_qty integer, p_unit_price bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_inventory nexora.inventory%rowtype;
  v_username text;
  v_id text := 'lst_' || gen_random_uuid()::text;
begin
  if p_item_id not in ('silicon_ore','copper_wire','energy_cells','crude_alloy','carbon_fiber','rare_minerals','microchips','precision_frame','synth_polymer','quantum_server','logistics_drone','bio_module') then raise exception 'INVALID_ITEM'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 10000 or p_unit_price is null or p_unit_price < 1 or p_unit_price > 1000000 then raise exception 'INVALID_LISTING_PARAMS'; end if;
  select username into v_username from nexora.player_profiles where user_id=p_uid;
  if v_username is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=p_item_id for update;
  if not found or v_inventory.quantity < p_qty then raise exception 'INSUFFICIENT_INVENTORY'; end if;
  update nexora.inventory set quantity=quantity-p_qty,updated_at=now() where user_id=p_uid and item_id=p_item_id;
  insert into nexora.market_listings(id,seller_uid,seller_name,item_id,quantity,remaining_qty,unit_price,status)
  values(v_id,p_uid,v_username,p_item_id,p_qty,p_qty,p_unit_price,'active');
  return jsonb_build_object('ok',true,'listing_id',v_id);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.buy_market_listing(p_uid text, p_listing_id text, p_qty integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_listing nexora.market_listings%rowtype; v_wallet nexora.wallets%rowtype; v_profile nexora.player_profiles%rowtype;
  v_seller nexora.wallets%rowtype; v_inventory nexora.inventory%rowtype;
  v_total bigint; v_fee bigint; v_net bigint; v_tax numeric; v_event_delta numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text; v_order text; v_stats jsonb;
begin
  if p_qty is null or p_qty < 1 then raise exception 'INVALID_QUANTITY'; end if;
  select * into v_listing from nexora.market_listings where id=p_listing_id for update;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.status <> 'active' or v_listing.remaining_qty < p_qty then raise exception 'INSUFFICIENT_LISTING_QTY'; end if;
  if v_listing.seller_uid=p_uid then raise exception 'CANNOT_BUY_OWN_LISTING'; end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_total := v_listing.unit_price * p_qty;
  if v_wallet.balance < v_total then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_event_delta := coalesce((select sum(tax_delta) from nexora.world_events where active=true and starts_at <= now() and ends_at > now()),0);
  v_tax := greatest(0.01,least(0.12,0.05 - coalesce((v_profile.skills->>'trade')::numeric,0)*0.004 + v_event_delta));
  v_fee := round(v_total * v_tax)::bigint; v_net := v_total - v_fee;
  if v_listing.seller_uid <> 'SYSTEM' then
    select * into v_seller from nexora.wallets where user_id=v_listing.seller_uid for update;
    if not found then raise exception 'SELLER_ACCOUNT_NOT_FOUND'; end if;
  end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=v_listing.item_id for update;
  update nexora.wallets set balance=balance-v_total,total_spent=total_spent+v_total,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  if v_listing.seller_uid <> 'SYSTEM' then
    update nexora.wallets set balance=balance+v_net,total_earned=total_earned+v_net,last_tx_id=v_tx,updated_at=now() where user_id=v_listing.seller_uid;
  end if;
  update nexora.market_listings set remaining_qty=remaining_qty-p_qty,status=case when remaining_qty-p_qty=0 then 'sold' else 'active' end,updated_at=now() where id=p_listing_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,v_listing.seller_uid,v_total,v_fee,v_net,'market_buy',p_listing_id,'Market buy: ' || p_qty::text || 'x ' || v_listing.item_id,'completed');
  v_order := 'ord_' || v_tx;
  insert into nexora.market_orders(id,listing_id,buyer_uid,seller_uid,item_id,quantity,unit_price,total_price,tax_amount,tx_id)
  values(v_order,p_listing_id,p_uid,v_listing.seller_uid,v_listing.item_id,p_qty,v_listing.unit_price,v_total,v_fee,v_tx);
  if v_inventory.user_id is null then
    insert into nexora.inventory(user_id,item_id,quantity) values(p_uid,v_listing.item_id,p_qty);
  else
    update nexora.inventory set quantity=quantity+p_qty,updated_at=now() where user_id=p_uid and item_id=v_listing.item_id;
  end if;
  v_stats := jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{tradesCount}',to_jsonb(coalesce((v_profile.stats->>'tradesCount')::integer,0)+1),true);
  update nexora.player_profiles set stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'order_id',v_order,'transaction_id',v_tx,'total',v_total,'tax',v_fee);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.cancel_market_listing(p_uid text, p_listing_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_listing nexora.market_listings%rowtype;
begin
  select * into v_listing from nexora.market_listings where id=p_listing_id for update;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.seller_uid<>p_uid or v_listing.status<>'active' then raise exception 'CANNOT_CANCEL_LISTING'; end if;
  update nexora.market_listings set remaining_qty=0,status='cancelled',updated_at=now() where id=p_listing_id;
  insert into nexora.inventory(user_id,item_id,quantity,last_listing_id)
  values(p_uid,v_listing.item_id,v_listing.remaining_qty,p_listing_id)
  on conflict(user_id,item_id) do update
    set quantity=nexora.inventory.quantity+excluded.quantity,last_listing_id=excluded.last_listing_id,updated_at=now();
  return jsonb_build_object('ok',true,'returned_qty',v_listing.remaining_qty);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.manufacture_recipe(p_uid text, p_recipe_id text, p_batches integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_inputs jsonb; v_output text; v_output_qty integer; v_cost integer; v_xp integer; v_required integer;
  v_profile nexora.player_profiles%rowtype; v_wallet nexora.wallets%rowtype;
  v_item record; v_qty integer; v_discount numeric; v_unit_cost integer; v_total bigint;
  v_tx text := 'tx_' || gen_random_uuid()::text; v_new_xp bigint;
  v_level integer := 1; v_remaining bigint; v_step bigint; v_levels_gained integer; v_leadership numeric; v_stats jsonb;
begin
  if p_batches is null or p_batches < 1 or p_batches > 999 then raise exception 'INVALID_QUANTITY'; end if;
  case p_recipe_id
    when 'rec_microchips' then v_output:='microchips'; v_output_qty:=2; v_cost:=40; v_xp:=45; v_required:=0; v_inputs:='[{"itemId":"silicon_ore","qty":2},{"itemId":"copper_wire","qty":2}]'::jsonb;
    when 'rec_precision_frame' then v_output:='precision_frame'; v_output_qty:=2; v_cost:=50; v_xp:=55; v_required:=0; v_inputs:='[{"itemId":"crude_alloy","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    when 'rec_synth_polymer' then v_output:='synth_polymer'; v_output_qty:=2; v_cost:=60; v_xp:=65; v_required:=1; v_inputs:='[{"itemId":"energy_cells","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb;
    when 'rec_quantum_server' then v_output:='quantum_server'; v_output_qty:=1; v_cost:=90; v_xp:=110; v_required:=1; v_inputs:='[{"itemId":"microchips","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    when 'rec_logistics_drone' then v_output:='logistics_drone'; v_output_qty:=1; v_cost:=110; v_xp:=125; v_required:=2; v_inputs:='[{"itemId":"precision_frame","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    when 'rec_bio_module' then v_output:='bio_module'; v_output_qty:=1; v_cost:=125; v_xp:=140; v_required:=2; v_inputs:='[{"itemId":"synth_polymer","qty":2},{"itemId":"rare_minerals","qty":2}]'::jsonb;
    when 'rec_titanium_frame' then v_output:='precision_frame'; v_output_qty:=2; v_cost:=80; v_xp:=75; v_required:=1; v_inputs:='[{"itemId":"titanium_ore","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    when 'rec_polymer_composite' then v_output:='synth_polymer'; v_output_qty:=2; v_cost:=90; v_xp:=85; v_required:=1; v_inputs:='[{"itemId":"polymer_resin","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    when 'rec_biotech_module' then v_output:='bio_module'; v_output_qty:=1; v_cost:=320; v_xp:=155; v_required:=2; v_inputs:='[{"itemId":"biotech_gel","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb;
    when 'rec_quantum_server_advanced' then v_output:='quantum_server'; v_output_qty:=1; v_cost:=60; v_xp:=180; v_required:=3; v_inputs:='[{"itemId":"quantum_dust","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    else raise exception 'INVALID_RECIPE';
  end case;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if coalesce((v_profile.skills->>'industry')::integer,0) < v_required then raise exception 'INDUSTRY_SKILL_TOO_LOW'; end if;
  v_discount := least(0.45,greatest(0,coalesce((v_profile.skills->>'industry')::integer,0))*0.06);
  v_unit_cost := greatest(10,round(v_cost*(1-v_discount))::integer);
  v_total := v_unit_cost*p_batches;
  if v_wallet.balance < v_total then raise exception 'INSUFFICIENT_FUNDS'; end if;
  for v_item in select value->>'itemId' as item_id,(value->>'qty')::integer as qty from jsonb_array_elements(v_inputs) order by value->>'itemId' loop
    select quantity into v_qty from nexora.inventory where user_id=p_uid and item_id=v_item.item_id for update;
    if not found or v_qty < v_item.qty*p_batches then raise exception 'MISSING_INPUTS'; end if;
  end loop;
  update nexora.wallets set balance=balance-v_total,total_spent=total_spent+v_total,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  for v_item in select value->>'itemId' as item_id,(value->>'qty')::integer as qty from jsonb_array_elements(v_inputs) loop
    update nexora.inventory set quantity=quantity-v_item.qty*p_batches,updated_at=now() where user_id=p_uid and item_id=v_item.item_id;
  end loop;
  insert into nexora.inventory(user_id,item_id,quantity) values(p_uid,v_output,v_output_qty*p_batches)
  on conflict(user_id,item_id) do update set quantity=nexora.inventory.quantity+excluded.quantity,updated_at=now();
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_total,0,v_total,'manufacturing',p_recipe_id,'Manufactured ' || (v_output_qty*p_batches)::text || 'x ' || v_output || ' (' || p_batches::text || ' batches)','completed');
  v_new_xp := v_profile.xp+v_xp*p_batches; v_remaining:=v_new_xp;
  while v_level<200 loop v_step:=200+(v_level-1)*120; exit when v_remaining<v_step; v_remaining:=v_remaining-v_step; v_level:=v_level+1; end loop;
  v_levels_gained:=greatest(0,v_level-v_profile.level);
  v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{totalProduced}',to_jsonb(coalesce((v_profile.stats->>'totalProduced')::integer,0)+v_output_qty*p_batches),true);
  update nexora.player_profiles set xp=v_new_xp,level=v_level,skill_points=skill_points+v_levels_gained*2,
    reputation=reputation+round(3*v_leadership)::bigint,influence=influence+round(2*v_leadership)::bigint,
    stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'output_item',v_output,'output_qty',v_output_qty*p_batches,'cost',v_total);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.fulfill_trade_contract(p_uid text, p_contract_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_item text; v_qty integer; v_base bigint; v_xp integer; v_rep integer; v_title text;
  v_date text := to_char(now() at time zone 'UTC','YYYY-MM-DD');
  v_claim text; v_profile nexora.player_profiles%rowtype; v_wallet nexora.wallets%rowtype;
  v_inventory nexora.inventory%rowtype; v_tier_bonus numeric := 0; v_payout bigint;
  v_tx text := 'tx_' || gen_random_uuid()::text; v_level integer := 1; v_remaining bigint; v_step bigint;
  v_new_xp bigint; v_levels_gained integer; v_leadership numeric; v_stats jsonb;
begin
  case p_contract_id
    when 'ctr_chip_batch' then v_item:='microchips'; v_qty:=2; v_base:=420; v_xp:=75; v_rep:=12; v_title:='Cloud Lab Microchip Supply';
    when 'ctr_drone_fleet' then v_item:='logistics_drone'; v_qty:=1; v_base:=890; v_xp:=145; v_rep:=24; v_title:='Express Cargo Drone Fleet';
    when 'ctr_quantum_node' then v_item:='quantum_server'; v_qty:=1; v_base:=840; v_xp:=135; v_rep:=22; v_title:='Quantum Node Deployment';
    else raise exception 'INVALID_CONTRACT';
  end case;
  v_claim:=p_contract_id || '_' || v_date;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if exists(select 1 from nexora.contract_claims where user_id=p_uid and contract_id=v_claim) then raise exception 'CONTRACT_ALREADY_FULFILLED'; end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=v_item for update;
  if not found or v_inventory.quantity<v_qty then raise exception 'MISSING_INPUTS'; end if;
  v_tier_bonus:=case
    when v_profile.reputation>=700 then 0.15
    when v_profile.reputation>=350 then 0.12
    when v_profile.reputation>=160 then 0.08
    when v_profile.reputation>=60 then 0.04
    else 0 end;
  v_payout:=least(2500,round(v_base*(1+coalesce((v_profile.skills->>'negotiation')::numeric,0)*0.07)*(1+v_tier_bonus))::bigint);
  update nexora.inventory set quantity=quantity-v_qty,updated_at=now() where user_id=p_uid and item_id=v_item;
  update nexora.wallets set balance=balance+v_payout,total_earned=total_earned+v_payout,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.contract_claims(user_id,contract_id,amount) values(p_uid,v_claim,v_payout);
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_payout,0,v_payout,'contract_deal',v_claim,'Contract fulfilled: ' || v_title,'completed');
  v_new_xp:=v_profile.xp+v_xp; v_remaining:=v_new_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120; exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step; v_level:=v_level+1;
  end loop;
  v_levels_gained:=greatest(0,v_level-v_profile.level); v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{tradesCount}',to_jsonb(coalesce((v_profile.stats->>'tradesCount')::integer,0)+1),true);
  update nexora.player_profiles set xp=v_new_xp,level=v_level,skill_points=skill_points+v_levels_gained*2,
    reputation=reputation+round(v_rep*v_leadership)::bigint,influence=influence+round(5*v_leadership)::bigint,
    stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'payout',v_payout,'contract_id',v_claim);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.update_player_settings(p_uid text, p_language text, p_notifications_enabled boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if p_language not in ('ar','en') then raise exception 'INVALID_LANGUAGE'; end if;
  update nexora.player_private set language=p_language,notifications_enabled=p_notifications_enabled,updated_at=now() where user_id=p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.update_player_avatar(p_uid text, p_avatar_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if p_avatar_id is null or length(p_avatar_id)<1 or length(p_avatar_id)>64 then raise exception 'INVALID_AVATAR'; end if;
  update nexora.player_profiles set avatar_id=p_avatar_id,updated_at=now() where user_id=p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.mark_notification_read(p_uid text, p_notification_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update nexora.notifications set is_read=true where id=p_notification_id and user_id=p_uid;
  if not found then raise exception 'NOTIFICATION_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.mark_all_notifications_read(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_count integer;
begin
  update nexora.notifications set is_read=true where user_id=p_uid and is_read=false;
  get diagnostics v_count = row_count;
  return jsonb_build_object('ok',true,'updated',v_count);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.found_company(p_uid text, p_name text, p_sector text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_username text; v_cost bigint; v_revenue bigint; v_expense bigint;
  v_wallet nexora.wallets%rowtype; v_profile nexora.player_profiles%rowtype;
  v_id text := 'cmp_' || gen_random_uuid()::text; v_tx text := 'tx_' || gen_random_uuid()::text;
  v_log text := 'clog_' || gen_random_uuid()::text; v_xp bigint; v_level integer := 1;
  v_remaining bigint; v_step bigint; v_gained integer; v_leadership numeric; v_stats jsonb;
begin
  if p_name is null or length(btrim(p_name))<2 or length(btrim(p_name))>48 then raise exception 'INVALID_NAME'; end if;
  case p_sector
    when 'trade' then v_cost:=900; v_revenue:=140; v_expense:=35;
    when 'services' then v_cost:=1100; v_revenue:=175; v_expense:=45;
    when 'logistics' then v_cost:=1400; v_revenue:=225; v_expense:=60;
    when 'manufacturing' then v_cost:=1800; v_revenue:=290; v_expense:=80;
    when 'tech' then v_cost:=2200; v_revenue:=365; v_expense:=95;
    else raise exception 'INVALID_SECTOR';
  end case;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_username:=v_profile.username;
  insert into nexora.companies(id,owner_uid,owner_name,name,sector,level,capital,base_revenue_per_hour,expense_per_hour,total_revenue,vault_level,vault_balance,last_collected_at)
  values(v_id,p_uid,v_username,btrim(p_name),p_sector,1,v_cost,v_revenue,v_expense,0,1,0,now());
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_create',v_id,'Founded company: ' || btrim(p_name),'completed');
  v_xp:=v_profile.xp+100; v_remaining:=v_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120; exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step; v_level:=v_level+1;
  end loop;
  v_gained:=greatest(0,v_level-v_profile.level); v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{companiesOwned}',to_jsonb(coalesce((v_profile.stats->>'companiesOwned')::integer,0)+1),true);
  update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,
    reputation=reputation+round(10*v_leadership)::bigint,influence=influence+round(8*v_leadership)::bigint,
    stats=v_stats,updated_at=now() where user_id=p_uid;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,v_id,p_uid,'founded',-v_cost,'Company established in ' || p_sector || ' sector');
  return jsonb_build_object('ok',true,'company_id',v_id);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.company_net_hourly(p_company_id text)
 RETURNS bigint
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company nexora.companies%rowtype; v_profile nexora.player_profiles%rowtype;
  v_management numeric; v_finance numeric; v_tier numeric:=0; v_event_mult numeric:=1;
  v_seen text[]:='{}'; v_event record; v_income_bonus numeric:=0;
  v_gross numeric; v_expense numeric;
begin
  select * into v_company from nexora.companies where id=p_company_id;
  if not found then return 0; end if;
  select * into v_profile from nexora.player_profiles where user_id=v_company.owner_uid;
  if not found then return 0; end if;
  v_management:=greatest(0,coalesce((v_profile.skills->>'management')::numeric,0));
  v_finance:=greatest(0,coalesce((v_profile.skills->>'finance')::numeric,0));
  v_tier:=case when v_profile.reputation>=700 then 0.08 when v_profile.reputation>=350 then 0.06
    when v_profile.reputation>=160 then 0.04 when v_profile.reputation>=60 then 0.02 else 0 end;
  if v_profile.org_id is not null then
    select greatest(0,least(10,coalesce((research->>'commerce')::numeric,0))) into v_income_bonus
    from nexora.organizations where id=v_profile.org_id;
  end if;
  for v_event in
    select group_key,revenue_multiplier,affected_sectors from (
      select distinct on (coalesce(nullif(stack_group,''),effect_type,id))
        coalesce(nullif(stack_group,''),effect_type,id) as group_key,revenue_multiplier,affected_sectors,starts_at
      from nexora.world_events
      where active=true and starts_at<=now() and ends_at>now()
      order by coalesce(nullif(stack_group,''),effect_type,id),starts_at desc
    ) e order by group_key limit 3
  loop
    if not (v_event.group_key=any(v_seen)) then
      v_seen:=array_append(v_seen,v_event.group_key);
      if coalesce(v_event.affected_sectors,'[]'::jsonb) @> jsonb_build_array(v_company.sector) then
        v_event_mult:=v_event_mult*coalesce(v_event.revenue_multiplier,1);
      end if;
    end if;
  end loop;
  v_event_mult:=greatest(0.75,least(1.4,round(v_event_mult::numeric,3)));
  v_gross:=round(v_company.base_revenue_per_hour*(1+(v_company.level-1)*0.32)*(1+v_management*0.08)
    *v_event_mult*(1+v_tier)*(1+v_income_bonus*0.005));
  v_expense:=round(v_company.expense_per_hour*(1+(v_company.level-1)*0.2)*(1-least(0.45,v_finance*0.05)));
  return greatest(15,(v_gross-v_expense))::bigint;
end;
$function$


CREATE OR REPLACE FUNCTION nexora.start_company_upgrade(p_uid text, p_company_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company nexora.companies%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cost bigint;
  v_target integer;
  v_duration numeric;
  v_ends timestamptz;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_log text:='clog_'||gen_random_uuid()::text;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.level>=100 then raise exception 'MAX_LEVEL'; end if;
  if v_company.level_upgrade_started_at is not null
     or v_company.level_upgrade_ends_at is not null
     or v_company.level_upgrade_target_level is not null then
    raise exception 'UPGRADE_IN_PROGRESS';
  end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_cost:=v_company.level*550;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_target:=v_company.level+1;
  if v_target<=50 then v_duration:=round(2000*power(43200::numeric,(v_target-2)::numeric/48));
  else v_duration:=round(86400000*power(15::numeric,(v_target-50)::numeric/50)); end if;
  v_ends:=now()+make_interval(secs=>greatest(1,v_duration/1000));
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.companies set level_upgrade_started_at=now(),level_upgrade_ends_at=v_ends,
    level_upgrade_target_level=v_target,level_upgrade_cost=v_cost,updated_at=now() where id=p_company_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_upgrade',p_company_id,
    'Started upgrade of '||v_company.name||' to Lv.'||v_target::text,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'upgrade_started',-v_cost,'Started upgrade to Level '||v_target::text);
  return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_ends);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.complete_company_upgrade(p_uid text, p_company_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company nexora.companies%rowtype;v_profile nexora.player_profiles%rowtype;v_target integer;
  v_xp bigint;v_level integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_cost bigint;v_log text:='clog_'||gen_random_uuid()::text;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND';end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED';end if;
  v_target:=coalesce(v_company.level_upgrade_target_level,0);
  if v_company.level_upgrade_ends_at is null or v_target=0 then raise exception 'NO_UPGRADE_IN_PROGRESS';end if;
  if now()<v_company.level_upgrade_ends_at then raise exception 'UPGRADE_NOT_FINISHED';end if;
  if v_target<>v_company.level+1 or v_target>100 then raise exception 'INVALID_UPGRADE_STATE';end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
  v_xp:=v_profile.xp+75;v_remaining:=v_xp;
  while v_level<200 loop v_step:=200+(v_level-1)*120;exit when v_remaining<v_step;v_remaining:=v_remaining-v_step;v_level:=v_level+1;end loop;
  v_gained:=greatest(0,v_level-v_profile.level);v_cost:=coalesce(v_company.level_upgrade_cost,0);
  update nexora.companies set level=v_target,capital=capital+v_cost,level_upgrade_started_at=null,
    level_upgrade_ends_at=null,level_upgrade_target_level=null,level_upgrade_cost=null,updated_at=now() where id=p_company_id;
  update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,updated_at=now() where user_id=p_uid;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'upgrade_completed',0,'Company reached Level '||v_target::text);
  return jsonb_build_object('ok',true,'level',v_target);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.complete_company_vault_upgrade(p_uid text, p_company_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_company nexora.companies%rowtype;v_target integer;v_log text:='clog_'||gen_random_uuid()::text;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND';end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED';end if;
  v_target:=coalesce(v_company.vault_upgrade_target_level,0);
  if v_company.vault_upgrade_ends_at is null or v_target=0 then raise exception 'NO_UPGRADE_IN_PROGRESS';end if;
  if now()<v_company.vault_upgrade_ends_at then raise exception 'UPGRADE_NOT_FINISHED';end if;
  if v_target<>v_company.vault_level+1 or v_target>5 then raise exception 'INVALID_UPGRADE_STATE';end if;
  update nexora.companies set vault_level=v_target,vault_upgrade_started_at=null,vault_upgrade_ends_at=null,
    vault_upgrade_target_level=null,updated_at=now() where id=p_company_id;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'vault_upgrade_completed',0,'Profit vault reached Level '||v_target::text);
  return jsonb_build_object('ok',true,'vault_level',v_target);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.upgrade_company_vault(p_uid text, p_company_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company nexora.companies%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_old integer;
  v_target integer;
  v_cost bigint;
  v_item1 text;
  v_qty1 integer;
  v_item2 text;
  v_qty2 integer;
  v_capacity bigint[]:=array[3500,7000,14000,25000,40000];
  v_cap bigint;
  v_net bigint;
  v_preserved bigint;
  v_now timestamptz:=now();
  v_elapsed numeric;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_log text:='clog_'||gen_random_uuid()::text;
  v_inv1 integer;
  v_inv2 integer;
  v_duration numeric;
  v_ends timestamptz;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.vault_upgrade_started_at is not null
     or v_company.vault_upgrade_ends_at is not null
     or v_company.vault_upgrade_target_level is not null then
    raise exception 'UPGRADE_IN_PROGRESS';
  end if;
  v_old:=greatest(1,least(5,v_company.vault_level));
  if v_old>=5 then raise exception 'VAULT_MAX_LEVEL'; end if;
  case v_old
    when 1 then v_cost:=1500;v_item1:='copper_wire';v_qty1:=20;v_item2:='crude_alloy';v_qty2:=10;
    when 2 then v_cost:=4000;v_item1:='silicon_ore';v_qty1:=20;v_item2:='energy_cells';v_qty2:=15;
    when 3 then v_cost:=10000;v_item1:='carbon_fiber';v_qty1:=15;v_item2:='precision_frame';v_qty2:=10;
    when 4 then v_cost:=25000;v_item1:='rare_minerals';v_qty1:=20;v_item2:='quantum_server';v_qty2:=5;
  end case;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  select * into v_profile from nexora.player_profiles where user_id=p_uid;
  if not found or v_wallet.user_id is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  select quantity into v_inv1 from nexora.inventory where user_id=p_uid and item_id=v_item1 for update;
  if not found or coalesce(v_inv1,0)<v_qty1 then raise exception 'MISSING_VAULT_MATERIALS'; end if;
  select quantity into v_inv2 from nexora.inventory where user_id=p_uid and item_id=v_item2 for update;
  if not found or coalesce(v_inv2,0)<v_qty2 then raise exception 'MISSING_VAULT_MATERIALS'; end if;
  v_net:=nexora.company_net_hourly(p_company_id);
  v_cap:=v_capacity[v_old];
  v_elapsed:=greatest(0,extract(epoch from (v_now-coalesce(v_company.last_collected_at,v_now)))/3600);
  v_preserved:=least(v_cap,greatest(0,coalesce(v_company.vault_balance,0)+floor(v_net*least(12,v_elapsed))::bigint));
  v_target:=v_old+1;
  if v_target<=50 then v_duration:=round(2000*power(43200::numeric,(v_target-2)::numeric/48));
  else v_duration:=round(86400000*power(15::numeric,(v_target-50)::numeric/50)); end if;
  v_ends:=v_now+make_interval(secs=>greatest(1,v_duration/2000));
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.inventory set quantity=quantity-v_qty1,updated_at=now() where user_id=p_uid and item_id=v_item1;
  update nexora.inventory set quantity=quantity-v_qty2,updated_at=now() where user_id=p_uid and item_id=v_item2;
  update nexora.companies set vault_balance=v_preserved,last_collected_at=v_now,vault_upgrade_started_at=v_now,
    vault_upgrade_ends_at=v_ends,vault_upgrade_target_level=v_target,updated_at=now() where id=p_company_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_vault_upgrade',p_company_id,
    'Upgraded '||v_company.name||' profit vault to Lv.'||v_target::text,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'vault_upgrade',-v_cost,
    'Profit vault upgraded to Lv.'||v_target::text||'; preserved '||v_preserved::text);
  return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_ends,
    'vault_balance',v_preserved,'capacity',v_cap);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.collect_company_revenue(p_uid text, p_company_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company nexora.companies%rowtype;v_wallet nexora.wallets%rowtype;v_profile nexora.player_profiles%rowtype;
  v_capacity bigint[]:=array[3500,7000,14000,25000,40000];v_level integer;v_net bigint;v_elapsed numeric;
  v_payout bigint;v_now timestamptz:=now();v_tx text:='tx_'||gen_random_uuid()::text;v_log text:='clog_'||gen_random_uuid()::text;
  v_xp bigint;v_level_after integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_leadership numeric;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND';end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED';end if;
  if v_company.last_collected_at is not null and v_now-v_company.last_collected_at<interval '30 seconds' then raise exception 'NOTHING_TO_COLLECT';end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found or v_wallet.user_id is null then raise exception 'ACCOUNT_NOT_FOUND';end if;
  v_net:=nexora.company_net_hourly(p_company_id);v_level:=greatest(1,least(5,v_company.vault_level));
  v_elapsed:=greatest(0,extract(epoch from (v_now-coalesce(v_company.last_collected_at,v_now)))/3600);
  v_payout:=least(v_capacity[v_level],greatest(0,coalesce(v_company.vault_balance,0)+floor(v_net*least(12,v_elapsed))::bigint));
  if v_payout<1 then raise exception 'NOTHING_TO_COLLECT';end if;
  update nexora.wallets set balance=balance+v_payout,total_earned=total_earned+v_payout,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.companies set total_revenue=total_revenue+v_payout,vault_balance=0,last_collected_at=v_now,updated_at=now() where id=p_company_id;
  v_xp:=v_profile.xp+least(80,greatest(10,floor(v_payout/15)::integer));v_remaining:=v_xp;
  while v_level_after<200 loop v_step:=200+(v_level_after-1)*120;exit when v_remaining<v_step;v_remaining:=v_remaining-v_step;v_level_after:=v_level_after+1;end loop;
  v_gained:=greatest(0,v_level_after-v_profile.level);v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  update nexora.player_profiles set xp=v_xp,level=v_level_after,skill_points=skill_points+v_gained*2,
    reputation=reputation+round(2*v_leadership)::bigint,influence=influence+round(1*v_leadership)::bigint,updated_at=now()
  where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_payout,0,v_payout,'company_collect',p_company_id,'Company revenue collected: '||v_company.name,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'collect',v_payout,'Collected +$'||v_payout::text);
  return jsonb_build_object('ok',true,'payout',v_payout);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.claim_mission_reward(p_uid text, p_mission_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_category text;
  v_metric text;
  v_target integer;
  v_credits bigint;
  v_xp_gain integer;
  v_rep integer;
  v_title text;
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_progress integer;
  v_claim text := p_uid || '_' || p_mission_id;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_xp bigint;
  v_level integer := 1;
  v_remaining bigint;
  v_step bigint;
  v_gained integer;
  v_leadership numeric;
  v_stats jsonb;
BEGIN
  CASE p_mission_id
    WHEN 'tut_first_trade' THEN v_category:='tutorial';v_metric:='trades';v_target:=1;v_credits:=450;v_xp_gain:=90;v_rep:=10;v_title:='Enter the Open Market';
    WHEN 'tut_first_production' THEN v_category:='tutorial';v_metric:='produced';v_target:=1;v_credits:=550;v_xp_gain:=110;v_rep:=15;v_title:='Start Production Line';
    WHEN 'tut_first_company' THEN v_category:='tutorial';v_metric:='companies';v_target:=1;v_credits:=850;v_xp_gain:=160;v_rep:=25;v_title:='Found Your First Company';
    WHEN 'daily_active_trader' THEN v_category:='daily';v_metric:='trades';v_target:=3;v_credits:=600;v_xp_gain:=120;v_rep:=14;v_title:='Active Market Trader';
    WHEN 'seasonal_syndicate' THEN v_category:='seasonal';v_metric:='org';v_target:=1;v_credits:=1200;v_xp_gain:=260;v_rep:=35;v_title:='Economic Syndicate Alliance';
    ELSE RAISE EXCEPTION 'INVALID_MISSION';
  END CASE;

  SELECT * INTO v_profile FROM nexora.player_profiles WHERE user_id=p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;
  SELECT * INTO v_wallet FROM nexora.wallets WHERE user_id=p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;
  IF EXISTS(SELECT 1 FROM nexora.player_missions WHERE user_id=p_uid AND mission_id=p_mission_id) THEN
    RAISE EXCEPTION 'MISSION_ALREADY_CLAIMED';
  END IF;

  v_progress := CASE v_metric
    WHEN 'trades' THEN coalesce((v_profile.stats->>'tradesCount')::integer,0)
    WHEN 'produced' THEN coalesce((v_profile.stats->>'totalProduced')::integer,0)
    WHEN 'companies' THEN coalesce((v_profile.stats->>'companiesOwned')::integer,0)
    WHEN 'org' THEN CASE WHEN v_profile.org_id IS NULL THEN 0 ELSE 1 END
    ELSE v_profile.level
  END;
  IF v_progress < v_target THEN RAISE EXCEPTION 'MISSION_NOT_COMPLETE'; END IF;

  INSERT INTO nexora.player_missions(user_id,mission_id,category,reward_credits,reward_xp)
  VALUES(p_uid,p_mission_id,v_category,v_credits,v_xp_gain);
  UPDATE nexora.wallets
  SET balance=balance+v_credits,total_earned=total_earned+v_credits,last_tx_id=v_tx,updated_at=now()
  WHERE user_id=p_uid;
  INSERT INTO nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  VALUES(v_tx,'SYSTEM',p_uid,v_credits,0,v_credits,'mission_reward',v_claim,'Mission reward: '||v_title,'completed');

  v_xp:=v_profile.xp+v_xp_gain;
  v_remaining:=v_xp;
  WHILE v_level<200 LOOP
    v_step:=200+(v_level-1)*120;
    EXIT WHEN v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level:=v_level+1;
  END LOOP;
  v_gained:=greatest(0,v_level-v_profile.level);
  v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{missionsCompleted}',
    to_jsonb(coalesce((v_profile.stats->>'missionsCompleted')::integer,0)+1),true);
  UPDATE nexora.player_profiles
  SET xp=v_xp,level=v_level,skill_points=skill_points+v_gained,
      reputation=reputation+round(v_rep*v_leadership)::bigint,
      influence=influence+round(5*v_leadership)::bigint,stats=v_stats,updated_at=now()
  WHERE user_id=p_uid;

  RETURN jsonb_build_object('ok',true,'reward_credits',v_credits,'reward_xp',v_xp_gain);
END;
$function$


CREATE OR REPLACE FUNCTION nexora.unlock_eligible_achievements(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_profile nexora.player_profiles%rowtype;
  v_unlocked text[] := '{}';
BEGIN
  SELECT * INTO v_profile FROM nexora.player_profiles WHERE user_id=p_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;

  INSERT INTO nexora.player_achievements(user_id,achievement_id)
  SELECT p_uid,a.id
  FROM (VALUES
    ('ach_merchant','trades',5),
    ('ach_industrial_pioneer','produced',5),
    ('ach_tycoon','companies',2),
    ('ach_level_5','level',5),
    ('ach_reputation_100','reputation',100)
  ) AS a(id,metric,threshold)
  WHERE CASE a.metric
    WHEN 'trades' THEN coalesce((v_profile.stats->>'tradesCount')::integer,0)
    WHEN 'produced' THEN coalesce((v_profile.stats->>'totalProduced')::integer,0)
    WHEN 'companies' THEN coalesce((v_profile.stats->>'companiesOwned')::integer,0)
    WHEN 'level' THEN v_profile.level
    ELSE v_profile.reputation
  END >= a.threshold
  ON CONFLICT(user_id,achievement_id) DO NOTHING;

  SELECT coalesce(array_agg(achievement_id),'{}'::text[])
  INTO v_unlocked
  FROM nexora.player_achievements
  WHERE user_id=p_uid;

  RETURN jsonb_build_object('unlocked_ids',v_unlocked);
END;
$function$


CREATE OR REPLACE FUNCTION nexora.create_organization(p_uid text, p_name text, p_tag text, p_description text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_profile nexora.player_profiles%rowtype;v_wallet nexora.wallets%rowtype;v_id text:='org_'||gen_random_uuid()::text;
 v_tx text:='tx_'||gen_random_uuid()::text;v_xp bigint;v_level integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_leadership numeric;
begin
 if p_name is null or length(btrim(p_name))<3 or length(btrim(p_name))>40 then raise exception 'INVALID_NAME';end if;
 if p_tag is null or length(btrim(p_tag))<2 or length(btrim(p_tag))>6 or btrim(p_tag)!~'^[A-Z0-9]+$' then raise exception 'INVALID_TAG';end if;
 select * into v_profile from nexora.player_profiles where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if v_profile.org_id is not null then raise exception 'ALREADY_IN_ORG';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if v_wallet.balance<1000 then raise exception 'INSUFFICIENT_FUNDS';end if;
 insert into nexora.organizations(id,name,tag,description,leader_uid,leader_name,treasury_balance,member_count,reputation,level,member_capacity,join_mode,research)
 values(v_id,btrim(p_name),btrim(p_tag),left(coalesce(btrim(p_description),''),240),p_uid,v_profile.username,0,1,15,1,20,'request','{}'::jsonb);
 insert into nexora.organization_members(org_id,user_id,username,role,permissions)
 values(v_id,p_uid,v_profile.username,'leader','["manage_members","manage_roles","manage_treasury","manage_org"]'::jsonb);
 update nexora.wallets set balance=balance-1000,total_spent=total_spent+1000,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
 values(v_tx,p_uid,'SYSTEM',1000,0,1000,'org_create',v_id,'Founded organization ['||btrim(p_tag)||'] '||btrim(p_name),'completed');
 v_xp:=v_profile.xp+150;v_remaining:=v_xp;
 while v_level<200 loop v_step:=200+(v_level-1)*120;exit when v_remaining<v_step;v_remaining:=v_remaining-v_step;v_level:=v_level+1;end loop;
 v_gained:=greatest(0,v_level-v_profile.level);v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*.1;
 update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,
  reputation=reputation+round(20*v_leadership)::bigint,influence=influence+round(25*v_leadership)::bigint,org_id=v_id,updated_at=now()
 where user_id=p_uid;
 return jsonb_build_object('ok',true,'org_id',v_id);
exception when unique_violation then raise exception 'TAG_TAKEN';
end;$function$


CREATE OR REPLACE FUNCTION nexora.start_organization_upgrade(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_cost bigint;v_level integer;v_finance numeric;v_engineering numeric;v_duration numeric;v_target integer;v_end timestamptz;v_tx text:='org_upgrade_'||gen_random_uuid()::text;
begin
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role not in ('leader','deputy') then raise exception 'UNAUTHORIZED';end if;
 if v_org.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS';end if;
 v_level:=greatest(1,v_org.level);if v_level>=10 then raise exception 'MAX_LEVEL';end if;
 v_finance:=least(10,greatest(0,coalesce((v_org.research->>'finance')::numeric,0)));
 v_engineering:=least(10,greatest(0,coalesce((v_org.research->>'engineering')::numeric,0)));
 v_cost:=round(12000*v_level*v_level*(1-v_finance*.005));
 if v_org.treasury_balance<v_cost then raise exception 'INSUFFICIENT_TREASURY';end if;
 v_target:=v_level+1;v_duration:=round(8*60*60*1000*power(1.5::numeric,greatest(0,v_target-2))*(1-v_engineering*.005));
 v_end:=now()+make_interval(secs=>v_duration/1000);
 update nexora.organizations set treasury_balance=treasury_balance-v_cost,upgrade_started_at=now(),upgrade_ends_at=v_end,upgrade_target_level=v_target,updated_at=now() where id=p_org_id;
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note)
 values(v_tx,p_org_id,p_uid,v_member.username,'upgrade',v_cost,'Started organization upgrade to Lv.'||v_target::text);
 return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_end,'cost',v_cost,'duration_ms',v_duration);
end;$function$


CREATE OR REPLACE FUNCTION nexora.complete_organization_upgrade(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_target integer;v_capacity integer;
begin
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role not in ('leader','deputy') then raise exception 'UNAUTHORIZED';end if;
 v_target:=coalesce(v_org.upgrade_target_level,0);
 if v_target=0 or v_org.upgrade_ends_at is null then raise exception 'UPGRADE_NOT_READY';end if;
 if now()<v_org.upgrade_ends_at then raise exception 'UPGRADE_NOT_READY';end if;
 if v_target<>v_org.level+1 then raise exception 'INVALID_UPGRADE_STATE';end if;
 v_capacity:=least(80,20+(v_target-1)*5+coalesce((v_org.research->>'expansion')::integer,0));
 update nexora.organizations set level=v_target,member_capacity=v_capacity,upgrade_ends_at=null,upgrade_started_at=null,upgrade_target_level=null,updated_at=now() where id=p_org_id;
 return jsonb_build_object('ok',true,'level',v_target,'member_capacity',v_capacity);
end;$function$


CREATE OR REPLACE FUNCTION nexora.research_organization(p_uid text, p_org_id text, p_research_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_base bigint;v_current integer;v_cost bigint;v_research jsonb;v_capacity integer;v_tx text:='org_research_'||gen_random_uuid()::text;
begin
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role not in ('leader','deputy') then raise exception 'UNAUTHORIZED';end if;
 v_base:=case p_research_id when 'commerce' then 25000 when 'engineering' then 30000 when 'expansion' then 20000 when 'finance' then 35000 when 'diplomacy' then 18000 else null end;
 if v_base is null then raise exception 'INVALID_RESEARCH';end if;
 v_current:=coalesce((v_org.research->>p_research_id)::integer,0);if v_current>=10 then raise exception 'RESEARCH_MAX_LEVEL';end if;
 v_cost:=v_base*(v_current+1)*(v_current+1);if v_org.treasury_balance<v_cost then raise exception 'INSUFFICIENT_TREASURY';end if;
 v_research:=jsonb_set(coalesce(v_org.research,'{}'::jsonb),array[p_research_id],to_jsonb(v_current+1),true);
 v_capacity:=case when p_research_id='expansion' then least(80,20+(greatest(1,v_org.level)-1)*5+v_current+1)
  else coalesce(nullif(v_org.member_capacity,0),least(70,20+(greatest(1,v_org.level)-1)*5)) end;
 update nexora.organizations set treasury_balance=treasury_balance-v_cost,research=v_research,member_capacity=v_capacity,updated_at=now() where id=p_org_id;
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note)
 values(v_tx,p_org_id,p_uid,v_member.username,'upgrade',v_cost,'Research '||p_research_id||' advanced to Lv.'||(v_current+1)::text);
 return jsonb_build_object('ok',true,'research_id',p_research_id,'level',v_current+1,'cost',v_cost,'member_capacity',v_capacity);
end;$function$


CREATE OR REPLACE FUNCTION nexora.request_join_organization(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_profile nexora.player_profiles%rowtype;v_org nexora.organizations%rowtype;v_id text:='req_'||gen_random_uuid()::text;
begin
 select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
 if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if v_profile.org_id is not null then raise exception 'ALREADY_IN_ORG';end if;
 select * into v_org from nexora.organizations where id=p_org_id;
 if not found then raise exception 'NOT_FOUND';end if;
 if exists(select 1 from nexora.organization_requests where org_id=p_org_id and user_id=p_uid and status='pending') then raise exception 'REQUEST_ALREADY_PENDING';end if;
 insert into nexora.organization_requests(id,org_id,user_id,username,status) values(v_id,p_org_id,p_uid,v_profile.username,'pending');
 return jsonb_build_object('ok',true,'request_id',v_id);
end;$function$


CREATE OR REPLACE FUNCTION nexora.handle_org_join_request(p_actor_uid text, p_org_id text, p_request_id text, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_req nexora.organization_requests%rowtype;v_org nexora.organizations%rowtype;v_actor nexora.organization_members%rowtype;v_profile nexora.player_profiles%rowtype;v_capacity integer;
begin
 if p_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION';end if;
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_actor from nexora.organization_members where org_id=p_org_id and user_id=p_actor_uid;
 if not found or not (v_actor.permissions ? 'manage_members') then raise exception 'UNAUTHORIZED';end if;
 select * into v_req from nexora.organization_requests where id=p_request_id and org_id=p_org_id for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if v_req.status<>'pending' then raise exception 'REQUEST_ALREADY_HANDLED';end if;
 if p_decision='approved' then
  select * into v_profile from nexora.player_profiles where user_id=v_req.user_id for update;
  if not found then raise exception 'NOT_FOUND';end if;
  if v_profile.org_id is not null then raise exception 'APPLICANT_IN_OTHER_ORG';end if;
  if exists(select 1 from nexora.organization_members where org_id=p_org_id and user_id=v_req.user_id) then raise exception 'ALREADY_ORG_MEMBER';end if;
  v_capacity:=coalesce(nullif(v_org.member_capacity,0),least(70,20+(greatest(1,v_org.level)-1)*5));
  if v_org.member_count>=v_capacity then raise exception 'ORG_FULL';end if;
  insert into nexora.organization_members(org_id,user_id,username,role,permissions) values(p_org_id,v_req.user_id,v_req.username,'member','[]'::jsonb);
  update nexora.player_profiles set org_id=p_org_id,updated_at=now() where user_id=v_req.user_id;
  update nexora.organizations set member_count=member_count+1,updated_at=now() where id=p_org_id;
 end if;
 update nexora.organization_requests set status=p_decision,updated_at=now() where id=p_request_id;
 return jsonb_build_object('ok',true);
end;$function$


CREATE OR REPLACE FUNCTION nexora.update_org_member_role(p_actor_uid text, p_org_id text, p_target_uid text, p_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_actor nexora.organization_members%rowtype;v_target nexora.organization_members%rowtype;v_aw integer;v_tw integer;v_perms jsonb;
begin
 if p_role not in ('deputy','officer','member') then raise exception 'INVALID_ROLE';end if;
 select * into v_actor from nexora.organization_members where org_id=p_org_id and user_id=p_actor_uid;
 select * into v_target from nexora.organization_members where org_id=p_org_id and user_id=p_target_uid for update;
 if not found or v_actor.user_id is null then raise exception 'NOT_FOUND';end if;
 if not (v_actor.permissions ? 'manage_roles') then raise exception 'UNAUTHORIZED';end if;
 v_aw:=case v_actor.role when 'leader' then 4 when 'deputy' then 3 when 'officer' then 2 else 1 end;
 v_tw:=case v_target.role when 'leader' then 4 when 'deputy' then 3 when 'officer' then 2 else 1 end;
 if v_aw<=v_tw then raise exception 'RANK_TOO_HIGH';end if;
 v_perms:=case p_role when 'deputy' then '["manage_members","manage_roles","manage_treasury"]'::jsonb when 'officer' then '["manage_members"]'::jsonb else '[]'::jsonb end;
 update nexora.organization_members set role=p_role,permissions=v_perms where org_id=p_org_id and user_id=p_target_uid;
 return jsonb_build_object('ok',true);
end;$function$


CREATE OR REPLACE FUNCTION nexora.leave_organization(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_member nexora.organization_members%rowtype;
begin
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role='leader' then raise exception 'LEADER_CANNOT_LEAVE';end if;
 delete from nexora.organization_members where org_id=p_org_id and user_id=p_uid;
 update nexora.organizations set member_count=greatest(1,member_count-1),updated_at=now() where id=p_org_id;
 update nexora.player_profiles set org_id=null,updated_at=now() where user_id=p_uid and org_id=p_org_id;
 return jsonb_build_object('ok',true);
end;$function$


CREATE OR REPLACE FUNCTION nexora.kick_org_member(p_actor_uid text, p_org_id text, p_target_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_actor nexora.organization_members%rowtype;v_target nexora.organization_members%rowtype;v_aw integer;v_tw integer;
begin
 if p_actor_uid=p_target_uid then raise exception 'CANNOT_KICK_SELF';end if;
 select * into v_actor from nexora.organization_members where org_id=p_org_id and user_id=p_actor_uid;
 select * into v_target from nexora.organization_members where org_id=p_org_id and user_id=p_target_uid for update;
 if not found or v_actor.user_id is null then raise exception 'NOT_FOUND';end if;
 if not (v_actor.permissions ? 'manage_members') then raise exception 'UNAUTHORIZED';end if;
 v_aw:=case v_actor.role when 'leader' then 4 when 'deputy' then 3 when 'officer' then 2 else 1 end;
 v_tw:=case v_target.role when 'leader' then 4 when 'deputy' then 3 when 'officer' then 2 else 1 end;
 if v_aw<=v_tw then raise exception 'RANK_TOO_HIGH';end if;
 delete from nexora.organization_members where org_id=p_org_id and user_id=p_target_uid;
 update nexora.organizations set member_count=greatest(1,member_count-1),updated_at=now() where id=p_org_id;
 update nexora.player_profiles set org_id=null,updated_at=now() where user_id=p_target_uid and org_id=p_org_id;
 return jsonb_build_object('ok',true);
end;$function$


CREATE OR REPLACE FUNCTION nexora.deposit_org_treasury(p_uid text, p_org_id text, p_amount bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_wallet nexora.wallets%rowtype;v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_tx text:='tx_'||gen_random_uuid()::text;v_otx text:='otx_'||gen_random_uuid()::text;v_username text;
begin
 if p_amount<=0 or p_amount>10000000 then raise exception 'INVALID_AMOUNT';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'UNAUTHORIZED';end if;
 if v_wallet.balance<p_amount then raise exception 'INSUFFICIENT_FUNDS';end if;
 update nexora.wallets set balance=balance-p_amount,total_spent=total_spent+p_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 update nexora.organizations set treasury_balance=treasury_balance+p_amount,reputation=reputation+greatest(1,floor((p_amount/100.0)*(1+least(10,coalesce((research->>'diplomacy')::integer,0))*.01))::bigint),updated_at=now() where id=p_org_id;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status) values(v_tx,p_uid,'ORG',p_amount,0,p_amount,'org_deposit',p_org_id,'Org treasury deposit ['||v_org.tag||']','completed');
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note) values(v_otx,p_org_id,p_uid,v_member.username,'deposit',p_amount,'Deposit by '||v_member.username);
 return jsonb_build_object('ok',true);
end;$function$


CREATE OR REPLACE FUNCTION nexora.withdraw_org_treasury(p_uid text, p_org_id text, p_amount bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_wallet nexora.wallets%rowtype;v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_tx text:='tx_'||gen_random_uuid()::text;v_otx text:='otx_'||gen_random_uuid()::text;
begin
 if p_amount<=0 or p_amount>10000000 then raise exception 'INVALID_AMOUNT';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;
 if not found or not (v_member.permissions ? 'manage_treasury') then raise exception 'UNAUTHORIZED';end if;
 if v_org.treasury_balance<p_amount then raise exception 'INSUFFICIENT_TREASURY';end if;
 update nexora.wallets set balance=balance+p_amount,total_earned=total_earned+p_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 update nexora.organizations set treasury_balance=treasury_balance-p_amount,updated_at=now() where id=p_org_id;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status) values(v_tx,'ORG',p_uid,p_amount,0,p_amount,'org_withdraw',p_org_id,'Org treasury withdrawal ['||v_org.tag||']','completed');
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note) values(v_otx,p_org_id,p_uid,v_member.username,'withdraw',p_amount,'Withdrawal by '||v_member.username);
 return jsonb_build_object('ok',true);
end;$function$


CREATE OR REPLACE FUNCTION nexora.get_org_pending_requests(p_org_id text, p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_member nexora.organization_members%rowtype;v_result jsonb;
begin
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;
 if not found or not (v_member.permissions ? 'manage_members') then raise exception 'UNAUTHORIZED';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'orgId',org_id,'uid',user_id,'username',username,'status',status,'createdAt',created_at) order by created_at),'[]'::jsonb)
 into v_result from nexora.organization_requests where org_id=p_org_id and status='pending';
 return v_result;
end;$function$


CREATE OR REPLACE FUNCTION nexora.fetch_leaderboards()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object(
  'players',coalesce((select jsonb_agg(jsonb_build_object(
   'uid',user_id,'username',username,'avatarId',avatar_id,'title',title,'level',level,'xp',xp,
   'reputation',reputation,'influence',influence,'skillPoints',skill_points,'skills',skills,'stats',stats,'orgId',org_id
  ) order by influence desc) from (select * from nexora.player_profiles order by influence desc limit 20) p),'[]'::jsonb),
  'companies',coalesce((select jsonb_agg(jsonb_build_object(
   'id',id,'ownerUid',owner_uid,'ownerName',owner_name,'name',name,'sector',sector,'level',level,'capital',capital,
   'employeesCount',employees_count,'baseRevenuePerHour',base_revenue_per_hour,'expensePerHour',expense_per_hour,
   'totalRevenue',total_revenue,'vaultLevel',vault_level,'vaultBalance',vault_balance,
   'levelUpgradeStartedAt',level_upgrade_started_at,'levelUpgradeEndsAt',level_upgrade_ends_at,
   'levelUpgradeTargetLevel',level_upgrade_target_level,'levelUpgradeCost',level_upgrade_cost,
   'vaultUpgradeStartedAt',vault_upgrade_started_at,'vaultUpgradeEndsAt',vault_upgrade_ends_at,
   'vaultUpgradeTargetLevel',vault_upgrade_target_level,'auctionId',auction_id,'auctionEndsAt',auction_ends_at,
   'auctionStatus',auction_status,'lastCollectedAt',last_collected_at,'createdAt',created_at,'updatedAt',updated_at
  ) order by total_revenue desc) from (select * from nexora.companies order by total_revenue desc limit 20) c),'[]'::jsonb),
  'organizations',coalesce((select jsonb_agg(jsonb_build_object(
   'id',id,'name',name,'tag',tag,'description',description,'leaderUid',leader_uid,'leaderName',leader_name,
   'treasuryBalance',treasury_balance,'memberCount',member_count,'reputation',reputation,'level',level,
   'memberCapacity',member_capacity,'joinMode',join_mode,'research',research,'upgradeStartedAt',upgrade_started_at,
   'upgradeEndsAt',upgrade_ends_at,'upgradeTargetLevel',upgrade_target_level,'createdAt',created_at,'updatedAt',updated_at
  ) order by reputation desc) from (select * from nexora.organizations order by reputation desc limit 20) o),'[]'::jsonb)
 );
$function$


CREATE OR REPLACE FUNCTION nexora.sync_self_org_membership(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_member nexora.organization_members%rowtype;
begin
 if p_org_id is null then
  select * into v_member from nexora.organization_members where user_id=p_uid for update;
  if found then
   if v_member.role='leader' then raise exception 'LEADER_CANNOT_LEAVE';end if;
   delete from nexora.organization_members where org_id=v_member.org_id and user_id=p_uid;
   update nexora.organizations set member_count=greatest(1,member_count-1),updated_at=now() where id=v_member.org_id;
  end if;
  update nexora.player_profiles set org_id=null,updated_at=now() where user_id=p_uid;
 else
  select * into v_member from nexora.organization_members where user_id=p_uid and org_id=p_org_id;
  if not found then raise exception 'NOT_ORG_MEMBER';end if;
  update nexora.player_profiles set org_id=p_org_id,updated_at=now() where user_id=p_uid;
 end if;
 return jsonb_build_object('ok',true);
end;$function$


CREATE OR REPLACE FUNCTION nexora.enforce_skill_point_progression()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.skill_points := 0;
  ELSIF NEW.level > OLD.level THEN
    NEW.skill_points := GREATEST(OLD.skill_points, 0) + (NEW.level - OLD.level);
  END IF;
  RETURN NEW;
END;
$function$


CREATE OR REPLACE FUNCTION nexora.get_public_player_profile(p_target_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare p player_profiles%rowtype;
begin
 if p_target_uid is null or length(p_target_uid)>128 then raise exception 'INVALID_TARGET'; end if;
 select * into p from player_profiles where user_id=p_target_uid;
 if not found then raise exception 'PLAYER_NOT_FOUND'; end if;
 return jsonb_build_object('uid',p.user_id,'username',p.username,'avatarId',p.avatar_id,'title',p.title,
  'level',p.level,'reputation',p.reputation,'influence',p.influence,'orgId',p.org_id);
end $function$


CREATE OR REPLACE FUNCTION nexora.search_players(p_user_id text, p_prefix text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare v_prefix text; v_players jsonb;
begin
 v_prefix:=lower(trim(coalesce(p_prefix,'')));
 if p_user_id is null then raise exception 'UNAUTHENTICATED'; end if;
 if length(v_prefix)<2 or length(v_prefix)>24 or v_prefix !~ '^[a-z0-9_]+$' then return jsonb_build_object('players','[]'::jsonb); end if;
 select coalesce(jsonb_agg(jsonb_build_object('uid',q.user_id,'username',q.username,'avatarId',q.avatar_id,
  'title',q.title,'level',q.level,'reputation',q.reputation,'influence',q.influence,'orgId',q.org_id)
  order by q.username_lower),'[]'::jsonb) into v_players
 from (select user_id,username,username_lower,avatar_id,title,level,reputation,influence,org_id
  from player_profiles where username_lower like v_prefix||'%' and user_id<>p_user_id
  order by username_lower limit 15) q;
 return jsonb_build_object('players',v_players);
end $function$


CREATE OR REPLACE FUNCTION nexora.list_blocked_players(p_user_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
 select jsonb_build_object('blockedUids',coalesce(jsonb_agg(target_uid),'[]'::jsonb))
 from user_blocks where owner_uid=p_user_id
$function$


CREATE OR REPLACE FUNCTION nexora.block_player(p_user_id text, p_target_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
begin
 if p_target_uid is null or p_target_uid=p_user_id or length(p_target_uid)>128 then raise exception 'INVALID_TARGET'; end if;
 if not exists(select 1 from player_profiles where user_id=p_user_id) or not exists(select 1 from player_profiles where user_id=p_target_uid) then raise exception 'PLAYER_NOT_FOUND'; end if;
 insert into user_blocks(id,owner_uid,target_uid) values(p_user_id||'__'||p_target_uid,p_user_id,p_target_uid) on conflict(owner_uid,target_uid) do nothing;
 return jsonb_build_object('ok',true);
end $function$


CREATE OR REPLACE FUNCTION nexora.unblock_player(p_user_id text, p_target_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
begin delete from user_blocks where owner_uid=p_user_id and target_uid=p_target_uid; return jsonb_build_object('ok',true); end $function$


CREATE OR REPLACE FUNCTION nexora.submit_player_report(p_user_id text, p_target_uid text, p_reason text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare rid text; rate_id text;
begin
 if p_request_id is null or p_target_uid is null or p_target_uid=p_user_id or p_reason not in ('harassment','spam','inappropriate','impersonation','other') then raise exception 'INVALID_REPORT'; end if;
 rid:='report_'||p_user_id||'_'||p_request_id::text;
 if exists(select 1 from player_reports where id=rid and reporter_uid=p_user_id) then return jsonb_build_object('ok',true,'replayed',true); end if;
 if not exists(select 1 from player_profiles where user_id=p_target_uid) then raise exception 'PLAYER_NOT_FOUND'; end if;
 insert into chat_rate_limits(id,last_sent_at) values('report_'||p_user_id,now())
 on conflict(id) do update set last_sent_at=excluded.last_sent_at where chat_rate_limits.last_sent_at<=now()-interval '30 seconds' returning id into rate_id;
 if rate_id is null then raise exception 'REPORT_RATE_LIMIT'; end if;
 insert into player_reports(id,reporter_uid,target_uid,reason) values(rid,p_user_id,p_target_uid,p_reason);
 return jsonb_build_object('ok',true);
end $function$


CREATE OR REPLACE FUNCTION nexora.open_direct_conversation(p_user_id text, p_target_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare a player_profiles%rowtype; b player_profiles%rowtype; pair text[]; cid text;
begin
 if p_target_uid is null or p_target_uid=p_user_id then raise exception 'INVALID_TARGET'; end if;
 select * into a from player_profiles where user_id=p_user_id; select * into b from player_profiles where user_id=p_target_uid;
 if a.user_id is null or b.user_id is null then raise exception 'PLAYER_NOT_FOUND'; end if;
 if exists(select 1 from user_blocks where (owner_uid=p_user_id and target_uid=p_target_uid) or (owner_uid=p_target_uid and target_uid=p_user_id)) then raise exception 'PLAYER_BLOCKED'; end if;
 select array_agg(x order by x) into pair from unnest(array[p_user_id,p_target_uid]) x;
 cid:='dm_'||array_to_string(pair,'_');
 insert into conversations(id,participants,participant_names,participant_avatars,last_sender_uid)
 values(cid,pair,jsonb_build_object(p_user_id,a.username,p_target_uid,b.username),jsonb_build_object(p_user_id,a.avatar_id,p_target_uid,b.avatar_id),'')
 on conflict(id) do nothing;
 if not exists(select 1 from conversations where id=cid and participants=pair) then raise exception 'CONVERSATION_ACCESS_DENIED'; end if;
 return jsonb_build_object('conversationId',cid);
end $function$


CREATE OR REPLACE FUNCTION nexora.send_direct_message(p_user_id text, p_target_uid text, p_text text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare a player_profiles%rowtype; b player_profiles%rowtype; pair text[]; cid text; mid text; msg text; rate_id text;
begin
 if p_request_id is null or p_target_uid is null or p_target_uid=p_user_id then raise exception 'INVALID_REQUEST'; end if;
 msg:=left(trim(regexp_replace(regexp_replace(coalesce(p_text,''),'[<>]','','g'),'[[:space:]]+',' ','g')),1000);
 if msg='' then raise exception 'INVALID_MESSAGE'; end if;
 select * into a from player_profiles where user_id=p_user_id; select * into b from player_profiles where user_id=p_target_uid;
 if a.user_id is null or b.user_id is null then raise exception 'PLAYER_NOT_FOUND'; end if;
 if exists(select 1 from user_blocks where (owner_uid=p_user_id and target_uid=p_target_uid) or (owner_uid=p_target_uid and target_uid=p_user_id)) then raise exception 'PLAYER_BLOCKED'; end if;
 select array_agg(x order by x) into pair from unnest(array[p_user_id,p_target_uid]) x;
 cid:='dm_'||array_to_string(pair,'_'); mid:='msg_'||p_user_id||'_'||p_request_id::text;
 if exists(select 1 from conversation_messages where id=mid and sender_uid=p_user_id and conversation_id=cid) then return jsonb_build_object('ok',true,'replayed',true); end if;
 insert into conversations(id,participants,participant_names,participant_avatars,last_sender_uid)
 values(cid,pair,jsonb_build_object(p_user_id,a.username,p_target_uid,b.username),jsonb_build_object(p_user_id,a.avatar_id,p_target_uid,b.avatar_id),'')
 on conflict(id) do nothing;
 if not exists(select 1 from conversations where id=cid and participants=pair) then raise exception 'CONVERSATION_ACCESS_DENIED'; end if;
 insert into chat_rate_limits(id,last_sent_at) values('dm_'||p_user_id,now())
 on conflict(id) do update set last_sent_at=excluded.last_sent_at where chat_rate_limits.last_sent_at<=now()-interval '1 second' returning id into rate_id;
 if rate_id is null then raise exception 'CHAT_RATE_LIMIT'; end if;
 insert into conversation_messages(id,conversation_id,sender_uid,sender_name,message_text) values(mid,cid,p_user_id,a.username,msg);
 update conversations set last_message=left(msg,120),last_message_at=now(),last_sender_uid=p_user_id,updated_at=now() where id=cid;
 return jsonb_build_object('ok',true);
end $function$


CREATE OR REPLACE FUNCTION nexora.send_global_chat_message(p_user_id text, p_text text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare p player_profiles%rowtype; msg text; mid text; rate_id text;
begin
 msg:=left(trim(regexp_replace(regexp_replace(coalesce(p_text,''),'[<>]','','g'),'[[:space:]]+',' ','g')),280);
 if msg='' or p_request_id is null then raise exception 'EMPTY_MESSAGE'; end if;
 select * into p from player_profiles where user_id=p_user_id; if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
 mid:='gmsg_'||p_user_id||'_'||p_request_id::text;
 if exists(select 1 from global_chat_messages where id=mid and sender_uid=p_user_id) then return jsonb_build_object('ok',true,'replayed',true); end if;
 insert into chat_rate_limits(id,last_sent_at) values('global_'||p_user_id,now())
 on conflict(id) do update set last_sent_at=excluded.last_sent_at where chat_rate_limits.last_sent_at<=now()-interval '3 seconds' returning id into rate_id;
 if rate_id is null then raise exception 'CHAT_RATE_LIMIT'; end if;
 insert into global_chat_messages(id,sender_uid,sender_name,avatar_id,message_text) values(mid,p_user_id,p.username,p.avatar_id,msg);
 return jsonb_build_object('ok',true);
end $function$


CREATE OR REPLACE FUNCTION nexora.list_direct_conversations(p_user_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
 select jsonb_build_object('conversations',coalesce(jsonb_agg(jsonb_build_object(
  'id',c.id,'participants',c.participants,'participantNames',c.participant_names,
  'participantAvatars',c.participant_avatars,'lastMessage',c.last_message,
  'lastMessageAt',c.last_message_at,'lastSenderUid',c.last_sender_uid
 ) order by c.last_message_at desc),'[]'::jsonb))
 from (select * from conversations where p_user_id=any(participants) order by last_message_at desc limit 50) c
$function$


CREATE OR REPLACE FUNCTION nexora.list_direct_messages(p_user_id text, p_conversation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare msgs jsonb;
begin
 if not exists(select 1 from conversations where id=p_conversation_id and p_user_id=any(participants)) then raise exception 'CONVERSATION_ACCESS_DENIED'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'senderUid',m.sender_uid,'senderName',m.sender_name,'text',m.message_text,'createdAt',m.created_at) order by m.created_at),'[]'::jsonb)
 into msgs from (select * from conversation_messages where conversation_id=p_conversation_id order by created_at desc limit 80) m;
 return jsonb_build_object('messages',msgs);
end $function$


CREATE OR REPLACE FUNCTION nexora.list_global_chat_messages(p_user_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
 select jsonb_build_object('messages',coalesce(jsonb_agg(jsonb_build_object('id',m.id,'senderUid',m.sender_uid,'senderName',m.sender_name,'avatarId',m.avatar_id,'text',m.message_text,'createdAt',m.created_at) order by m.created_at),'[]'::jsonb))
 from (select * from global_chat_messages order by created_at desc limit 60) m
$function$


CREATE OR REPLACE FUNCTION nexora.list_organization_invites(p_user_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
 select jsonb_build_object('invites',coalesce(jsonb_agg(jsonb_build_object('id',i.id,'orgId',i.org_id,'orgName',i.org_name,'orgTag',i.org_tag,'inviterName',i.inviter_name,'status',i.status,'targetUid',i.target_uid) order by i.created_at desc),'[]'::jsonb))
 from organization_invites i where i.target_uid=p_user_id and i.status='pending'
$function$


CREATE OR REPLACE FUNCTION nexora.invite_player_to_organization(p_user_id text, p_target_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare a player_profiles%rowtype; b player_profiles%rowtype; o organizations%rowtype; m organization_members%rowtype; iid text;
begin
 select * into a from player_profiles where user_id=p_user_id for update;
 if a.user_id is null or a.org_id is null then raise exception 'NOT_IN_ORG'; end if;
 select * into o from organizations where id=a.org_id for update;
 select * into m from organization_members where org_id=o.id and user_id=p_user_id;
 if m.user_id is null or (m.role not in ('leader','deputy') and not (m.permissions @> '["manage_members"]'::jsonb)) then raise exception 'INVITE_PERMISSION_REQUIRED'; end if;
 select * into b from player_profiles where user_id=p_target_uid for update;
 if b.user_id is null then raise exception 'PLAYER_NOT_FOUND'; end if;
 if b.org_id is not null then raise exception 'TARGET_ALREADY_IN_ORG'; end if;
 iid:=o.id||'_'||p_target_uid;
 insert into organization_invites(id,org_id,org_name,org_tag,target_uid,inviter_uid,inviter_name,status)
 values(iid,o.id,o.name,o.tag,p_target_uid,p_user_id,a.username,'pending')
 on conflict(id) do update set status='pending',inviter_uid=excluded.inviter_uid,inviter_name=excluded.inviter_name,created_at=now(),responded_at=null
 where organization_invites.status<>'pending';
 if not found then raise exception 'INVITE_ALREADY_PENDING'; end if;
 return jsonb_build_object('ok',true);
end $function$


CREATE OR REPLACE FUNCTION nexora.respond_organization_invite(p_user_id text, p_invite_id text, p_response text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare i organization_invites%rowtype; o organizations%rowtype; p player_profiles%rowtype; cap integer;
begin
 select * into i from organization_invites where id=p_invite_id for update;
 if i.id is null or i.target_uid<>p_user_id or i.status<>'pending' then raise exception 'INVITE_NOT_AVAILABLE'; end if;
 if p_response='decline' then update organization_invites set status='rejected',responded_at=now() where id=i.id; return jsonb_build_object('ok',true,'status','rejected'); end if;
 if p_response<>'accept' then raise exception 'INVALID_RESPONSE'; end if;
 select * into o from organizations where id=i.org_id for update;
 select * into p from player_profiles where user_id=p_user_id for update;
 if o.id is null or p.user_id is null or p.org_id is not null then raise exception 'ALREADY_IN_ORG'; end if;
 cap:=coalesce(o.member_capacity,least(70,20+(greatest(1,o.level)-1)*5));
 if o.member_count>=cap then raise exception 'ORG_FULL'; end if;
 insert into organization_members(org_id,user_id,username,role,permissions,joined_at) values(o.id,p_user_id,p.username,'member','[]'::jsonb,now());
 update player_profiles set org_id=o.id,updated_at=now() where user_id=p_user_id;
 update organizations set member_count=member_count+1,updated_at=now() where id=o.id;
 update organization_invites set status='accepted',responded_at=now() where id=i.id;
 return jsonb_build_object('ok',true,'status','accepted');
end $function$


CREATE OR REPLACE FUNCTION nexora.touch_player_presence(p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare v_presence player_presence%rowtype;
begin
  if p_user_id is null or length(p_user_id) < 1 or length(p_user_id) > 128 then
    raise exception 'INVALID_USER';
  end if;
  insert into player_presence(user_id,online_since,last_seen_at)
  values(p_user_id,now(),now())
  on conflict(user_id) do update
    set online_since = case
      when player_presence.last_seen_at < now() - interval '2 minutes' then now()
      else player_presence.online_since
    end,
    last_seen_at = now()
  returning * into v_presence;
  return jsonb_build_object('uid',v_presence.user_id,'onlineSince',v_presence.online_since,'lastSeenAt',v_presence.last_seen_at);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.get_players_presence(p_user_ids text[])
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
  select jsonb_build_object('players',coalesce(jsonb_agg(jsonb_build_object(
    'uid',ids.uid,
    'isOnline',coalesce(p.last_seen_at >= now() - interval '2 minutes',false),
    'onlineSince',case when p.last_seen_at >= now() - interval '2 minutes' then p.online_since else null end,
    'lastSeenAt',p.last_seen_at
  )),'[]'::jsonb))
  from (select distinct unnest(coalesce(p_user_ids,'{}'::text[])) as uid limit 60) ids
  left join player_presence p on p.user_id=ids.uid;
$function$


CREATE OR REPLACE FUNCTION nexora.get_org_donation_ranking(p_org_id text, p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
declare v_ranking jsonb;
begin
  if not exists(select 1 from organization_members where org_id=p_org_id and user_id=p_user_id) then
    raise exception 'UNAUTHORIZED';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('uid',q.user_id,'username',q.username,'amount',q.net_amount) order by q.net_amount desc,q.username),'[]'::jsonb)
  into v_ranking
  from (
    select user_id,max(username) as username,
      sum(case when type='deposit' then amount when type='withdraw' then -amount else 0 end)::bigint as net_amount
    from organization_transactions
    where org_id=p_org_id and type in ('deposit','withdraw')
    group by user_id
    having sum(case when type='deposit' then amount when type='withdraw' then -amount else 0 end)>0
  ) q;
  return jsonb_build_object('ranking',v_ranking);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.enforce_company_capacity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_owned integer; v_reserved integer;
begin
  perform 1 from nexora.player_profiles where user_id=new.owner_uid for update;
  select count(*) into v_owned from nexora.companies where owner_uid=new.owner_uid and is_deleted=false;
  select count(*) into v_reserved from nexora.company_auctions
    where highest_bidder_uid=new.owner_uid and status='active';
  if v_reserved > 0 then raise exception 'COMPANY_AUCTION_PENDING'; end if;
  if v_owned >= 3 then raise exception 'COMPANY_CAPACITY_REACHED'; end if;
  return new;
end;
$function$


CREATE OR REPLACE FUNCTION nexora.settle_company_auction(p_auction_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_auction nexora.company_auctions%rowtype;
  v_company nexora.companies%rowtype;
  v_escrow nexora.company_auction_escrows%rowtype;
  v_tx text;
begin
  select * into v_auction from nexora.company_auctions where id=p_auction_id for update;
  if not found then return jsonb_build_object('settled',false,'reason','NOT_FOUND'); end if;
  if v_auction.status <> 'active' then return jsonb_build_object('settled',false,'reason','ALREADY_SETTLED'); end if;
  if v_auction.ends_at > now() then return jsonb_build_object('settled',false,'reason','NOT_EXPIRED'); end if;

  select * into v_company from nexora.companies where id=v_auction.company_id for update;
  if not found then
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    return jsonb_build_object('settled',true,'status','cancelled');
  end if;

  if v_auction.highest_bidder_uid is null then
    update nexora.company_auctions set status='unsold',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.companies set auction_id=null,auction_ends_at=null,auction_status='unsold',updated_at=now()
      where id=v_auction.company_id;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'notif_'||gen_random_uuid()::text,v_auction.seller_uid,
      'انتهى مزاد شركتك','انتهى المزاد دون عروض شراء. يمكنك عرض الشركة مجدداً.','market',false
    where exists (select 1 from nexora.player_private where user_id=v_auction.seller_uid and notifications_enabled=true);
    insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
      values('clog_'||gen_random_uuid()::text,v_auction.company_id,v_auction.seller_uid,'auction_unsold',0,'انتهى المزاد دون عروض شراء');
    return jsonb_build_object('settled',true,'status','unsold');
  end if;

  select * into v_escrow from nexora.company_auction_escrows
    where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid and status='reserved' for update;
  if not found or v_escrow.amount < v_auction.current_price then
    -- Fail closed: refund the bidder and return the company to its seller.
    if found then
      update nexora.wallets set balance=balance+v_escrow.amount,
        total_spent=greatest(0,total_spent-v_escrow.amount),updated_at=now()
        where user_id=v_auction.highest_bidder_uid;
      update nexora.company_auction_escrows set status='refunded',updated_at=now()
        where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
      v_tx:='tx_'||gen_random_uuid()::text;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
        values(v_tx,'SYSTEM',v_auction.highest_bidder_uid,v_escrow.amount,0,v_escrow.amount,
          'company_auction_refund',p_auction_id,'Refund after company auction settlement failed','completed');
      insert into nexora.notifications(id,user_id,title,body,type,is_read)
      select 'notif_'||gen_random_uuid()::text,v_auction.highest_bidder_uid,
        'أُعيد مبلغ المزايدة','تعذر إتمام بيع الشركة، وأُعيد مبلغ الضمان إلى رصيدك.','market',false
      where exists (select 1 from nexora.player_private where user_id=v_auction.highest_bidder_uid and notifications_enabled=true);
    end if;
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.companies set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now()
      where id=v_auction.company_id;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'notif_'||gen_random_uuid()::text,v_auction.seller_uid,
      'تعذر إتمام بيع الشركة','تعذر تأكيد مبلغ الضمان، وأُلغيت عملية البيع وأُعيدت الأموال المحجوزة.','market',false
    where exists (select 1 from nexora.player_private where user_id=v_auction.seller_uid and notifications_enabled=true);
    return jsonb_build_object('settled',true,'status','cancelled','reason','ESCROW_INVALID');
  end if;

  update nexora.wallets set balance=balance+v_auction.current_price,
    total_earned=total_earned+v_auction.current_price,updated_at=now()
    where user_id=v_auction.seller_uid;
  if not found then
    update nexora.wallets set balance=balance+v_escrow.amount,
      total_spent=greatest(0,total_spent-v_escrow.amount),updated_at=now()
      where user_id=v_auction.highest_bidder_uid;
    update nexora.company_auction_escrows set status='refunded',updated_at=now()
      where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
    v_tx:='tx_'||gen_random_uuid()::text;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,'SYSTEM',v_auction.highest_bidder_uid,v_escrow.amount,0,v_escrow.amount,
        'company_auction_refund',p_auction_id,'Refund because seller settlement account is unavailable','completed');
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.companies set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now()
      where id=v_auction.company_id;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'notif_'||gen_random_uuid()::text,v_auction.highest_bidder_uid,
      'تعذر إتمام شراء الشركة','لم نتمكن من إتمام الدفع للبائع، وأُعيد مبلغ المزايدة إلى رصيدك.','market',false
    where exists (select 1 from nexora.player_private where user_id=v_auction.highest_bidder_uid and notifications_enabled=true);
    return jsonb_build_object('settled',true,'status','cancelled','reason','SELLER_WALLET_MISSING');
  end if;

  update nexora.companies set owner_uid=v_auction.highest_bidder_uid,
    owner_name=v_auction.highest_bidder_name,auction_id=null,auction_ends_at=null,auction_status='sold',updated_at=now()
    where id=v_auction.company_id;
  update nexora.company_auction_escrows set status='released',updated_at=now()
    where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
  update nexora.company_auctions set status='sold',winning_bid=v_auction.current_price,
    settled_at=now(),updated_at=now() where id=p_auction_id;

  v_tx:='tx_'||gen_random_uuid()::text;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,'SYSTEM',v_auction.seller_uid,v_auction.current_price,0,
      v_auction.current_price,'company_auction_sale',v_auction.company_id,
      'Purchased company at auction: '||v_auction.company_name,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
    values('clog_'||gen_random_uuid()::text,v_auction.company_id,v_auction.highest_bidder_uid,
      'auction_sold',v_auction.current_price,'تم شراء الشركة في المزاد مقابل $'||v_auction.current_price::text);
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  select 'notif_'||gen_random_uuid()::text,v_auction.seller_uid,
    'تم بيع شركتك في المزاد','تم بيع '||v_auction.company_name||' مقابل $'||v_auction.current_price::text||'. تم إضافة المبلغ إلى رصيدك.','market',false
  where exists (select 1 from nexora.player_private where user_id=v_auction.seller_uid and notifications_enabled=true);
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  select 'notif_'||gen_random_uuid()::text,v_auction.highest_bidder_uid,
    'أصبحت مالكاً لشركة جديدة','فزت بمزاد '||v_auction.company_name||'. تم نقل الملكية إلى حسابك.','market',false
  where exists (select 1 from nexora.player_private where user_id=v_auction.highest_bidder_uid and notifications_enabled=true);
  return jsonb_build_object('settled',true,'status','sold','company_id',v_auction.company_id,'buyer_uid',v_auction.highest_bidder_uid,'price',v_auction.current_price);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.settle_expired_company_auctions()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_row record; v_count integer:=0;
begin
  for v_row in select id,asset_type from nexora.company_auctions where status='active' and ends_at<=now() order by ends_at for update skip locked loop
    if v_row.asset_type='factory' then perform nexora.settle_factory_auction(v_row.id);
    else perform nexora.settle_company_auction(v_row.id); end if;
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$function$


CREATE OR REPLACE FUNCTION nexora.list_company_for_auction(p_uid text, p_company_id text, p_starting_price bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_company nexora.companies%rowtype; v_auction_id text:='auc_'||gen_random_uuid()::text; v_ends timestamptz:=now()+interval '24 hours';
begin
  if p_starting_price is null or p_starting_price<1 or p_starting_price>1000000000000 then raise exception 'INVALID_STARTING_PRICE'; end if;
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.is_deleted then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.level<50 then raise exception 'COMPANY_LEVEL_TOO_LOW'; end if;
  if v_company.auction_id is not null then raise exception 'COMPANY_ALREADY_LISTED'; end if;
  if v_company.level_upgrade_started_at is not null or v_company.vault_upgrade_started_at is not null then raise exception 'COMPANY_UPGRADE_IN_PROGRESS'; end if;
  insert into nexora.company_auctions(id,company_id,company_name,company_sector,company_level,seller_uid,seller_name,starting_price,current_price,ends_at)
    values(v_auction_id,v_company.id,v_company.name,v_company.sector,v_company.level,p_uid,v_company.owner_name,p_starting_price,p_starting_price,v_ends);
  update nexora.companies set auction_id=v_auction_id,auction_ends_at=v_ends,auction_status='active',updated_at=now() where id=p_company_id;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
    values('clog_'||gen_random_uuid()::text,p_company_id,p_uid,'auction_listed',0,'تم إدراج الشركة في المزاد بسعر بداية $'||p_starting_price::text);
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  select 'notif_'||gen_random_uuid()::text,p_uid,'تم إدراج شركتك في المزاد',
    'بدأ مزاد '||v_company.name||' لمدة 24 ساعة.','market',false
  where exists (select 1 from nexora.player_private where user_id=p_uid and notifications_enabled=true);
  return jsonb_build_object('auction_id',v_auction_id,'ends_at',v_ends);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.place_company_auction_bid(p_uid text, p_auction_id text, p_amount bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_auction nexora.company_auctions%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_old_wallet nexora.wallets%rowtype;
  v_old_escrow nexora.company_auction_escrows%rowtype;
  v_min bigint; v_owned integer; v_reserved integer; v_charge bigint;
  v_tx text; v_log text;
begin
  perform nexora.settle_expired_company_auctions();
  select * into v_auction from nexora.company_auctions where id=p_auction_id for update;
  if not found then raise exception 'AUCTION_NOT_FOUND'; end if;
  if v_auction.status<>'active' then raise exception 'AUCTION_NOT_ACTIVE'; end if;
  if v_auction.ends_at<=now() then return jsonb_build_object('ended',true); end if;
  if v_auction.seller_uid=p_uid then raise exception 'CANNOT_BID_OWN_COMPANY'; end if;
  if p_amount is null or p_amount<1 then raise exception 'INVALID_BID'; end if;
  v_min:=case when v_auction.highest_bidder_uid is null then v_auction.starting_price else v_auction.current_price+1 end;
  if p_amount<v_min then raise exception 'BID_TOO_LOW'; end if;

  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select count(*) into v_owned from nexora.companies where owner_uid=p_uid and is_deleted=false;
  select count(*) into v_reserved from nexora.company_auctions
    where highest_bidder_uid=p_uid and status='active' and ends_at>now() and id<>p_auction_id;
  if v_auction.highest_bidder_uid is distinct from p_uid and v_owned+v_reserved>=3 then
    raise exception 'COMPANY_CAPACITY_REACHED';
  end if;

  if v_auction.highest_bidder_uid is not null and v_auction.highest_bidder_uid<>p_uid then
    select * into v_old_escrow from nexora.company_auction_escrows
      where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid and status='reserved' for update;
    if found then
      update nexora.wallets set balance=balance+v_old_escrow.amount,
        total_spent=greatest(0,total_spent-v_old_escrow.amount),updated_at=now()
        where user_id=v_auction.highest_bidder_uid;
      update nexora.company_auction_escrows set status='refunded',updated_at=now()
        where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
      v_tx:='tx_'||gen_random_uuid()::text;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
        values(v_tx,'SYSTEM',v_auction.highest_bidder_uid,v_old_escrow.amount,0,v_old_escrow.amount,
          'company_auction_refund',p_auction_id,'Refund for an outbid company auction','completed');
      insert into nexora.notifications(id,user_id,title,body,type,is_read)
      select 'notif_'||gen_random_uuid()::text,v_auction.highest_bidder_uid,
        'تم تجاوز عرضك','تم تجاوز عرضك على شركة '||v_auction.company_name||' وأُعيد مبلغ الضمان إلى رصيدك.','market',false
      where exists (select 1 from nexora.player_private where user_id=v_auction.highest_bidder_uid and notifications_enabled=true);
    end if;
  end if;

  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_auction.highest_bidder_uid=p_uid then
    select * into v_old_escrow from nexora.company_auction_escrows
      where auction_id=p_auction_id and bidder_uid=p_uid and status='reserved' for update;
    v_charge:=greatest(0,p_amount-coalesce(v_old_escrow.amount,0));
  else
    v_charge:=p_amount;
  end if;
  if v_wallet.balance<v_charge then raise exception 'INSUFFICIENT_FUNDS'; end if;
  if v_charge>0 then
    update nexora.wallets set balance=balance-v_charge,total_spent=total_spent+v_charge,updated_at=now() where user_id=p_uid;
    v_tx:='tx_'||gen_random_uuid()::text;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,p_uid,'SYSTEM',v_charge,0,v_charge,'company_auction_escrow',p_auction_id,
        'Escrow reserved for bid on '||v_auction.company_name,'completed');
  end if;
  insert into nexora.company_auction_escrows(auction_id,bidder_uid,amount,status,updated_at)
    values(p_auction_id,p_uid,p_amount,'reserved',now())
    on conflict (auction_id,bidder_uid) do update set amount=excluded.amount,status='reserved',updated_at=now();
  update nexora.company_auctions set current_price=p_amount,highest_bidder_uid=p_uid,
    highest_bidder_name=v_profile.username,updated_at=now() where id=p_auction_id;
  insert into nexora.company_auction_bids(id,auction_id,bidder_uid,bidder_name,amount)
    values('abid_'||gen_random_uuid()::text,p_auction_id,p_uid,v_profile.username,p_amount);
  v_log:='clog_'||gen_random_uuid()::text;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
    values(v_log,v_auction.company_id,v_auction.seller_uid,'auction_bid',p_amount,
      'عرض شراء جديد بقيمة $'||p_amount::text||' من '||v_profile.username);
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  select 'notif_'||gen_random_uuid()::text,v_auction.seller_uid,'عرض شراء جديد على شركتك',
    'قدّم '||v_profile.username||' عرضاً بقيمة $'||p_amount::text||' على '||v_auction.company_name||'.','market',false
  where exists (select 1 from nexora.player_private where user_id=v_auction.seller_uid and notifications_enabled=true);
  return jsonb_build_object('ok',true,'current_price',p_amount,'minimum_next_bid',p_amount+1);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.fetch_company_auctions(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_result jsonb;
begin
  perform nexora.settle_expired_company_auctions();
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',a.id,'assetType',a.asset_type,'companyId',a.company_id,'factoryId',a.factory_id,
    'companyName',a.company_name,'companySector',a.company_sector,'companyLevel',a.company_level,
    'sellerUid',a.seller_uid,'sellerName',a.seller_name,'startingPrice',a.starting_price,'currentPrice',a.current_price,
    'highestBidderUid',a.highest_bidder_uid,'highestBidderName',a.highest_bidder_name,
    'startsAt',floor(extract(epoch from a.starts_at)*1000)::bigint,
    'endsAt',floor(extract(epoch from a.ends_at)*1000)::bigint,'status',a.status,
    'winningBid',a.winning_bid,'createdAt',floor(extract(epoch from a.created_at)*1000)::bigint
  ) order by case when a.status='active' then 0 else 1 end,a.ends_at asc),'[]'::jsonb)
  into v_result from nexora.company_auctions a
  where a.status='active' or a.created_at>now()-interval '30 days'
    or a.seller_uid=p_uid or a.highest_bidder_uid=p_uid;
  return v_result;
end
$function$


CREATE OR REPLACE FUNCTION nexora.delete_company(p_uid text, p_company_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_company nexora.companies%rowtype;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found or v_company.is_deleted then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.auction_id is not null then raise exception 'COMPANY_IN_AUCTION'; end if;
  -- Keep the immutable operation log and archive the company instead of deleting audit history.
  update nexora.companies set is_deleted=true,deleted_at=now(),updated_at=now() where id=p_company_id;
  update nexora.player_profiles set stats=jsonb_set(coalesce(stats,'{}'::jsonb),'{companiesOwned}',
    to_jsonb(greatest(0,coalesce((stats->>'companiesOwned')::integer,0)-1)),true),updated_at=now()
    where user_id=p_uid;
  insert into nexora.audit_logs(id,user_id,action,entity_type,entity_id,details)
    values('audit_'||gen_random_uuid()::text,p_uid,'delete_company','company',p_company_id,
      jsonb_build_object('company_name',v_company.name,'company_level',v_company.level));
  return jsonb_build_object('ok',true,'archived',true);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.reset_player_skills(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_refund integer;
  v_cost bigint := 2500;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_profile from nexora.player_profiles where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_refund :=
    coalesce((v_profile.skills->>'trade')::integer, 0) +
    coalesce((v_profile.skills->>'management')::integer, 0) +
    coalesce((v_profile.skills->>'industry')::integer, 0) +
    coalesce((v_profile.skills->>'negotiation')::integer, 0) +
    coalesce((v_profile.skills->>'finance')::integer, 0) +
    coalesce((v_profile.skills->>'leadership')::integer, 0);
  if v_refund < 1 then raise exception 'NO_SKILLS_TO_RESET'; end if;

  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;

  update nexora.wallets
    set balance = balance - v_cost,
        total_spent = total_spent + v_cost,
        last_tx_id = v_tx,
        updated_at = now()
    where user_id = p_uid;

  update nexora.player_profiles
    set skills = jsonb_build_object(
      'trade', 0, 'management', 0, 'industry', 0,
      'negotiation', 0, 'finance', 0, 'leadership', 0
    ),
    skill_points = skill_points + v_refund,
    updated_at = now()
    where user_id = p_uid;

  insert into nexora.transactions(
    id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status
  ) values (
    v_tx, p_uid, 'SYSTEM', v_cost, 0, v_cost, 'skill_reset', p_uid,
    'Skill reset; refunded ' || v_refund::text || ' skill points', 'completed'
  );

  return jsonb_build_object('ok', true, 'refunded_points', v_refund, 'cost', v_cost);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.factory_resource_config(p_resource_id text)
 RETURNS TABLE(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select cfg.founding_cost,cfg.production_rate,cfg.operating_cost,cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,1.10::numeric,25.00::numeric,1.00::numeric),
    ('silicon_ore',2400,1.03,28.00,1.20),
    ('energy_cells',3200,0.92,32.00,1.40),
    ('crude_alloy',4200,0.89,35.00,1.65),
    ('carbon_fiber',6000,0.88,42.00,2.10),
    ('rare_minerals',9000,0.87,50.00,3.60),
    ('titanium_ore',12000,0.86,60.00,4.00),
    ('polymer_resin',15000,0.85,65.00,4.50),
    ('biotech_gel',22000,0.84,80.00,5.00),
    ('quantum_dust',30000,0.83,110.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$function$


CREATE OR REPLACE FUNCTION nexora.found_factory(p_uid text, p_name text, p_resource_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_count integer;
  v_reserved integer;
  v_id text := 'fac_' || gen_random_uuid()::text;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  if p_name is null or char_length(btrim(p_name))<2 or char_length(btrim(p_name))>48 then raise exception 'INVALID_NAME'; end if;
  select * into v_cfg from nexora.factory_resource_config(p_resource_id);
  if not found then raise exception 'INVALID_RESOURCE'; end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select count(*) into v_count from nexora.factories where owner_uid=p_uid;
  select count(*) into v_reserved from nexora.company_auctions
    where asset_type='factory' and highest_bidder_uid=p_uid and status='active' and ends_at>now();
  if v_count+v_reserved>=3 then raise exception 'FACTORY_CAPACITY_REACHED'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cfg.founding_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  insert into nexora.factories(id,owner_uid,owner_name,name,resource_id,level,skill_level,warehouse_qty,last_produced_at,warehouse_level)
  values(v_id,p_uid,v_profile.username,btrim(p_name),p_resource_id,1,0,0,now(),1);
  update nexora.wallets set balance=balance-v_cfg.founding_cost,total_spent=total_spent+v_cfg.founding_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cfg.founding_cost,0,v_cfg.founding_cost,'factory_create',v_id,'Founded raw-resource factory: '||btrim(p_name),'completed');
  return jsonb_build_object('ok',true,'factory_id',v_id,'cost',v_cfg.founding_cost);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.sync_factory_production(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_factory nexora.factories%rowtype; v_wallet nexora.wallets%rowtype; v_cfg record;
  v_capacity bigint; v_space bigint; v_elapsed numeric; v_hours numeric; v_rate numeric; v_expense numeric;
  v_raw_cost numeric; v_cost bigint; v_cost_remainder numeric; v_raw_output numeric; v_qty bigint;
  v_production_remainder numeric; v_tx text:='tx_'||gen_random_uuid()::text;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  v_capacity:=nexora.factory_warehouse_capacity(v_factory.resource_id,v_factory.warehouse_level);
  if not v_factory.is_active then
    update nexora.factories set last_produced_at=now(),updated_at=now() where id=p_factory_id;
    return jsonb_build_object('produced',0,'operating_cost',0,'warehouse_qty',v_factory.warehouse_qty,'capacity',v_capacity,'is_active',false);
  end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_space:=greatest(0,v_capacity-v_factory.warehouse_qty);
  v_elapsed:=least(12,greatest(0,extract(epoch from (now()-v_factory.last_produced_at))/3600));
  if v_space=0 or v_elapsed=0 then
    update nexora.factories set last_produced_at=now(),updated_at=now() where id=p_factory_id;
    return jsonb_build_object('produced',0,'operating_cost',0,'warehouse_qty',v_factory.warehouse_qty,'capacity',v_capacity);
  end if;
  v_rate:=v_cfg.production_rate*(1+greatest(0,v_factory.level-1)*0.90)*(1+v_factory.skill_level*0.02);
  v_expense:=v_cfg.operating_cost*(1+greatest(0,v_factory.level-1)*0.025)*(1-v_factory.skill_level*0.015);
  v_hours:=least(v_elapsed,greatest(0,(v_space-v_factory.production_remainder)/v_rate));
  v_raw_cost:=v_factory.operating_cost_remainder+v_expense*v_hours;
  v_cost:=floor(v_raw_cost)::bigint;
  if v_raw_cost>v_wallet.balance then
    v_hours:=greatest(0,(v_wallet.balance-v_factory.operating_cost_remainder)/v_expense);
    v_cost:=v_wallet.balance; v_cost_remainder:=0;
  else v_cost_remainder:=v_raw_cost-v_cost;
  end if;
  v_raw_output:=v_factory.production_remainder+v_rate*v_hours;
  v_qty:=least(v_space,floor(v_raw_output)::bigint);
  v_production_remainder:=case when v_qty>=v_space then 0 else v_raw_output-v_qty end;
  if v_cost>0 then
    update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_operating',p_factory_id,'Factory operating costs: '||v_factory.name,'completed');
  end if;
  update nexora.factories set warehouse_qty=warehouse_qty+v_qty,production_remainder=v_production_remainder,
    operating_cost_remainder=v_cost_remainder,last_produced_at=now(),updated_at=now() where id=p_factory_id;
  return jsonb_build_object('produced',v_qty,'operating_cost',v_cost,'warehouse_qty',v_factory.warehouse_qty+v_qty,'capacity',v_capacity);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.upgrade_factory(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_cost bigint;
  v_materials integer;
  v_owned bigint;
  v_target integer;
  v_ends timestamptz;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;
  if v_factory.level>=100 then raise exception 'MAX_LEVEL'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_target:=v_factory.level+1;
  v_cost:=ceil(v_cfg.founding_cost*0.18*power(v_factory.level::numeric,1.25))::bigint;
  v_materials:=ceil(v_factory.level*v_cfg.rarity_factor*2)::integer;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  select quantity into v_owned from nexora.inventory where user_id=p_uid and item_id=v_factory.resource_id for update;
  if not found or coalesce(v_owned,0)<v_materials then raise exception 'MISSING_FACTORY_MATERIALS'; end if;
  v_ends:=now()+make_interval(secs=>((5+v_factory.level*8)*v_cfg.rarity_factor*60)::double precision);
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.inventory set quantity=quantity-v_materials,updated_at=now() where user_id=p_uid and item_id=v_factory.resource_id;
  update nexora.factories set upgrade_started_at=now(),upgrade_ends_at=v_ends,upgrade_target_level=v_target,upgrade_cost=v_cost,updated_at=now() where id=p_factory_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_upgrade',p_factory_id,'Started factory upgrade: '||v_factory.name,'completed');
  return jsonb_build_object('target_level',v_target,'ends_at',v_ends,'cost',v_cost,'materials',v_materials);
end
$function$


CREATE OR REPLACE FUNCTION nexora.complete_factory_upgrade(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_factory nexora.factories%rowtype;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.upgrade_ends_at is null then raise exception 'NO_UPGRADE_IN_PROGRESS'; end if;
  if v_factory.upgrade_ends_at>now() then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  update nexora.factories set level=upgrade_target_level,upgrade_started_at=null,upgrade_ends_at=null,upgrade_target_level=null,upgrade_cost=null,updated_at=now() where id=p_factory_id;
  return jsonb_build_object('ok',true,'level',v_factory.upgrade_target_level);
end $function$


CREATE OR REPLACE FUNCTION nexora.upgrade_factory_skill(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_cost bigint;
  v_materials integer;
  v_owned bigint;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.skill_level>=10 then raise exception 'SKILL_MAXED'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_cost:=ceil(v_cfg.founding_cost*0.18*power((v_factory.skill_level+1)::numeric,1.35))::bigint;
  v_materials:=ceil((v_factory.skill_level+1)*v_cfg.rarity_factor)::integer;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  select quantity into v_owned from nexora.inventory where user_id=p_uid and item_id=v_factory.resource_id for update;
  if not found or coalesce(v_owned,0)<v_materials then raise exception 'MISSING_FACTORY_MATERIALS'; end if;
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.inventory set quantity=quantity-v_materials,updated_at=now() where user_id=p_uid and item_id=v_factory.resource_id;
  update nexora.factories set skill_level=skill_level+1,updated_at=now() where id=p_factory_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_skill',p_factory_id,'Factory operator skill training: '||v_factory.name,'completed');
  return jsonb_build_object('ok',true,'skill_level',v_factory.skill_level+1,'cost',v_cost,'materials',v_materials);
end $function$


CREATE OR REPLACE FUNCTION nexora.set_factory_active(p_uid text, p_factory_id text, p_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_factory nexora.factories%rowtype;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;

  -- Bank any accrued production before pausing so the last active interval is not lost.
  if not coalesce(p_active,false) and v_factory.is_active then
    perform nexora.sync_factory_production(p_uid,p_factory_id);
  end if;

  update nexora.factories
    set is_active=coalesce(p_active,false),last_produced_at=now(),updated_at=now()
    where id=p_factory_id;
  return jsonb_build_object('ok',true,'is_active',coalesce(p_active,false));
end $function$


CREATE OR REPLACE FUNCTION nexora.withdraw_factory_warehouse(p_uid text, p_factory_id text, p_quantity integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_factory nexora.factories%rowtype;
begin
  if p_quantity is null or p_quantity<1 or p_quantity>1000000 then raise exception 'INVALID_QUANTITY'; end if;
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_qty<p_quantity then raise exception 'WAREHOUSE_INSUFFICIENT_STOCK'; end if;
  update nexora.factories set warehouse_qty=warehouse_qty-p_quantity,updated_at=now() where id=p_factory_id;
  insert into nexora.inventory(user_id,item_id,quantity,updated_at) values(p_uid,v_factory.resource_id,p_quantity,now())
  on conflict(user_id,item_id) do update set quantity=nexora.inventory.quantity+excluded.quantity,updated_at=now();
  return jsonb_build_object('ok',true,'withdrawn',p_quantity,'remaining',v_factory.warehouse_qty-p_quantity);
end $function$


CREATE OR REPLACE FUNCTION nexora.upgrade_factory_warehouse(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_factory nexora.factories%rowtype; v_wallet nexora.wallets%rowtype;
  v_cost bigint; v_target integer; v_ends timestamptz; v_tx text:='tx_'||gen_random_uuid()::text;
  v_costs bigint[]:=array[1500,4000,10000,25000];
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_level>=5 then raise exception 'WAREHOUSE_MAX_LEVEL'; end if;
  if v_factory.warehouse_upgrade_ends_at is not null and v_factory.warehouse_upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;
  if v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;
  v_target:=greatest(1,v_factory.warehouse_level)+1;
  v_cost:=v_costs[v_factory.warehouse_level];
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_ends:=now()+make_interval(mins=>case v_target when 2 then 20 when 3 then 60 when 4 then 180 else 480 end);
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.factories set warehouse_upgrade_started_at=now(),warehouse_upgrade_ends_at=v_ends,
    warehouse_upgrade_target_level=v_target,warehouse_upgrade_cost=v_cost,updated_at=now() where id=p_factory_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_warehouse_upgrade',p_factory_id,'Factory warehouse expansion: '||v_factory.name,'completed');
  return jsonb_build_object('target_level',v_target,'ends_at',v_ends,'cost',v_cost,
    'capacity',nexora.factory_warehouse_capacity(v_factory.resource_id,v_target));
end;
$function$


CREATE OR REPLACE FUNCTION nexora.complete_factory_warehouse_upgrade(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_factory nexora.factories%rowtype; v_target integer; v_capacity bigint;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_upgrade_ends_at is null then raise exception 'NO_UPGRADE_IN_PROGRESS'; end if;
  if v_factory.warehouse_upgrade_ends_at>now() then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  v_target:=v_factory.warehouse_upgrade_target_level;
  if v_target<>v_factory.warehouse_level+1 or v_target>5 then raise exception 'INVALID_UPGRADE_STATE'; end if;
  v_capacity:=nexora.factory_warehouse_capacity(v_factory.resource_id,v_target);
  update nexora.factories set warehouse_level=v_target,warehouse_upgrade_started_at=null,
    warehouse_upgrade_ends_at=null,warehouse_upgrade_target_level=null,warehouse_upgrade_cost=null,updated_at=now()
    where id=p_factory_id;
  return jsonb_build_object('ok',true,'warehouse_level',v_target,'capacity',v_capacity);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.list_factory_for_auction(p_uid text, p_factory_id text, p_starting_price bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_factory nexora.factories%rowtype; v_id text:='auc_'||gen_random_uuid()::text; v_ends timestamptz:=now()+interval '24 hours';
begin
  if p_starting_price is null or p_starting_price<1 or p_starting_price>1000000000000 then raise exception 'INVALID_STARTING_PRICE'; end if;
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.level<50 then raise exception 'FACTORY_LEVEL_TOO_LOW'; end if;
  if v_factory.auction_id is not null then raise exception 'FACTORY_ALREADY_LISTED'; end if;
  if (v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at>now())
    or (v_factory.warehouse_upgrade_ends_at is not null and v_factory.warehouse_upgrade_ends_at>now()) then raise exception 'FACTORY_UPGRADE_IN_PROGRESS'; end if;
  insert into nexora.company_auctions(id,asset_type,company_id,factory_id,company_name,company_sector,company_level,seller_uid,seller_name,starting_price,current_price,ends_at)
  values(v_id,'factory',null,v_factory.id,v_factory.name,'factory',v_factory.level,p_uid,v_factory.owner_name,p_starting_price,p_starting_price,v_ends);
  update nexora.factories set auction_id=v_id,auction_ends_at=v_ends,auction_status='active',updated_at=now() where id=p_factory_id;
  return jsonb_build_object('auction_id',v_id,'ends_at',v_ends);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.place_factory_auction_bid(p_uid text, p_auction_id text, p_amount bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_a nexora.company_auctions%rowtype;
  v_p nexora.player_profiles%rowtype;
  v_w nexora.wallets%rowtype;
  v_e nexora.company_auction_escrows%rowtype;
  v_charge bigint;
  v_owned integer;
  v_reserved integer;
  v_tx text;
begin
  perform nexora.settle_expired_company_auctions();
  select * into v_a from nexora.company_auctions where id=p_auction_id for update;
  if not found or v_a.asset_type<>'factory' then raise exception 'AUCTION_NOT_FOUND'; end if;
  if v_a.status<>'active' then raise exception 'AUCTION_NOT_ACTIVE'; end if;
  if v_a.ends_at<=now() then return jsonb_build_object('ended',true); end if;
  if v_a.seller_uid=p_uid then raise exception 'CANNOT_BID_OWN_FACTORY'; end if;
  if p_amount is null or p_amount < (case when v_a.highest_bidder_uid is null then v_a.starting_price else v_a.current_price+1 end) then raise exception 'BID_TOO_LOW'; end if;
  select * into v_p from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select count(*) into v_owned from nexora.factories where owner_uid=p_uid;
  select count(*) into v_reserved from nexora.company_auctions where asset_type='factory' and highest_bidder_uid=p_uid and status='active' and ends_at>now() and id<>p_auction_id;
  if v_a.highest_bidder_uid is distinct from p_uid and v_owned+v_reserved>=3 then raise exception 'FACTORY_CAPACITY_REACHED'; end if;
  if v_a.highest_bidder_uid is not null and v_a.highest_bidder_uid<>p_uid then
    select * into v_e from nexora.company_auction_escrows where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid and status='reserved' for update;
    if found then
      update nexora.wallets set balance=balance+v_e.amount,total_spent=greatest(0,total_spent-v_e.amount),updated_at=now() where user_id=v_a.highest_bidder_uid;
      update nexora.company_auction_escrows set status='refunded',updated_at=now() where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
      v_tx:='tx_'||gen_random_uuid()::text;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,'SYSTEM',v_a.highest_bidder_uid,v_e.amount,0,v_e.amount,'factory_auction_refund',p_auction_id,'Refund for an outbid factory auction','completed');
    end if;
  end if;
  select * into v_w from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_a.highest_bidder_uid=p_uid then
    select * into v_e from nexora.company_auction_escrows where auction_id=p_auction_id and bidder_uid=p_uid and status='reserved' for update;
    v_charge:=greatest(0,p_amount-coalesce(v_e.amount,0));
  else
    v_charge:=p_amount;
  end if;
  if v_w.balance<v_charge then raise exception 'INSUFFICIENT_FUNDS'; end if;
  if v_charge>0 then
    update nexora.wallets set balance=balance-v_charge,total_spent=total_spent+v_charge,updated_at=now() where user_id=p_uid;
    v_tx:='tx_'||gen_random_uuid()::text;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,'SYSTEM',v_charge,0,v_charge,'factory_auction_escrow',p_auction_id,'Escrow reserved for factory auction bid','completed');
  end if;
  insert into nexora.company_auction_escrows(auction_id,bidder_uid,amount,status,updated_at)
  values(p_auction_id,p_uid,p_amount,'reserved',now())
  on conflict(auction_id,bidder_uid) do update set amount=excluded.amount,status='reserved',updated_at=now();
  update nexora.company_auctions set current_price=p_amount,highest_bidder_uid=p_uid,highest_bidder_name=v_p.username,updated_at=now() where id=p_auction_id;
  insert into nexora.company_auction_bids(id,auction_id,bidder_uid,bidder_name,amount)
  values('abid_'||gen_random_uuid()::text,p_auction_id,p_uid,v_p.username,p_amount);
  return jsonb_build_object('ok',true,'current_price',p_amount,'minimum_next_bid',p_amount+1);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.settle_factory_auction(p_auction_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_a nexora.company_auctions%rowtype;
  v_f nexora.factories%rowtype;
  v_e nexora.company_auction_escrows%rowtype;
  v_tx text;
begin
  select * into v_a from nexora.company_auctions where id=p_auction_id for update;
  if not found or v_a.asset_type<>'factory' then return jsonb_build_object('settled',false,'reason','NOT_FOUND'); end if;
  if v_a.status<>'active' or v_a.ends_at>now() then return jsonb_build_object('settled',false,'reason','NOT_EXPIRED'); end if;
  select * into v_f from nexora.factories where id=v_a.factory_id for update;
  if not found then
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    return jsonb_build_object('settled',true,'status','cancelled');
  end if;
  if v_a.highest_bidder_uid is null then
    update nexora.company_auctions set status='unsold',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.factories set auction_id=null,auction_ends_at=null,auction_status='unsold',updated_at=now() where id=v_a.factory_id;
    return jsonb_build_object('settled',true,'status','unsold');
  end if;
  select * into v_e from nexora.company_auction_escrows where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid and status='reserved' for update;
  if not found or v_e.amount<v_a.current_price then
    if found then
      update nexora.wallets set balance=balance+v_e.amount,total_spent=greatest(0,total_spent-v_e.amount),updated_at=now() where user_id=v_a.highest_bidder_uid;
      update nexora.company_auction_escrows set status='refunded',updated_at=now() where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
      v_tx:='tx_'||gen_random_uuid()::text;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,'SYSTEM',v_a.highest_bidder_uid,v_e.amount,0,v_e.amount,'factory_auction_refund',p_auction_id,'Refund after factory auction settlement failed','completed');
    end if;
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.factories set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now() where id=v_a.factory_id;
    return jsonb_build_object('settled',true,'status','cancelled','reason','ESCROW_INVALID');
  end if;
  update nexora.wallets set balance=balance+v_a.current_price,total_earned=total_earned+v_a.current_price,updated_at=now() where user_id=v_a.seller_uid;
  if not found then
    update nexora.wallets set balance=balance+v_e.amount,total_spent=greatest(0,total_spent-v_e.amount),updated_at=now() where user_id=v_a.highest_bidder_uid;
    update nexora.company_auction_escrows set status='refunded',updated_at=now() where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
    v_tx:='tx_'||gen_random_uuid()::text;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,'SYSTEM',v_a.highest_bidder_uid,v_e.amount,0,v_e.amount,'factory_auction_refund',p_auction_id,'Refund because seller wallet is unavailable','completed');
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.factories set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now() where id=v_a.factory_id;
    return jsonb_build_object('settled',true,'status','cancelled','reason','SELLER_WALLET_MISSING');
  end if;
  update nexora.factories set owner_uid=v_a.highest_bidder_uid,owner_name=v_a.highest_bidder_name,auction_id=null,auction_ends_at=null,auction_status='sold',updated_at=now() where id=v_a.factory_id;
  update nexora.company_auction_escrows set status='released',updated_at=now() where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
  update nexora.company_auctions set status='sold',winning_bid=v_a.current_price,settled_at=now(),updated_at=now() where id=p_auction_id;
  v_tx:='tx_'||gen_random_uuid()::text;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',v_a.seller_uid,v_a.current_price,0,v_a.current_price,'factory_auction_sale',v_a.factory_id,'Factory sold at auction: '||v_a.company_name,'completed');
  return jsonb_build_object('settled',true,'status','sold','factory_id',v_a.factory_id,'buyer_uid',v_a.highest_bidder_uid,'price',v_a.current_price);
end;
$function$


CREATE OR REPLACE FUNCTION nexora.factory_warehouse_capacity(p_resource_id text, p_level integer)
 RETURNS bigint
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select greatest(1,floor((array[3500,7000,14000,25000,40000]::bigint[])[greatest(1,least(5,coalesce(p_level,1)))]::numeric /
    case p_resource_id
      when 'copper_wire' then 28::numeric when 'silicon_ore' then 35::numeric
      when 'energy_cells' then 45::numeric when 'crude_alloy' then 40::numeric
      when 'carbon_fiber' then 55::numeric when 'rare_minerals' then 70::numeric
      when 'titanium_ore' then 85::numeric when 'polymer_resin' then 95::numeric
      when 'biotech_gel' then 120::numeric when 'quantum_dust' then 160::numeric
      else 30::numeric
    end))::bigint
$function$


-- Triggers
CREATE TRIGGER audit_logs_immutable BEFORE DELETE OR UPDATE ON nexora.audit_logs FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();
CREATE TRIGGER companies_capacity_guard BEFORE INSERT ON nexora.companies FOR EACH ROW EXECUTE FUNCTION nexora.enforce_company_capacity();
CREATE TRIGGER company_logs_immutable BEFORE DELETE OR UPDATE ON nexora.company_logs FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();
CREATE TRIGGER contract_claims_immutable BEFORE DELETE OR UPDATE ON nexora.contract_claims FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();
CREATE TRIGGER daily_claims_immutable BEFORE DELETE OR UPDATE ON nexora.daily_claims FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();
CREATE TRIGGER organization_transactions_immutable BEFORE DELETE OR UPDATE ON nexora.organization_transactions FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();
CREATE TRIGGER player_achievements_immutable BEFORE DELETE OR UPDATE ON nexora.player_achievements FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();
CREATE TRIGGER player_missions_immutable BEFORE DELETE OR UPDATE ON nexora.player_missions FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();
CREATE TRIGGER enforce_skill_point_progression BEFORE INSERT OR UPDATE ON nexora.player_profiles FOR EACH ROW EXECUTE FUNCTION nexora.enforce_skill_point_progression();
CREATE TRIGGER transactions_immutable BEFORE DELETE OR UPDATE ON nexora.transactions FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

-- RLS policies


-- RLS
alter table nexora.audit_logs enable row level security;
alter table nexora.chat_rate_limits enable row level security;
alter table nexora.companies enable row level security;
alter table nexora.company_auction_bids enable row level security;
alter table nexora.company_auction_escrows enable row level security;
alter table nexora.company_auctions enable row level security;
alter table nexora.company_logs enable row level security;
alter table nexora.contract_claims enable row level security;
alter table nexora.conversation_messages enable row level security;
alter table nexora.conversations enable row level security;
alter table nexora.daily_claims enable row level security;
alter table nexora.diagnostics_admins enable row level security;
alter table nexora.factories enable row level security;
alter table nexora.global_chat_messages enable row level security;
alter table nexora.inventory enable row level security;
alter table nexora.market_listings enable row level security;
alter table nexora.market_orders enable row level security;
alter table nexora.notifications enable row level security;
alter table nexora.organization_invites enable row level security;
alter table nexora.organization_members enable row level security;
alter table nexora.organization_requests enable row level security;
alter table nexora.organization_transactions enable row level security;
alter table nexora.organizations enable row level security;
alter table nexora.player_achievements enable row level security;
alter table nexora.player_missions enable row level security;
alter table nexora.player_presence enable row level security;
alter table nexora.player_private enable row level security;
alter table nexora.player_profiles enable row level security;
alter table nexora.player_reports enable row level security;
alter table nexora.transactions enable row level security;
alter table nexora.user_blocks enable row level security;
alter table nexora.usernames enable row level security;
alter table nexora.wallets enable row level security;
alter table nexora.world_events enable row level security;
