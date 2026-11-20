-- CI-ONLY, DATA-FREE snapshot generated from the live NOVA production catalog on 2026-11-20.
-- Never apply this file to production. It is an isolated-test baseline only.
SET check_function_bodies = off;
CREATE SCHEMA IF NOT EXISTS nexora;

CREATE TABLE nexora.audit_logs (
  id text NOT NULL,
  user_id text,
  action text NOT NULL,
  entity_type text DEFAULT ''::text NOT NULL,
  entity_id text DEFAULT ''::text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.chat_rate_limits (
  id text NOT NULL,
  last_sent_at timestamp with time zone
);

CREATE TABLE nexora.companies (
  id text NOT NULL,
  owner_uid text NOT NULL,
  owner_name text NOT NULL,
  name text NOT NULL,
  sector text NOT NULL,
  level integer DEFAULT 1 NOT NULL,
  capital bigint DEFAULT 0 NOT NULL,
  employees_count integer DEFAULT 0 NOT NULL,
  base_revenue_per_hour bigint DEFAULT 0 NOT NULL,
  expense_per_hour bigint DEFAULT 0 NOT NULL,
  total_revenue bigint DEFAULT 0 NOT NULL,
  vault_level integer DEFAULT 1 NOT NULL,
  vault_balance bigint DEFAULT 0 NOT NULL,
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
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  is_deleted boolean DEFAULT false NOT NULL,
  deleted_at timestamp with time zone
);

CREATE TABLE nexora.company_auction_bids (
  id text NOT NULL,
  auction_id text NOT NULL,
  bidder_uid text NOT NULL,
  bidder_name text NOT NULL,
  amount bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.company_auction_escrows (
  auction_id text NOT NULL,
  bidder_uid text NOT NULL,
  amount bigint NOT NULL,
  status text DEFAULT 'reserved'::text NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.company_auctions (
  id text NOT NULL,
  company_id text,
  company_name text NOT NULL,
  company_sector text NOT NULL,
  company_level integer NOT NULL,
  seller_uid text NOT NULL,
  seller_name text NOT NULL,
  starting_price bigint NOT NULL,
  current_price bigint NOT NULL,
  highest_bidder_uid text,
  highest_bidder_name text,
  starts_at timestamp with time zone DEFAULT now() NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  winning_bid bigint,
  settled_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  asset_type text DEFAULT 'company'::text NOT NULL,
  factory_id text
);

CREATE TABLE nexora.company_logs (
  id text NOT NULL,
  company_id text NOT NULL,
  owner_uid text NOT NULL,
  action text NOT NULL,
  amount bigint DEFAULT 0 NOT NULL,
  details text DEFAULT ''::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.contract_claims (
  user_id text NOT NULL,
  contract_id text NOT NULL,
  amount bigint NOT NULL,
  claimed_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.contract_config (
  config_key text NOT NULL,
  config_value jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.contract_daily_limits (
  user_id text NOT NULL,
  date_key date NOT NULL,
  used_count integer DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  personal_used_count integer DEFAULT 0 NOT NULL,
  org_used_count integer DEFAULT 0 NOT NULL
);

CREATE TABLE nexora.contract_offers (
  id text NOT NULL,
  scope text NOT NULL,
  user_id text,
  org_id text,
  slot_no integer NOT NULL,
  slot_generation integer DEFAULT 1 NOT NULL,
  board_date date NOT NULL,
  event_id text,
  item_id text NOT NULL,
  tier text NOT NULL,
  quantity integer NOT NULL,
  base_price bigint NOT NULL,
  payout bigint NOT NULL,
  reputation_reward integer NOT NULL,
  org_reputation_reward integer DEFAULT 0 NOT NULL,
  processing_minutes integer NOT NULL,
  event_premium numeric(6,4) DEFAULT 0 NOT NULL,
  status text DEFAULT 'offered'::text NOT NULL,
  offered_at timestamp with time zone DEFAULT now() NOT NULL,
  offer_expires_at timestamp with time zone NOT NULL,
  accepted_at timestamp with time zone,
  deadline_at timestamp with time zone,
  deadline_remaining_secs integer,
  processing_started_at timestamp with time zone,
  ready_at timestamp with time zone,
  delivered_at timestamp with time zone,
  completed_at timestamp with time zone,
  claimed_by text,
  fee_paid bigint DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.contract_slot_cooldowns (
  scope text NOT NULL,
  owner_id text NOT NULL,
  slot_no integer NOT NULL,
  board_date date NOT NULL,
  cooldown_until timestamp with time zone NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.contract_slot_refresh_usage (
  scope text NOT NULL,
  owner_id text NOT NULL,
  date_key date NOT NULL,
  used_count integer DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.conversation_messages (
  id text NOT NULL,
  conversation_id text NOT NULL,
  sender_uid text NOT NULL,
  sender_name text NOT NULL,
  message_text text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.conversations (
  id text NOT NULL,
  participants text[] NOT NULL,
  participant_names jsonb DEFAULT '{}'::jsonb NOT NULL,
  participant_avatars jsonb DEFAULT '{}'::jsonb NOT NULL,
  last_message text DEFAULT ''::text NOT NULL,
  last_message_at timestamp with time zone DEFAULT now() NOT NULL,
  last_sender_uid text DEFAULT ''::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.daily_claims (
  user_id text NOT NULL,
  date_key text NOT NULL,
  amount bigint NOT NULL,
  claimed_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.diagnostics_admins (
  user_id text NOT NULL,
  role text DEFAULT 'owner'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.factories (
  id text NOT NULL,
  owner_uid text NOT NULL,
  owner_name text NOT NULL,
  name text NOT NULL,
  resource_id text NOT NULL,
  level integer DEFAULT 1 NOT NULL,
  skill_level integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  warehouse_qty bigint DEFAULT 0 NOT NULL,
  production_remainder numeric(12,6) DEFAULT 0 NOT NULL,
  operating_cost_remainder numeric(12,6) DEFAULT 0 NOT NULL,
  last_produced_at timestamp with time zone DEFAULT now() NOT NULL,
  upgrade_started_at timestamp with time zone,
  upgrade_ends_at timestamp with time zone,
  upgrade_target_level integer,
  upgrade_cost bigint,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  warehouse_level integer DEFAULT 1 NOT NULL,
  warehouse_upgrade_started_at timestamp with time zone,
  warehouse_upgrade_ends_at timestamp with time zone,
  warehouse_upgrade_target_level integer,
  warehouse_upgrade_cost bigint,
  auction_id text,
  auction_ends_at timestamp with time zone,
  auction_status text
);

CREATE TABLE nexora.global_chat_messages (
  id text NOT NULL,
  sender_uid text NOT NULL,
  sender_name text NOT NULL,
  avatar_id text DEFAULT 'strategist'::text NOT NULL,
  message_text text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.inventory (
  user_id text NOT NULL,
  item_id text NOT NULL,
  quantity bigint DEFAULT 0 NOT NULL,
  last_listing_id text,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.manufacturing_jobs (
  id text NOT NULL,
  user_id text NOT NULL,
  recipe_id text NOT NULL,
  output_item_id text NOT NULL,
  output_qty integer NOT NULL,
  xp_reward integer NOT NULL,
  started_at timestamp with time zone DEFAULT now() NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  status text DEFAULT 'running'::text NOT NULL,
  completed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  input_snapshot jsonb DEFAULT '[]'::jsonb NOT NULL,
  batch_count integer DEFAULT 1 NOT NULL,
  cancelled_at timestamp with time zone
);

CREATE TABLE nexora.market_listings (
  id text NOT NULL,
  seller_uid text NOT NULL,
  seller_name text NOT NULL,
  item_id text NOT NULL,
  quantity integer NOT NULL,
  remaining_qty integer NOT NULL,
  unit_price bigint NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.market_orders (
  id text NOT NULL,
  listing_id text NOT NULL,
  buyer_uid text NOT NULL,
  seller_uid text NOT NULL,
  item_id text NOT NULL,
  quantity integer NOT NULL,
  unit_price bigint NOT NULL,
  total_price bigint NOT NULL,
  tax_amount bigint DEFAULT 0 NOT NULL,
  tx_id text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.market_system_restock_runs (
  restock_date date NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.notification_events (
  user_id text NOT NULL,
  event_key text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.notifications (
  id text NOT NULL,
  user_id text NOT NULL,
  title text NOT NULL,
  body text DEFAULT ''::text NOT NULL,
  type text NOT NULL,
  is_read boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  event_key text
);

CREATE TABLE nexora.org_goal_contributions (
  id text NOT NULL,
  goal_id text NOT NULL,
  org_id text NOT NULL,
  user_id text NOT NULL,
  amount numeric(18,2) DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.org_weekly_goals (
  id text NOT NULL,
  org_id text NOT NULL,
  week_start date NOT NULL,
  goal_type text NOT NULL,
  difficulty text NOT NULL,
  target_amount numeric(18,2) NOT NULL,
  current_amount numeric(18,2) DEFAULT 0 NOT NULL,
  reward_reputation bigint NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  completed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.organization_chat_messages (
  id text NOT NULL,
  org_id text NOT NULL,
  sender_uid text NOT NULL,
  sender_name text NOT NULL,
  message_text text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.organization_invites (
  id text NOT NULL,
  org_id text NOT NULL,
  org_name text NOT NULL,
  org_tag text NOT NULL,
  target_uid text NOT NULL,
  inviter_uid text NOT NULL,
  inviter_name text NOT NULL,
  status text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  responded_at timestamp with time zone
);

CREATE TABLE nexora.organization_members (
  org_id text NOT NULL,
  user_id text NOT NULL,
  username text NOT NULL,
  role text NOT NULL,
  permissions jsonb DEFAULT '[]'::jsonb NOT NULL,
  joined_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.organization_requests (
  id text NOT NULL,
  org_id text NOT NULL,
  user_id text NOT NULL,
  username text NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.organization_transactions (
  id text NOT NULL,
  org_id text NOT NULL,
  user_id text NOT NULL,
  username text NOT NULL,
  type text NOT NULL,
  amount bigint NOT NULL,
  note text DEFAULT ''::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.organizations (
  id text NOT NULL,
  name text NOT NULL,
  tag text NOT NULL,
  description text DEFAULT ''::text NOT NULL,
  leader_uid text NOT NULL,
  leader_name text NOT NULL,
  treasury_balance bigint DEFAULT 0 NOT NULL,
  member_count integer DEFAULT 1 NOT NULL,
  reputation bigint DEFAULT 0 NOT NULL,
  level integer DEFAULT 1 NOT NULL,
  member_capacity integer DEFAULT 20 NOT NULL,
  join_mode text DEFAULT 'request'::text NOT NULL,
  research jsonb DEFAULT '{}'::jsonb NOT NULL,
  upgrade_started_at timestamp with time zone,
  upgrade_ends_at timestamp with time zone,
  upgrade_target_level integer,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.player_achievements (
  user_id text NOT NULL,
  achievement_id text NOT NULL,
  unlocked_at timestamp with time zone DEFAULT now() NOT NULL,
  claimed_at timestamp with time zone
);

CREATE TABLE nexora.player_missions (
  user_id text NOT NULL,
  mission_id text NOT NULL,
  category text NOT NULL,
  reward_credits bigint DEFAULT 0 NOT NULL,
  reward_xp bigint DEFAULT 0 NOT NULL,
  claimed_at timestamp with time zone DEFAULT now() NOT NULL,
  period_key text DEFAULT 'lifetime'::text NOT NULL
);

CREATE TABLE nexora.player_presence (
  user_id text NOT NULL,
  online_since timestamp with time zone DEFAULT now() NOT NULL,
  last_seen_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.player_private (
  user_id text NOT NULL,
  email text DEFAULT ''::text NOT NULL,
  language text DEFAULT 'ar'::text NOT NULL,
  notifications_enabled boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.player_profiles (
  user_id text NOT NULL,
  username text NOT NULL,
  username_lower text NOT NULL,
  avatar_id text DEFAULT 'strategist'::text NOT NULL,
  title text DEFAULT 'newcomer'::text NOT NULL,
  level integer DEFAULT 1 NOT NULL,
  xp bigint DEFAULT 0 NOT NULL,
  reputation bigint DEFAULT 0 NOT NULL,
  influence bigint DEFAULT 0 NOT NULL,
  skill_points integer DEFAULT 0 NOT NULL,
  skills jsonb DEFAULT '{}'::jsonb NOT NULL,
  stats jsonb DEFAULT '{}'::jsonb NOT NULL,
  org_id text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.player_reports (
  id text NOT NULL,
  reporter_uid text NOT NULL,
  target_uid text NOT NULL,
  reason text NOT NULL,
  status text DEFAULT 'open'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.transactions (
  id text NOT NULL,
  from_uid text,
  to_uid text,
  amount bigint NOT NULL,
  fee bigint DEFAULT 0 NOT NULL,
  net_amount bigint NOT NULL,
  type text NOT NULL,
  reference_id text DEFAULT ''::text NOT NULL,
  description text DEFAULT ''::text NOT NULL,
  status text DEFAULT 'completed'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.user_blocks (
  id text NOT NULL,
  owner_uid text NOT NULL,
  target_uid text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.usernames (
  username_lower text NOT NULL,
  uid text NOT NULL,
  username text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.wallets (
  user_id text NOT NULL,
  balance bigint DEFAULT 2500 NOT NULL,
  total_earned bigint DEFAULT 0 NOT NULL,
  total_spent bigint DEFAULT 0 NOT NULL,
  last_tx_id text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE nexora.world_events (
  id text NOT NULL,
  title_ar text NOT NULL,
  title_en text NOT NULL,
  description_ar text NOT NULL,
  description_en text NOT NULL,
  effect_type text NOT NULL,
  target_item_id text,
  affected_sectors jsonb,
  price_multiplier numeric(12,4) DEFAULT 1 NOT NULL,
  revenue_multiplier numeric(12,4),
  tax_delta numeric(12,4) DEFAULT 0 NOT NULL,
  stack_group text,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  active boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE nexora.audit_logs ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);

ALTER TABLE nexora.chat_rate_limits ADD CONSTRAINT chat_rate_limits_pkey PRIMARY KEY (id);

ALTER TABLE nexora.companies ADD CONSTRAINT companies_base_revenue_per_hour_check CHECK ((base_revenue_per_hour >= 0));

ALTER TABLE nexora.companies ADD CONSTRAINT companies_capital_check CHECK ((capital >= 0));

ALTER TABLE nexora.companies ADD CONSTRAINT companies_employees_count_check CHECK ((employees_count >= 0));

ALTER TABLE nexora.companies ADD CONSTRAINT companies_expense_per_hour_check CHECK ((expense_per_hour >= 0));

ALTER TABLE nexora.companies ADD CONSTRAINT companies_level_check CHECK ((level >= 1));

ALTER TABLE nexora.companies ADD CONSTRAINT companies_pkey PRIMARY KEY (id);

ALTER TABLE nexora.companies ADD CONSTRAINT companies_sector_check CHECK ((sector = ANY (ARRAY['trade'::text, 'manufacturing'::text, 'services'::text, 'tech'::text, 'logistics'::text])));

ALTER TABLE nexora.companies ADD CONSTRAINT companies_total_revenue_check CHECK ((total_revenue >= 0));

ALTER TABLE nexora.companies ADD CONSTRAINT companies_vault_balance_check CHECK ((vault_balance >= 0));

ALTER TABLE nexora.companies ADD CONSTRAINT companies_vault_level_check CHECK ((vault_level >= 1));

ALTER TABLE nexora.company_auction_bids ADD CONSTRAINT company_auction_bids_amount_check CHECK ((amount > 0));

ALTER TABLE nexora.company_auction_bids ADD CONSTRAINT company_auction_bids_auction_id_fkey FOREIGN KEY (auction_id) REFERENCES nexora.company_auctions(id);

ALTER TABLE nexora.company_auction_bids ADD CONSTRAINT company_auction_bids_pkey PRIMARY KEY (id);

ALTER TABLE nexora.company_auction_escrows ADD CONSTRAINT company_auction_escrows_amount_check CHECK ((amount > 0));

ALTER TABLE nexora.company_auction_escrows ADD CONSTRAINT company_auction_escrows_auction_id_fkey FOREIGN KEY (auction_id) REFERENCES nexora.company_auctions(id);

ALTER TABLE nexora.company_auction_escrows ADD CONSTRAINT company_auction_escrows_pkey PRIMARY KEY (auction_id, bidder_uid);

ALTER TABLE nexora.company_auction_escrows ADD CONSTRAINT company_auction_escrows_status_check CHECK ((status = ANY (ARRAY['reserved'::text, 'refunded'::text, 'released'::text])));

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_asset_level_check CHECK ((company_level >= 50));

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_asset_type_check CHECK ((asset_type = ANY (ARRAY['company'::text, 'factory'::text])));

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_check CHECK ((ends_at > starts_at));

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_company_id_fkey FOREIGN KEY (company_id) REFERENCES nexora.companies(id) ON DELETE SET NULL;

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_current_price_check CHECK ((current_price > 0));

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_factory_id_fkey FOREIGN KEY (factory_id) REFERENCES nexora.factories(id) ON DELETE SET NULL;

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_pkey PRIMARY KEY (id);

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_starting_price_check CHECK ((starting_price > 0));

ALTER TABLE nexora.company_auctions ADD CONSTRAINT company_auctions_status_check CHECK ((status = ANY (ARRAY['active'::text, 'sold'::text, 'unsold'::text, 'cancelled'::text])));

ALTER TABLE nexora.company_logs ADD CONSTRAINT company_logs_company_id_fkey FOREIGN KEY (company_id) REFERENCES nexora.companies(id);

ALTER TABLE nexora.company_logs ADD CONSTRAINT company_logs_pkey PRIMARY KEY (id);

ALTER TABLE nexora.contract_claims ADD CONSTRAINT contract_claims_amount_check CHECK ((amount >= 0));

ALTER TABLE nexora.contract_claims ADD CONSTRAINT contract_claims_pkey PRIMARY KEY (user_id, contract_id);

ALTER TABLE nexora.contract_config ADD CONSTRAINT contract_config_pkey PRIMARY KEY (config_key);

ALTER TABLE nexora.contract_daily_limits ADD CONSTRAINT contract_daily_limits_pkey PRIMARY KEY (user_id, date_key);

ALTER TABLE nexora.contract_daily_limits ADD CONSTRAINT contract_daily_limits_used_count_check CHECK ((used_count >= 0));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_base_price_check CHECK ((base_price > 0));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_check CHECK ((((scope = 'personal'::text) AND (user_id IS NOT NULL) AND (org_id IS NULL)) OR ((scope = 'organization'::text) AND (org_id IS NOT NULL) AND (user_id IS NULL))));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_org_reputation_reward_check CHECK ((org_reputation_reward >= 0));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_payout_check CHECK (((payout > 0) AND (payout <= 2500)));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_pkey PRIMARY KEY (id);

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_processing_minutes_check CHECK (((processing_minutes >= 10) AND (processing_minutes <= 120)));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_quantity_check CHECK ((quantity > 0));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_reputation_reward_check CHECK ((reputation_reward >= 0));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_scope_check CHECK ((scope = ANY (ARRAY['personal'::text, 'organization'::text])));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_status_check CHECK ((status = ANY (ARRAY['offered'::text, 'accepted'::text, 'processing'::text, 'ready'::text, 'completed'::text, 'expired'::text, 'abandoned'::text])));

ALTER TABLE nexora.contract_offers ADD CONSTRAINT contract_offers_tier_check CHECK ((tier = ANY (ARRAY['common'::text, 'uncommon'::text, 'rare'::text, 'epic'::text])));

ALTER TABLE nexora.contract_slot_cooldowns ADD CONSTRAINT contract_slot_cooldowns_pkey PRIMARY KEY (scope, owner_id, slot_no, board_date);

ALTER TABLE nexora.contract_slot_cooldowns ADD CONSTRAINT contract_slot_cooldowns_scope_check CHECK ((scope = ANY (ARRAY['personal'::text, 'organization'::text])));

ALTER TABLE nexora.contract_slot_cooldowns ADD CONSTRAINT contract_slot_cooldowns_slot_no_check CHECK ((slot_no > 0));

ALTER TABLE nexora.contract_slot_refresh_usage ADD CONSTRAINT contract_slot_refresh_usage_pkey PRIMARY KEY (scope, owner_id, date_key);

ALTER TABLE nexora.contract_slot_refresh_usage ADD CONSTRAINT contract_slot_refresh_usage_scope_check CHECK ((scope = ANY (ARRAY['personal'::text, 'organization'::text])));

ALTER TABLE nexora.contract_slot_refresh_usage ADD CONSTRAINT contract_slot_refresh_usage_used_count_check CHECK ((used_count >= 0));

ALTER TABLE nexora.conversation_messages ADD CONSTRAINT conversation_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES nexora.conversations(id) ON DELETE CASCADE;

ALTER TABLE nexora.conversation_messages ADD CONSTRAINT conversation_messages_message_text_check CHECK (((length(message_text) >= 1) AND (length(message_text) <= 1000)));

ALTER TABLE nexora.conversation_messages ADD CONSTRAINT conversation_messages_pkey PRIMARY KEY (id);

ALTER TABLE nexora.conversations ADD CONSTRAINT conversations_participants_check CHECK ((cardinality(participants) = 2));

ALTER TABLE nexora.conversations ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);

ALTER TABLE nexora.daily_claims ADD CONSTRAINT daily_claims_amount_check CHECK ((amount >= 0));

ALTER TABLE nexora.daily_claims ADD CONSTRAINT daily_claims_pkey PRIMARY KEY (user_id, date_key);

ALTER TABLE nexora.diagnostics_admins ADD CONSTRAINT diagnostics_admins_pkey PRIMARY KEY (user_id);

ALTER TABLE nexora.diagnostics_admins ADD CONSTRAINT diagnostics_admins_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text])));

ALTER TABLE nexora.factories ADD CONSTRAINT factories_level_check CHECK (((level >= 1) AND (level <= 100)));

ALTER TABLE nexora.factories ADD CONSTRAINT factories_name_check CHECK (((char_length(name) >= 2) AND (char_length(name) <= 48)));

ALTER TABLE nexora.factories ADD CONSTRAINT factories_operating_cost_remainder_check CHECK (((operating_cost_remainder >= (0)::numeric) AND (operating_cost_remainder < (1)::numeric)));

ALTER TABLE nexora.factories ADD CONSTRAINT factories_pkey PRIMARY KEY (id);

ALTER TABLE nexora.factories ADD CONSTRAINT factories_production_remainder_check CHECK (((production_remainder >= (0)::numeric) AND (production_remainder < (1)::numeric)));

ALTER TABLE nexora.factories ADD CONSTRAINT factories_resource_id_check CHECK ((resource_id = ANY (ARRAY['copper_wire'::text, 'silicon_ore'::text, 'energy_cells'::text, 'crude_alloy'::text, 'carbon_fiber'::text, 'rare_minerals'::text, 'titanium_ore'::text, 'polymer_resin'::text, 'biotech_gel'::text, 'quantum_dust'::text])));

ALTER TABLE nexora.factories ADD CONSTRAINT factories_skill_level_check CHECK (((skill_level >= 0) AND (skill_level <= 10)));

ALTER TABLE nexora.factories ADD CONSTRAINT factories_warehouse_level_check CHECK (((warehouse_level >= 1) AND (warehouse_level <= 5)));

ALTER TABLE nexora.factories ADD CONSTRAINT factories_warehouse_qty_check CHECK ((warehouse_qty >= 0));

ALTER TABLE nexora.global_chat_messages ADD CONSTRAINT global_chat_messages_message_text_check CHECK (((length(message_text) >= 1) AND (length(message_text) <= 280)));

ALTER TABLE nexora.global_chat_messages ADD CONSTRAINT global_chat_messages_pkey PRIMARY KEY (id);

ALTER TABLE nexora.inventory ADD CONSTRAINT inventory_pkey PRIMARY KEY (user_id, item_id);

ALTER TABLE nexora.inventory ADD CONSTRAINT inventory_quantity_check CHECK ((quantity >= 0));

ALTER TABLE nexora.manufacturing_jobs ADD CONSTRAINT manufacturing_jobs_output_qty_check CHECK ((output_qty > 0));

ALTER TABLE nexora.manufacturing_jobs ADD CONSTRAINT manufacturing_jobs_pkey PRIMARY KEY (id);

ALTER TABLE nexora.manufacturing_jobs ADD CONSTRAINT manufacturing_jobs_status_check CHECK ((status = ANY (ARRAY['running'::text, 'completed'::text, 'cancelled'::text])));

ALTER TABLE nexora.manufacturing_jobs ADD CONSTRAINT manufacturing_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES nexora.player_profiles(user_id) ON DELETE CASCADE;

ALTER TABLE nexora.manufacturing_jobs ADD CONSTRAINT manufacturing_jobs_xp_reward_check CHECK ((xp_reward >= 0));

ALTER TABLE nexora.market_listings ADD CONSTRAINT market_listings_check CHECK (((remaining_qty >= 0) AND (remaining_qty <= quantity)));

ALTER TABLE nexora.market_listings ADD CONSTRAINT market_listings_pkey PRIMARY KEY (id);

ALTER TABLE nexora.market_listings ADD CONSTRAINT market_listings_quantity_check CHECK ((quantity > 0));

ALTER TABLE nexora.market_listings ADD CONSTRAINT market_listings_status_check CHECK ((status = ANY (ARRAY['active'::text, 'sold'::text, 'cancelled'::text])));

ALTER TABLE nexora.market_listings ADD CONSTRAINT market_listings_unit_price_check CHECK ((unit_price > 0));

ALTER TABLE nexora.market_orders ADD CONSTRAINT market_orders_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES nexora.market_listings(id);

ALTER TABLE nexora.market_orders ADD CONSTRAINT market_orders_pkey PRIMARY KEY (id);

ALTER TABLE nexora.market_orders ADD CONSTRAINT market_orders_quantity_check CHECK ((quantity > 0));

ALTER TABLE nexora.market_orders ADD CONSTRAINT market_orders_tax_amount_check CHECK ((tax_amount >= 0));

ALTER TABLE nexora.market_orders ADD CONSTRAINT market_orders_total_price_check CHECK ((total_price > 0));

ALTER TABLE nexora.market_orders ADD CONSTRAINT market_orders_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES nexora.transactions(id);

ALTER TABLE nexora.market_orders ADD CONSTRAINT market_orders_unit_price_check CHECK ((unit_price > 0));

ALTER TABLE nexora.market_system_restock_runs ADD CONSTRAINT market_system_restock_runs_pkey PRIMARY KEY (restock_date);

ALTER TABLE nexora.notification_events ADD CONSTRAINT notification_events_pkey PRIMARY KEY (user_id, event_key);

ALTER TABLE nexora.notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

ALTER TABLE nexora.notifications ADD CONSTRAINT notifications_type_check CHECK ((type = ANY (ARRAY['economy'::text, 'market'::text, 'org'::text, 'mission'::text, 'system'::text])));

ALTER TABLE nexora.org_goal_contributions ADD CONSTRAINT org_goal_contributions_amount_check CHECK ((amount >= (0)::numeric));

ALTER TABLE nexora.org_goal_contributions ADD CONSTRAINT org_goal_contributions_goal_id_fkey FOREIGN KEY (goal_id) REFERENCES nexora.org_weekly_goals(id) ON DELETE CASCADE;

ALTER TABLE nexora.org_goal_contributions ADD CONSTRAINT org_goal_contributions_goal_id_user_id_key UNIQUE (goal_id, user_id);

ALTER TABLE nexora.org_goal_contributions ADD CONSTRAINT org_goal_contributions_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id) ON DELETE CASCADE;

ALTER TABLE nexora.org_goal_contributions ADD CONSTRAINT org_goal_contributions_pkey PRIMARY KEY (id);

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_current_amount_check CHECK ((current_amount >= (0)::numeric));

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_difficulty_check CHECK ((difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text])));

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_goal_type_check CHECK ((goal_type = ANY (ARRAY['produce_units'::text, 'trade_volume'::text, 'contracts_completed'::text, 'treasury_donations'::text, 'personal_contracts_completed'::text, 'org_contracts_completed'::text, 'company_revenue'::text, 'factory_upgrades'::text, 'company_upgrades'::text, 'companies_founded'::text, 'factories_founded'::text])));

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id) ON DELETE CASCADE;

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_org_id_week_start_goal_type_key UNIQUE (org_id, week_start, goal_type);

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_pkey PRIMARY KEY (id);

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_reward_reputation_check CHECK ((reward_reputation = ANY (ARRAY[(50)::bigint, (100)::bigint, (200)::bigint])));

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_status_check CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text])));

ALTER TABLE nexora.org_weekly_goals ADD CONSTRAINT org_weekly_goals_target_amount_check CHECK ((target_amount > (0)::numeric));

ALTER TABLE nexora.organization_chat_messages ADD CONSTRAINT organization_chat_messages_message_text_check CHECK (((length(message_text) >= 1) AND (length(message_text) <= 280)));

ALTER TABLE nexora.organization_chat_messages ADD CONSTRAINT organization_chat_messages_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id) ON DELETE CASCADE;

ALTER TABLE nexora.organization_chat_messages ADD CONSTRAINT organization_chat_messages_pkey PRIMARY KEY (id);

ALTER TABLE nexora.organization_invites ADD CONSTRAINT organization_invites_pkey PRIMARY KEY (id);

ALTER TABLE nexora.organization_invites ADD CONSTRAINT organization_invites_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'rejected'::text, 'cancelled'::text])));

ALTER TABLE nexora.organization_members ADD CONSTRAINT organization_members_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id) ON DELETE CASCADE;

ALTER TABLE nexora.organization_members ADD CONSTRAINT organization_members_pkey PRIMARY KEY (org_id, user_id);

ALTER TABLE nexora.organization_members ADD CONSTRAINT organization_members_role_check CHECK ((role = ANY (ARRAY['leader'::text, 'deputy'::text, 'officer'::text, 'member'::text])));

ALTER TABLE nexora.organization_requests ADD CONSTRAINT organization_requests_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id) ON DELETE CASCADE;

ALTER TABLE nexora.organization_requests ADD CONSTRAINT organization_requests_pkey PRIMARY KEY (id);

ALTER TABLE nexora.organization_requests ADD CONSTRAINT organization_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])));

ALTER TABLE nexora.organization_transactions ADD CONSTRAINT organization_transactions_amount_check CHECK ((amount >= 0));

ALTER TABLE nexora.organization_transactions ADD CONSTRAINT organization_transactions_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id);

ALTER TABLE nexora.organization_transactions ADD CONSTRAINT organization_transactions_pkey PRIMARY KEY (id);

ALTER TABLE nexora.organization_transactions ADD CONSTRAINT organization_transactions_type_check CHECK ((type = ANY (ARRAY['deposit'::text, 'withdraw'::text, 'upgrade'::text])));

ALTER TABLE nexora.organizations ADD CONSTRAINT organizations_level_check CHECK ((level >= 1));

ALTER TABLE nexora.organizations ADD CONSTRAINT organizations_member_capacity_check CHECK ((member_capacity >= 1));

ALTER TABLE nexora.organizations ADD CONSTRAINT organizations_member_count_check CHECK ((member_count >= 0));

ALTER TABLE nexora.organizations ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);

ALTER TABLE nexora.organizations ADD CONSTRAINT organizations_reputation_check CHECK ((reputation >= 0));

ALTER TABLE nexora.organizations ADD CONSTRAINT organizations_tag_key UNIQUE (tag);

ALTER TABLE nexora.organizations ADD CONSTRAINT organizations_treasury_balance_check CHECK ((treasury_balance >= 0));

ALTER TABLE nexora.player_achievements ADD CONSTRAINT player_achievements_pkey PRIMARY KEY (user_id, achievement_id);

ALTER TABLE nexora.player_missions ADD CONSTRAINT player_missions_pkey PRIMARY KEY (user_id, mission_id, period_key);

ALTER TABLE nexora.player_missions ADD CONSTRAINT player_missions_reward_credits_check CHECK ((reward_credits >= 0));

ALTER TABLE nexora.player_missions ADD CONSTRAINT player_missions_reward_xp_check CHECK ((reward_xp >= 0));

ALTER TABLE nexora.player_presence ADD CONSTRAINT player_presence_pkey PRIMARY KEY (user_id);

ALTER TABLE nexora.player_private ADD CONSTRAINT player_private_language_check CHECK ((language = ANY (ARRAY['ar'::text, 'en'::text])));

ALTER TABLE nexora.player_private ADD CONSTRAINT player_private_pkey PRIMARY KEY (user_id);

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_influence_check CHECK ((influence >= 0));

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_level_check CHECK ((level >= 1));

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_org_id_fkey FOREIGN KEY (org_id) REFERENCES nexora.organizations(id);

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_pkey PRIMARY KEY (user_id);

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_reputation_check CHECK ((reputation >= 0));

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_skill_points_check CHECK ((skill_points >= 0));

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_username_check CHECK (((char_length(username) >= 3) AND (char_length(username) <= 24)));

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_username_lower_key UNIQUE (username_lower);

ALTER TABLE nexora.player_profiles ADD CONSTRAINT player_profiles_xp_check CHECK ((xp >= 0));

ALTER TABLE nexora.player_reports ADD CONSTRAINT player_reports_check CHECK ((reporter_uid <> target_uid));

ALTER TABLE nexora.player_reports ADD CONSTRAINT player_reports_pkey PRIMARY KEY (id);

ALTER TABLE nexora.player_reports ADD CONSTRAINT player_reports_reason_check CHECK ((reason = ANY (ARRAY['harassment'::text, 'spam'::text, 'inappropriate'::text, 'impersonation'::text, 'other'::text])));

ALTER TABLE nexora.player_reports ADD CONSTRAINT player_reports_status_check CHECK ((status = ANY (ARRAY['open'::text, 'reviewing'::text, 'closed'::text])));

ALTER TABLE nexora.transactions ADD CONSTRAINT transactions_amount_check CHECK ((amount >= 0));

ALTER TABLE nexora.transactions ADD CONSTRAINT transactions_fee_check CHECK ((fee >= 0));

ALTER TABLE nexora.transactions ADD CONSTRAINT transactions_net_amount_check CHECK ((net_amount >= 0));

ALTER TABLE nexora.transactions ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);

ALTER TABLE nexora.transactions ADD CONSTRAINT transactions_status_check CHECK ((status = 'completed'::text));

ALTER TABLE nexora.user_blocks ADD CONSTRAINT user_blocks_check CHECK ((owner_uid <> target_uid));

ALTER TABLE nexora.user_blocks ADD CONSTRAINT user_blocks_owner_uid_target_uid_key UNIQUE (owner_uid, target_uid);

ALTER TABLE nexora.user_blocks ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (id);

ALTER TABLE nexora.usernames ADD CONSTRAINT usernames_pkey PRIMARY KEY (username_lower);

ALTER TABLE nexora.usernames ADD CONSTRAINT usernames_user_id_key UNIQUE (uid);

ALTER TABLE nexora.wallets ADD CONSTRAINT wallets_balance_check CHECK ((balance >= 0));

ALTER TABLE nexora.wallets ADD CONSTRAINT wallets_pkey PRIMARY KEY (user_id);

ALTER TABLE nexora.wallets ADD CONSTRAINT wallets_total_earned_check CHECK ((total_earned >= 0));

ALTER TABLE nexora.wallets ADD CONSTRAINT wallets_total_spent_check CHECK ((total_spent >= 0));

ALTER TABLE nexora.world_events ADD CONSTRAINT world_events_pkey PRIMARY KEY (id);

ALTER TABLE nexora.world_events ADD CONSTRAINT world_events_price_multiplier_check CHECK ((price_multiplier >= (0)::numeric));

CREATE INDEX companies_owner_active_idx ON nexora.companies USING btree (owner_uid, is_deleted);

CREATE INDEX companies_owner_uid_idx ON nexora.companies USING btree (owner_uid);

CREATE INDEX company_auction_bids_auction_idx ON nexora.company_auction_bids USING btree (auction_id, created_at DESC);

CREATE INDEX company_auction_escrows_bidder_idx ON nexora.company_auction_escrows USING btree (bidder_uid, status);

CREATE INDEX company_auctions_active_ends_idx ON nexora.company_auctions USING btree (status, ends_at);

CREATE UNIQUE INDEX company_auctions_factory_active_unique ON nexora.company_auctions USING btree (factory_id) WHERE ((factory_id IS NOT NULL) AND (status = 'active'::text));

CREATE INDEX company_auctions_seller_idx ON nexora.company_auctions USING btree (seller_uid, created_at DESC);

CREATE INDEX company_logs_company_id_idx ON nexora.company_logs USING btree (company_id);

CREATE INDEX company_logs_owner_uid_created_at_idx ON nexora.company_logs USING btree (owner_uid, created_at DESC);

CREATE INDEX contract_offers_expiry_idx ON nexora.contract_offers USING btree (status, deadline_at, offer_expires_at);

CREATE INDEX contract_offers_org_board_idx ON nexora.contract_offers USING btree (org_id, board_date, status, slot_no);

CREATE UNIQUE INDEX contract_offers_org_slot_generation_uq ON nexora.contract_offers USING btree (org_id, board_date, slot_no, slot_generation) WHERE (scope = 'organization'::text);

CREATE INDEX contract_offers_personal_board_idx ON nexora.contract_offers USING btree (user_id, board_date, status, slot_no);

CREATE UNIQUE INDEX contract_offers_personal_slot_generation_uq ON nexora.contract_offers USING btree (user_id, board_date, slot_no, slot_generation) WHERE (scope = 'personal'::text);

CREATE UNIQUE INDEX contract_one_active_org_per_member_uq ON nexora.contract_offers USING btree (claimed_by) WHERE ((scope = 'organization'::text) AND (status = ANY (ARRAY['accepted'::text, 'processing'::text, 'ready'::text])) AND (claimed_by IS NOT NULL));

CREATE INDEX contract_slot_cooldowns_until_idx ON nexora.contract_slot_cooldowns USING btree (cooldown_until);

CREATE INDEX conversation_messages_order_idx ON nexora.conversation_messages USING btree (conversation_id, created_at DESC);

CREATE INDEX conversations_last_message_at_idx ON nexora.conversations USING btree (last_message_at DESC);

CREATE INDEX conversations_participants_gin_idx ON nexora.conversations USING gin (participants);

CREATE UNIQUE INDEX factories_auction_id_unique ON nexora.factories USING btree (auction_id) WHERE (auction_id IS NOT NULL);

CREATE INDEX factories_owner_created_idx ON nexora.factories USING btree (owner_uid, created_at);

CREATE INDEX global_chat_created_idx ON nexora.global_chat_messages USING btree (created_at DESC);

CREATE INDEX inventory_user_id_idx ON nexora.inventory USING btree (user_id);

CREATE UNIQUE INDEX manufacturing_jobs_one_running_per_player ON nexora.manufacturing_jobs USING btree (user_id) WHERE (status = 'running'::text);

CREATE INDEX manufacturing_jobs_user_created_idx ON nexora.manufacturing_jobs USING btree (user_id, created_at DESC);

CREATE INDEX market_listings_seller_uid_idx ON nexora.market_listings USING btree (seller_uid);

CREATE INDEX market_listings_status_created_at_idx ON nexora.market_listings USING btree (status, created_at DESC);

CREATE INDEX market_orders_buyer_uid_created_at_idx ON nexora.market_orders USING btree (buyer_uid, created_at DESC);

CREATE INDEX market_orders_listing_id_idx ON nexora.market_orders USING btree (listing_id);

CREATE INDEX market_orders_tx_id_idx ON nexora.market_orders USING btree (tx_id);

CREATE INDEX notifications_user_id_created_at_idx ON nexora.notifications USING btree (user_id, created_at DESC);

CREATE INDEX org_goal_contributions_org_id_idx ON nexora.org_goal_contributions USING btree (org_id);

CREATE INDEX org_goal_contributions_ranking_idx ON nexora.org_goal_contributions USING btree (goal_id, amount DESC, updated_at);

CREATE INDEX org_invites_target_status_idx ON nexora.organization_invites USING btree (target_uid, status);

CREATE INDEX org_weekly_goals_week_idx ON nexora.org_weekly_goals USING btree (org_id, week_start, status);

CREATE INDEX organization_chat_messages_order_idx ON nexora.organization_chat_messages USING btree (org_id, created_at DESC);

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

CREATE OR REPLACE FUNCTION nexora.abandon_dynamic_contract(p_uid text, p_contract_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_today date:=(now() at time zone 'UTC')::date;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' and v_contract.claimed_by<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.status<>'accepted' then raise exception 'CONTRACT_CANNOT_BE_ABANDONED'; end if;
  if v_contract.deadline_at<=now() then
    update nexora.contract_offers set status='expired',updated_at=now() where id=p_contract_id;
    if v_contract.scope='personal' and v_contract.board_date=v_today and
      (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
        and e.active=true and e.starts_at<=now() and e.ends_at>now())) then
      perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
        v_contract.slot_no,v_today,v_contract.item_id,v_contract.tier,v_contract.event_id);
    end if;
    return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED');
  end if;
  update nexora.contract_offers set status='abandoned',completed_at=now(),updated_at=now() where id=p_contract_id;
  if v_contract.scope='personal' and v_contract.board_date=v_today and
    not exists(select 1 from nexora.contract_offers replacement
      where replacement.scope=v_contract.scope and replacement.board_date=v_today
        and replacement.slot_no=v_contract.slot_no and replacement.status='offered'
        and ((v_contract.scope='personal' and replacement.user_id=v_contract.user_id)
          or (v_contract.scope='organization' and replacement.org_id=v_contract.org_id)))
    and (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
      and e.active=true and e.starts_at<=now() and e.ends_at>now())) then
    perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
      v_contract.slot_no,v_today,v_contract.item_id,v_contract.tier,v_contract.event_id);
  end if;
  return jsonb_build_object('ok',true);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.accept_dynamic_contract(p_uid text, p_contract_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_active integer;
  v_progression jsonb;
  v_tier_rules jsonb;
  v_daily_limit integer;
  v_active_limit integer;
  v_join_hours integer;
  v_min_hours integer;
  v_max_hours integer;
  v_deadline_hours integer;
  v_today date:=(now() at time zone 'UTC')::date;
  v_used integer;
  v_now timestamptz:=now();
  v_hours integer;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select config_value into v_progression from nexora.contract_config where config_key='progression';
  v_daily_limit:=coalesce((v_progression->>'daily_claim_limit')::integer,5);
  v_active_limit:=coalesce((v_progression->>'active_personal_limit')::integer,3);
  v_join_hours:=coalesce((v_progression->>'org_join_hours')::integer,8);
  select config_value into v_tier_rules from nexora.contract_config where config_key='tier_rules';
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.status<>'offered' then raise exception 'CONTRACT_NOT_AVAILABLE'; end if;
  if v_contract.offer_expires_at<=v_now then
    update nexora.contract_offers set status='expired',updated_at=v_now where id=p_contract_id;
    if v_contract.board_date=(v_now at time zone 'UTC')::date and
      (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
        and e.active=true and e.starts_at<=v_now and e.ends_at>v_now)) then
      perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
        v_contract.slot_no,(v_now at time zone 'UTC')::date,v_contract.item_id,v_contract.tier,v_contract.event_id);
    end if;
    return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED');
  end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' then
    if v_profile.org_id is distinct from v_contract.org_id then raise exception 'UNAUTHORIZED'; end if;
    select extract(epoch from (v_now-joined_at))/3600 into v_hours
      from nexora.organization_members where org_id=v_contract.org_id and user_id=p_uid;
    if not found then raise exception 'UNAUTHORIZED'; end if;
    if v_hours<v_join_hours then raise exception 'ORG_MEMBERSHIP_TOO_NEW'; end if;
    if v_contract.claimed_by is not null then raise exception 'CONTRACT_ALREADY_CLAIMED'; end if;
    select count(*) into v_active from nexora.contract_offers
      where scope='organization' and claimed_by=p_uid and status in ('accepted','processing','ready');
    if v_active>=3 then raise exception 'ORG_ACTIVE_CONTRACT_LIMIT'; end if;
  else
    select count(*) into v_active from nexora.contract_offers
      where scope='personal' and user_id=p_uid and status in ('accepted','processing','ready');
    if v_active>=v_active_limit then raise exception 'ACTIVE_CONTRACT_LIMIT'; end if;
  end if;
  insert into nexora.contract_daily_limits(user_id,date_key,used_count) values(p_uid,v_today,0)
    on conflict(user_id,date_key) do nothing;
  select case when v_contract.scope='personal' then personal_used_count else org_used_count end
    into v_used from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today for update;
  if v_used>=v_daily_limit then raise exception 'DAILY_CONTRACT_LIMIT_REACHED'; end if;
  update nexora.contract_daily_limits
    set used_count=used_count+1,
      personal_used_count=personal_used_count+case when v_contract.scope='personal' then 1 else 0 end,
      org_used_count=org_used_count+case when v_contract.scope='organization' then 1 else 0 end,
      updated_at=v_now
    where user_id=p_uid and date_key=v_today;
  v_min_hours:=coalesce((v_tier_rules->v_contract.tier->>'min_hours')::integer,3);
  v_max_hours:=coalesce((v_tier_rules->v_contract.tier->>'max_hours')::integer,v_min_hours);
  v_deadline_hours:=v_min_hours+floor(random()*greatest(1,v_max_hours-v_min_hours+1))::integer;
  update nexora.contract_offers set status='accepted',accepted_at=v_now,
    deadline_at=v_now+make_interval(hours=>v_deadline_hours),
    claimed_by=case when v_contract.scope='organization' then p_uid else null end,
    updated_at=v_now where id=p_contract_id;
  if v_contract.scope='personal' and v_contract.board_date=v_today and
    (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
      and e.active=true and e.starts_at<=v_now and e.ends_at>v_now)) then
    perform nexora.generate_dynamic_contract('personal',p_uid,null,v_contract.slot_no,v_today,
      v_contract.item_id,v_contract.tier,v_contract.event_id);
  end if;
  return jsonb_build_object('ok',true,'deadline_at',(
    select deadline_at from nexora.contract_offers where id=p_contract_id),'daily_used',v_used+1);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.apply_company_auction_sale_fee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_fee bigint; v_tx text:='tx_'||gen_random_uuid()::text;
begin
  if old.status='active' and new.status='sold' and new.highest_bidder_uid is not null then
    v_fee:=round(new.current_price*0.04)::bigint;
    if v_fee>0 then
      update nexora.wallets set balance=balance-v_fee,total_spent=total_spent+v_fee,last_tx_id=v_tx,updated_at=now() where user_id=new.seller_uid;
      if not found then raise exception 'SELLER_WALLET_NOT_FOUND'; end if;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
        values(v_tx,new.seller_uid,'SYSTEM',v_fee,0,v_fee,'auction_fee',new.id,'4% company/factory auction sale fee','completed');
    end if;
  end if;
  return new;
end;
$function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.buy_market_listing(p_uid text, p_listing_id text, p_qty integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_listing nexora.market_listings%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_seller nexora.wallets%rowtype;
  v_inventory nexora.inventory%rowtype;
  v_total bigint; v_fee bigint; v_net bigint; v_tax numeric; v_event_delta numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text; v_order text; v_stats jsonb; v_expected_seller text;
begin
  if p_qty is null or p_qty < 1 then raise exception 'INVALID_QUANTITY'; end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_listing from nexora.market_listings where id=p_listing_id;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.seller_uid=p_uid then raise exception 'CANNOT_BUY_OWN_LISTING'; end if;
  v_expected_seller:=v_listing.seller_uid;
  if v_expected_seller<>'SYSTEM' then
    perform 1 from nexora.wallets where user_id in (p_uid,v_expected_seller) order by user_id for update;
  else
    perform 1 from nexora.wallets where user_id=p_uid for update;
  end if;
  select * into v_listing from nexora.market_listings where id=p_listing_id for update;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.seller_uid is distinct from v_expected_seller then raise exception 'LISTING_CHANGED_RETRY'; end if;
  if v_listing.status <> 'active' or v_listing.remaining_qty < p_qty then raise exception 'INSUFFICIENT_LISTING_QTY'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_total := v_listing.unit_price * p_qty;
  if v_wallet.balance < v_total then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_event_delta := coalesce((select sum(tax_delta) from nexora.world_events where active=true and starts_at <= now() and ends_at > now()),0);
  v_tax := greatest(0.01,least(0.12,0.05 - coalesce((v_profile.skills->>'trade')::numeric,0)*0.004 + v_event_delta));
  v_fee := round(v_total * v_tax)::bigint;
  v_net := v_total - v_fee;
  if v_listing.seller_uid <> 'SYSTEM' then
    select * into v_seller from nexora.wallets where user_id=v_listing.seller_uid;
    if not found then raise exception 'SELLER_ACCOUNT_NOT_FOUND'; end if;
  end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=v_listing.item_id for update;
  update nexora.wallets set balance=balance-v_total,total_spent=total_spent+v_total,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  if v_listing.seller_uid <> 'SYSTEM' then
    update nexora.wallets set balance=balance+v_net,total_earned=total_earned+v_net,last_tx_id=v_tx,updated_at=now() where user_id=v_listing.seller_uid;
  end if;
  update nexora.market_listings set remaining_qty=remaining_qty-p_qty,status=case when remaining_qty-p_qty=0 then 'sold' else 'active' end,updated_at=now()
    where id=p_listing_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,v_listing.seller_uid,v_total,v_fee,v_net,'market_buy',p_listing_id,'Market buy: '||p_qty::text||'x '||v_listing.item_id,'completed');
  v_order:='ord_'||v_tx;
  insert into nexora.market_orders(id,listing_id,buyer_uid,seller_uid,item_id,quantity,unit_price,total_price,tax_amount,tx_id)
    values(v_order,p_listing_id,p_uid,v_listing.seller_uid,v_listing.item_id,p_qty,v_listing.unit_price,v_total,v_fee,v_tx);
  if v_inventory.user_id is null then
    insert into nexora.inventory(user_id,item_id,quantity) values(p_uid,v_listing.item_id,p_qty);
  else
    update nexora.inventory set quantity=quantity+p_qty,updated_at=now() where user_id=p_uid and item_id=v_listing.item_id;
  end if;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{tradesCount}',to_jsonb(coalesce((v_profile.stats->>'tradesCount')::integer,0)+1),true);
  update nexora.player_profiles set stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'order_id',v_order,'transaction_id',v_tx,'total',v_total,'tax',v_fee);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.cancel_manufacturing_job(p_uid text, p_job_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_job nexora.manufacturing_jobs%rowtype;
  v_item record;
begin
  select * into v_job
  from nexora.manufacturing_jobs
  where id = p_job_id and user_id = p_uid
  for update;
  if not found then raise exception 'MANUFACTURING_JOB_NOT_FOUND'; end if;

  if v_job.status = 'cancelled' then
    return jsonb_build_object('ok', true, 'already_cancelled', true, 'returned_items', v_job.input_snapshot);
  end if;
  if v_job.status = 'completed' then
    raise exception 'MANUFACTURING_JOB_ALREADY_COMPLETED';
  end if;
  if v_job.ends_at <= now() then
    raise exception 'MANUFACTURING_JOB_ALREADY_FINISHED';
  end if;
  if jsonb_typeof(v_job.input_snapshot) <> 'array' or jsonb_array_length(v_job.input_snapshot) = 0 then
    raise exception 'MANUFACTURING_REFUND_SNAPSHOT_MISSING';
  end if;

  -- A refund must never be blocked by newly filled inventory slots: restoring consumed
  -- inputs is a reversal of the reservation, not a new purchase.
  perform set_config('nexora.allow_inventory_refund', 'true', true);
  for v_item in
    select value->>'itemId' as item_id, sum((value->>'qty')::integer)::integer as qty
    from jsonb_array_elements(v_job.input_snapshot)
    group by value->>'itemId'
    order by value->>'itemId'
  loop
    insert into nexora.inventory(user_id, item_id, quantity)
    values (p_uid, v_item.item_id, v_item.qty * v_job.batch_count)
    on conflict (user_id, item_id)
    do update set quantity = nexora.inventory.quantity + excluded.quantity, updated_at = now();
  end loop;
  perform set_config('nexora.allow_inventory_refund', 'false', true);

  update nexora.manufacturing_jobs
  set status = 'cancelled', cancelled_at = now()
  where id = p_job_id;

  return jsonb_build_object(
    'ok', true,
    'already_cancelled', false,
    'returned_batches', v_job.batch_count,
    'returned_items', v_job.input_snapshot
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.cancel_market_listing(p_uid text, p_listing_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_listing nexora.market_listings%rowtype;
  v_previous_refund_setting text;
begin
  select * into v_listing from nexora.market_listings where id=p_listing_id for update;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.seller_uid<>p_uid or v_listing.status<>'active' then raise exception 'CANNOT_CANCEL_LISTING'; end if;
  update nexora.market_listings set remaining_qty=0,status='cancelled',updated_at=now() where id=p_listing_id;
  v_previous_refund_setting:=coalesce(current_setting('nexora.allow_inventory_refund',true),'false');
  perform set_config('nexora.allow_inventory_refund','true',true);
  insert into nexora.inventory(user_id,item_id,quantity,last_listing_id)
  values(p_uid,v_listing.item_id,v_listing.remaining_qty,p_listing_id)
  on conflict(user_id,item_id) do update
    set quantity=nexora.inventory.quantity+excluded.quantity,last_listing_id=excluded.last_listing_id,updated_at=now();
  perform set_config('nexora.allow_inventory_refund',v_previous_refund_setting,true);
  return jsonb_build_object('ok',true,'returned_qty',v_listing.remaining_qty);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.claim_achievement_reward(p_uid text, p_achievement_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_achievement nexora.player_achievements%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_reward bigint;
  v_tx text:='tx_'||gen_random_uuid()::text;
begin
  if p_achievement_id not in (
    'nova_whale_i','nova_whale_ii','nova_whale_iii','nova_whale_iv',
    'nova_market_i','nova_market_ii','nova_market_iii','nova_market_iv',
    'nova_industry_i','nova_industry_ii','nova_industry_iii','nova_industry_iv',
    'nova_enterprise_i','nova_enterprise_ii','nova_enterprise_iii','nova_enterprise_iv'
  ) then raise exception 'INVALID_ACHIEVEMENT'; end if;

  select * into v_achievement
  from nexora.player_achievements
  where user_id=p_uid and achievement_id=p_achievement_id
  for update;
  if not found then raise exception 'ACHIEVEMENT_NOT_UNLOCKED'; end if;
  if v_achievement.claimed_at is not null then raise exception 'ACHIEVEMENT_ALREADY_CLAIMED'; end if;

  select reward into v_reward from (values
    ('nova_whale_i',2000::bigint),('nova_whale_ii',8000::bigint),('nova_whale_iii',25000::bigint),('nova_whale_iv',75000::bigint),
    ('nova_market_i',1500::bigint),('nova_market_ii',6000::bigint),('nova_market_iii',25000::bigint),('nova_market_iv',75000::bigint),
    ('nova_industry_i',2000::bigint),('nova_industry_ii',8000::bigint),('nova_industry_iii',30000::bigint),('nova_industry_iv',90000::bigint),
    ('nova_enterprise_i',5000::bigint),('nova_enterprise_ii',15000::bigint),('nova_enterprise_iii',50000::bigint),('nova_enterprise_iv',150000::bigint)
  ) as rewards(id,reward) where id=p_achievement_id;

  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  update nexora.wallets
  set balance=balance+v_reward,total_earned=total_earned+v_reward,last_tx_id=v_tx,updated_at=now()
  where user_id=p_uid;

  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_reward,0,v_reward,'mission_reward',p_achievement_id,
    'NOVA achievement reward: '||p_achievement_id,'completed');

  update nexora.player_achievements set claimed_at=now()
  where user_id=p_uid and achievement_id=p_achievement_id;

  update nexora.notifications set is_read=true,event_key=null
  where user_id=p_uid and event_key='achievement-ready:'||p_achievement_id;

  return jsonb_build_object('ok',true,'achievement_id',p_achievement_id,'reward',v_reward);
end;
$function$
;

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
      reputation=reputation + round(2 * v_leadership)::bigint,
      influence=influence + round(1 * v_leadership)::bigint,
      updated_at=now()
  where user_id=p_uid;

  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  values(v_notification,p_uid,'Daily Stipend Credited','+$' || v_amount::text || ' & +40 XP','economy',false);

  return jsonb_build_object('ok',true,'amount',v_amount,'xp_gain',40,'date_key',v_date);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.claim_dynamic_contract(p_uid text, p_contract_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_today date:=(now() at time zone 'UTC')::date;
  v_xp integer;
  v_level integer:=1;
  v_remaining bigint;
  v_step bigint;
  v_leadership numeric;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_new_xp bigint;
  v_progression jsonb;
  v_xp_rate numeric;
  v_xp_cap integer;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select config_value into v_progression from nexora.contract_config where config_key='progression';
  v_xp_rate:=coalesce((v_progression->>'xp_rate')::numeric,0.17);
  v_xp_cap:=coalesce((v_progression->>'xp_cap')::integer,400);
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' and v_contract.claimed_by<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.status='processing' and v_contract.ready_at<=now() then
    update nexora.contract_offers set status='ready',updated_at=now() where id=p_contract_id;
    perform nexora.emit_notification_once(
      p_uid,'contract-ready:'||p_contract_id,
      'العقد جاهز للاستلام','Contract ready to claim',
      'أصبحت مكافأة أحد عقودك جاهزة للاستلام.','A contract reward is ready to claim.','economy'
    );
    v_contract.status:='ready';
  end if;
  if v_contract.status<>'ready' then
    if v_contract.status='processing' then raise exception 'CONTRACT_NOT_READY'; end if;
    raise exception 'CONTRACT_NOT_CLAIMABLE';
  end if;
  if v_contract.ready_at>now() then raise exception 'CONTRACT_NOT_READY'; end if;
  v_xp:=least(v_xp_cap,round(v_contract.payout*v_xp_rate)::integer);
  v_new_xp:=v_profile.xp+v_xp;
  v_remaining:=v_new_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120;
    exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level:=v_level+1;
  end loop;
  v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  update nexora.wallets set balance=balance+v_contract.payout,total_earned=total_earned+v_contract.payout,
    last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_contract.payout,0,v_contract.payout,'contract_reward',p_contract_id,
    'Dynamic contract reward: '||v_contract.item_id,'completed');
  update nexora.player_profiles set xp=v_new_xp,level=v_level,
    reputation=reputation+round(v_contract.reputation_reward*v_leadership)::bigint,
    updated_at=now() where user_id=p_uid;
  if v_contract.scope='organization' then
    update nexora.organizations set reputation=reputation+v_contract.org_reputation_reward,updated_at=now()
      where id=v_contract.org_id;
  end if;
  update nexora.contract_offers set status='completed',completed_at=now(),updated_at=now() where id=p_contract_id;
  update nexora.notifications set is_read=true,event_key=null
  where user_id=p_uid and event_key='contract-ready:'||p_contract_id;
  if v_contract.scope='personal' then
    perform nexora.record_org_goal_progress(p_uid,'personal_contracts_completed',1);
  else
    perform nexora.record_org_goal_progress(p_uid,'org_contracts_completed',1);
  end if;
  if v_contract.scope='personal' and v_contract.board_date=v_today and
    not exists(select 1 from nexora.contract_offers replacement
      where replacement.scope=v_contract.scope and replacement.board_date=v_today
        and replacement.slot_no=v_contract.slot_no and replacement.status='offered'
        and ((v_contract.scope='personal' and replacement.user_id=v_contract.user_id)
          or (v_contract.scope='organization' and replacement.org_id=v_contract.org_id)))
    and (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
      and e.active=true and e.starts_at<=now() and e.ends_at>now())) then
    perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
      v_contract.slot_no,v_today,v_contract.item_id,v_contract.tier,v_contract.event_id);
  end if;
  return jsonb_build_object('ok',true,'payout',v_contract.payout,'xp',v_xp,
    'reputation',round(v_contract.reputation_reward*v_leadership));
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.claim_mission_reward(p_uid text, p_mission_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_category text;
  v_metric text;
  v_target bigint;
  v_credits bigint;
  v_xp_gain integer;
  v_rep integer;
  v_title text;
  v_period_key text:='lifetime';
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_progress bigint;
  v_claim text;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_xp bigint;
  v_level integer:=1;
  v_remaining bigint;
  v_step bigint;
  v_gained integer;
  v_leadership numeric;
  v_stats jsonb;
  v_day_start timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
  v_week_start timestamptz:=date_trunc('week',now() at time zone 'UTC') at time zone 'UTC';
  v_quarter_start timestamptz:=date_trunc('quarter',now() at time zone 'UTC') at time zone 'UTC';
begin
  case p_mission_id
    when 'tut_first_trade' then v_category:='tutorial';v_metric:='trades';v_target:=1;v_credits:=450;v_xp_gain:=90;v_rep:=10;v_title:='Enter the Market';
    when 'tut_first_production' then v_category:='tutorial';v_metric:='produced';v_target:=1;v_credits:=550;v_xp_gain:=110;v_rep:=15;v_title:='First Production';
    when 'tut_first_company' then v_category:='tutorial';v_metric:='companies';v_target:=1;v_credits:=850;v_xp_gain:=160;v_rep:=25;v_title:='Found Your Company';

    when 'daily_active_trader' then v_category:='daily';v_metric:='daily_market_buys';v_target:=3;v_credits:=600;v_xp_gain:=120;v_rep:=14;v_title:='Active Market Trader';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'daily_market_orders' then v_category:='daily';v_metric:='daily_market_buys';v_target:=5;v_credits:=700;v_xp_gain:=110;v_rep:=12;v_title:='Market Activity';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'daily_factory_shift' then v_category:='daily';v_metric:='daily_manufacturing';v_target:=3;v_credits:=950;v_xp_gain:=145;v_rep:=16;v_title:='Production Shift';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'daily_market_volume' then v_category:='daily';v_metric:='daily_market_spend';v_target:=2500;v_credits:=1100;v_xp_gain:=155;v_rep:=18;v_title:='Capital in Motion';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'daily_company_cycle' then v_category:='daily';v_metric:='daily_company_collections';v_target:=2;v_credits:=1300;v_xp_gain:=175;v_rep:=20;v_title:='Operating Cycle';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');

    when 'weekly_market_mogul' then v_category:='weekly';v_metric:='weekly_market_buys';v_target:=20;v_credits:=1500;v_xp_gain:=300;v_rep:=35;v_title:='Weekly Market Mogul';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'weekly_market_network' then v_category:='weekly';v_metric:='weekly_market_buys';v_target:=35;v_credits:=4200;v_xp_gain:=520;v_rep:=48;v_title:='Supply Network';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'weekly_industrial_output' then v_category:='weekly';v_metric:='weekly_manufacturing';v_target:=25;v_credits:=5200;v_xp_gain:=650;v_rep:=58;v_title:='Sustained Output';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'weekly_capital_flow' then v_category:='weekly';v_metric:='weekly_market_spend';v_target:=30000;v_credits:=6500;v_xp_gain:=760;v_rep:=68;v_title:='Investment Flow';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'weekly_corporate_returns' then v_category:='weekly';v_metric:='weekly_company_collections';v_target:=12;v_credits:=7800;v_xp_gain:=900;v_rep:=80;v_title:='Corporate Returns';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');

    when 'seasonal_syndicate' then v_category:='seasonal';v_metric:='org';v_target:=1;v_credits:=1200;v_xp_gain:=260;v_rep:=35;v_title:='Economic Syndicate Alliance';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    when 'seasonal_market_leadership' then v_category:='seasonal';v_metric:='seasonal_market_buys';v_target:=250;v_credits:=22000;v_xp_gain:=1900;v_rep:=190;v_title:='Market Leadership';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    when 'seasonal_industry_scale' then v_category:='seasonal';v_metric:='seasonal_manufacturing';v_target:=180;v_credits:=28000;v_xp_gain:=2400;v_rep:=230;v_title:='Industrial Scale';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    when 'seasonal_capital_commitment' then v_category:='seasonal';v_metric:='seasonal_market_spend';v_target:=500000;v_credits:=38000;v_xp_gain:=3200;v_rep:=300;v_title:='Capital Commitment';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    when 'seasonal_corporate_scale' then v_category:='seasonal';v_metric:='seasonal_company_collections';v_target:=75;v_credits:=50000;v_xp_gain:=4000;v_rep:=360;v_title:='Portfolio Management';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;

    -- Backward compatibility for clients that were open before the update.
    when 'weekly_real_estate' then v_category:='weekly';v_metric:='properties';v_target:=1;v_credits:=950;v_xp_gain:=210;v_rep:=28;v_title:='Real Estate Expansion';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    else raise exception 'INVALID_MISSION';
  end case;

  v_claim:=p_uid||'_'||p_mission_id||'_'||v_period_key;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;

  if exists(select 1 from nexora.player_missions
    where user_id=p_uid and mission_id=p_mission_id and period_key=v_period_key) then
    raise exception 'MISSION_ALREADY_CLAIMED';
  end if;

  v_progress:=case v_metric
    when 'daily_market_buys' then (select count(*) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_day_start)
    when 'daily_manufacturing' then (select count(*) from nexora.transactions where from_uid=p_uid and type='manufacturing' and status='completed' and created_at>=v_day_start)
    when 'daily_company_collections' then (select count(*) from nexora.transactions where to_uid=p_uid and type='company_collect' and status='completed' and created_at>=v_day_start)
    when 'daily_market_spend' then (select coalesce(sum(amount),0) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_day_start)
    when 'weekly_market_buys' then (select count(*) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_week_start)
    when 'weekly_manufacturing' then (select count(*) from nexora.transactions where from_uid=p_uid and type='manufacturing' and status='completed' and created_at>=v_week_start)
    when 'weekly_market_spend' then (select coalesce(sum(amount),0) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_week_start)
    when 'weekly_company_collections' then (select count(*) from nexora.transactions where to_uid=p_uid and type='company_collect' and status='completed' and created_at>=v_week_start)
    when 'seasonal_market_buys' then (select count(*) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_quarter_start)
    when 'seasonal_manufacturing' then (select count(*) from nexora.transactions where from_uid=p_uid and type='manufacturing' and status='completed' and created_at>=v_quarter_start)
    when 'seasonal_market_spend' then (select coalesce(sum(amount),0) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_quarter_start)
    when 'seasonal_company_collections' then (select count(*) from nexora.transactions where to_uid=p_uid and type='company_collect' and status='completed' and created_at>=v_quarter_start)
    when 'trades' then coalesce((v_profile.stats->>'tradesCount')::bigint,0)
    when 'produced' then coalesce((v_profile.stats->>'totalProduced')::bigint,0)
    when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::bigint,0)
    when 'properties' then coalesce((v_profile.stats->>'propertiesOwned')::bigint,0)
    when 'org' then case when v_profile.org_id is null then 0 else 1 end
    else v_profile.level
  end;
  if v_progress<v_target then raise exception 'MISSION_NOT_COMPLETE';end if;

  insert into nexora.player_missions(user_id,mission_id,category,reward_credits,reward_xp,period_key)
    values(p_uid,p_mission_id,v_category,v_credits,v_xp_gain,v_period_key);
  update nexora.wallets set balance=balance+v_credits,total_earned=total_earned+v_credits,last_tx_id=v_tx,updated_at=now()
    where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,'SYSTEM',p_uid,v_credits,0,v_credits,'mission_reward',v_claim,'Mission reward: '||v_title,'completed');

  v_xp:=v_profile.xp+v_xp_gain;
  v_remaining:=v_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120;
    exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level:=v_level+1;
  end loop;
  v_gained:=greatest(0,v_level-v_profile.level);
  v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{missionsCompleted}',
    to_jsonb(coalesce((v_profile.stats->>'missionsCompleted')::integer,0)+1),true);
  update nexora.player_profiles set xp=v_xp,level=v_level,
    reputation=reputation+round(v_rep*v_leadership)::bigint,
    influence=influence+round(5*v_leadership)::bigint,stats=v_stats,updated_at=now()
    where user_id=p_uid;
  return jsonb_build_object('ok',true,'reward_credits',v_credits,'reward_xp',v_xp_gain,
    'period_key',v_period_key,'levels_gained',v_gained);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.collect_company_revenue(p_uid text, p_company_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company nexora.companies%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_capacity bigint[]:=array[3500,7000,14000,25000,40000];
  v_vault_level integer;
  v_net bigint;
  v_elapsed numeric;
  v_payout bigint;
  v_now timestamptz:=now();
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_log text:='clog_'||gen_random_uuid()::text;
  v_xp_gain bigint;
  v_xp bigint;
  v_level_after integer:=1;
  v_remaining bigint;
  v_step bigint;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.last_collected_at is not null and v_now-v_company.last_collected_at<interval '30 seconds' then
    raise exception 'NOTHING_TO_COLLECT';
  end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_net:=nexora.company_net_hourly(p_company_id);
  v_vault_level:=greatest(1,least(5,v_company.vault_level));
  v_elapsed:=greatest(0,extract(epoch from (v_now-coalesce(v_company.last_collected_at,v_now)))/3600);
  v_payout:=least(v_capacity[v_vault_level],greatest(0,coalesce(v_company.vault_balance,0)+floor(v_net*least(12,v_elapsed))::bigint));
  if v_payout<1 then raise exception 'NOTHING_TO_COLLECT'; end if;
  update nexora.wallets set balance=balance+v_payout,total_earned=total_earned+v_payout,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.companies set total_revenue=total_revenue+v_payout,vault_balance=0,last_collected_at=v_now,updated_at=now() where id=p_company_id;
  v_xp_gain:=floor((v_company.total_revenue+v_payout)::numeric/15)::bigint-floor(v_company.total_revenue::numeric/15)::bigint;
  v_xp:=v_profile.xp+v_xp_gain;
  v_remaining:=v_xp;
  while v_level_after<200 loop
    v_step:=200+(v_level_after-1)*120;
    exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level_after:=v_level_after+1;
  end loop;
  update nexora.player_profiles set xp=v_xp,level=v_level_after,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,'SYSTEM',p_uid,v_payout,0,v_payout,'company_collect',p_company_id,'Company revenue collected: '||v_company.name,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
    values(v_log,p_company_id,p_uid,'collect',v_payout,'Collected +$'||v_payout::text);
  return jsonb_build_object('ok',true,'payout',v_payout,'xp_gain',v_xp_gain);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.company_collectable_amount(p_company_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company nexora.companies%rowtype;
  v_capacity bigint[] := array[3500,7000,14000,25000,40000];
  v_vault_level integer;
  v_net bigint;
  v_elapsed numeric;
  v_accrued bigint;
begin
  select * into v_company from nexora.companies where id = p_company_id;
  if not found then return jsonb_build_object('net_hourly', 0, 'collectable', 0); end if;
  v_net := nexora.company_net_hourly(p_company_id);
  v_vault_level := greatest(1, least(5, coalesce(v_company.vault_level, 1)));
  v_elapsed := greatest(0, extract(epoch from (now() - coalesce(v_company.last_collected_at, now()))) / 3600);
  v_accrued := least(
    v_capacity[v_vault_level],
    greatest(0, coalesce(v_company.vault_balance, 0) + floor(v_net * least(12, v_elapsed))::bigint)
  );
  return jsonb_build_object('net_hourly', v_net, 'collectable', v_accrued);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.company_net_hourly(p_company_id text)
 RETURNS bigint
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company nexora.companies%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_management numeric;
  v_finance numeric;
  v_tier numeric := 0;
  v_event_mult numeric := 1;
  v_seen text[] := '{}';
  v_event record;
  v_income_bonus numeric := 0;
  v_level_gain numeric;
  v_gross numeric;
  v_expense numeric;
begin
  select * into v_company from nexora.companies where id = p_company_id;
  if not found then return 0; end if;
  select * into v_profile from nexora.player_profiles where user_id = v_company.owner_uid;
  if not found then return 0; end if;
  v_management := greatest(0, coalesce((v_profile.skills->>'management')::numeric, 0));
  v_finance := greatest(0, coalesce((v_profile.skills->>'finance')::numeric, 0));
  v_tier := case
    when v_profile.reputation >= 700 then .08
    when v_profile.reputation >= 350 then .06
    when v_profile.reputation >= 160 then .04
    when v_profile.reputation >= 60 then .02
    else 0
  end;
  if v_profile.org_id is not null then
    select greatest(0, least(10, coalesce((research->>'commerce')::numeric, 0)))
      into v_income_bonus
      from nexora.organizations where id = v_profile.org_id;
  end if;
  for v_event in select group_key, revenue_multiplier, affected_sectors from (
    select distinct on (coalesce(nullif(stack_group, ''), effect_type, id))
      coalesce(nullif(stack_group, ''), effect_type, id) group_key,
      revenue_multiplier, affected_sectors, starts_at
    from nexora.world_events
    where active = true and starts_at <= now() and ends_at > now()
    order by coalesce(nullif(stack_group, ''), effect_type, id), starts_at desc
  ) e order by group_key limit 3 loop
    if not (v_event.group_key = any(v_seen)) then
      v_seen := array_append(v_seen, v_event.group_key);
      if coalesce(v_event.affected_sectors, '[]'::jsonb) @> jsonb_build_array(v_company.sector) then
        v_event_mult := v_event_mult * coalesce(v_event.revenue_multiplier, 1);
      end if;
    end if;
  end loop;
  v_event_mult := greatest(.75, least(1.4, round(v_event_mult::numeric, 3)));
  v_level_gain := nexora.company_sector_level_gain(v_company.sector);
  v_gross := round(
    (v_company.base_revenue_per_hour + (v_company.level - 1) * v_level_gain)
    * (1 + v_management * .08)
    * v_event_mult
    * (1 + v_tier)
    * (1 + least(.05, v_income_bonus * .005))
  );
  v_expense := round(
    v_company.expense_per_hour * (1 + (v_company.level - 1) * .08)
    * (1 - least(.45, v_finance * .05))
  );
  return greatest(15, v_gross - v_expense)::bigint;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.company_sector_level_gain(p_sector text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select case coalesce(p_sector, 'trade')
    when 'trade' then 37.8::numeric
    when 'services' then 47::numeric
    when 'logistics' then 60::numeric
    when 'manufacturing' then 76.8::numeric
    when 'tech' then 97.8::numeric
    else 37.8::numeric
  end
$function$
;

CREATE OR REPLACE FUNCTION nexora.company_upgrade_cost(p_sector text, p_level integer)
 RETURNS bigint
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select ceil(
    nexora.company_sector_level_gain(p_sector)
    * (8 + 2.411 * greatest(1, least(99, coalesce(p_level, 1))))
  )::bigint
$function$
;

CREATE OR REPLACE FUNCTION nexora.company_upgrade_duration_seconds(p_target integer)
 RETURNS bigint
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select round(
    11 * power(greatest(2, least(100, coalesce(p_target, 2)))::numeric / 13, 0.85) * 60
  )::bigint
$function$
;

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
  update nexora.player_profiles set xp=v_xp,level=v_level,updated_at=now() where user_id=p_uid;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'upgrade_completed',0,'Company reached Level '||v_target::text);
  return jsonb_build_object('ok',true,'level',v_target);
end;
$function$
;

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
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.complete_manufacturing_job(p_uid text, p_job_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_job nexora.manufacturing_jobs%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_new_xp bigint;
  v_level integer := 1;
  v_remaining bigint;
  v_step bigint;
  v_levels_gained integer;
  v_leadership numeric;
  v_stats jsonb;
  v_capacity bigint;
  v_total bigint;
begin
  select * into v_job
  from nexora.manufacturing_jobs
  where id = p_job_id and user_id = p_uid
  for update;
  if not found then raise exception 'MANUFACTURING_JOB_NOT_FOUND'; end if;
  if v_job.status = 'cancelled' then raise exception 'MANUFACTURING_JOB_CANCELLED'; end if;
  if v_job.status = 'completed' then
    return jsonb_build_object('ok', true, 'output_item', v_job.output_item_id, 'output_qty', v_job.output_qty, 'already_completed', true);
  end if;
  if v_job.ends_at > now() then raise exception 'MANUFACTURING_JOB_NOT_FINISHED'; end if;

  select * into v_profile from nexora.player_profiles where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_uid, 0));
  v_total := nexora.player_inventory_usage(p_uid);
  v_capacity := nexora.player_inventory_capacity(v_profile.level);
  if v_total + v_job.output_qty > v_capacity then
    raise exception 'INVENTORY_CAPACITY_EXCEEDED';
  end if;

  insert into nexora.inventory(user_id, item_id, quantity)
  values (p_uid, v_job.output_item_id, v_job.output_qty)
  on conflict (user_id, item_id)
  do update set quantity = nexora.inventory.quantity + excluded.quantity, updated_at = now();

  v_new_xp := v_profile.xp + v_job.xp_reward;
  v_remaining := v_new_xp;
  while v_level < 200 loop
    v_step := 200 + (v_level - 1) * 120;
    exit when v_remaining < v_step;
    v_remaining := v_remaining - v_step;
    v_level := v_level + 1;
  end loop;
  v_levels_gained := greatest(0, v_level - v_profile.level);
  v_leadership := 1 + coalesce((v_profile.skills->>'leadership')::numeric, 0) * 0.1;
  v_stats := jsonb_set(
    coalesce(v_profile.stats, '{}'::jsonb),
    '{totalProduced}',
    to_jsonb(coalesce((v_profile.stats->>'totalProduced')::integer, 0) + v_job.output_qty),
    true
  );

  update nexora.player_profiles
  set xp = v_new_xp, level = v_level, skill_points = skill_points + v_levels_gained * 2,
      reputation = reputation + round(3 * v_leadership)::bigint,
      influence = influence + round(2 * v_leadership)::bigint,
      stats = v_stats, updated_at = now()
  where user_id = p_uid;

  update nexora.manufacturing_jobs
  set status = 'completed', completed_at = now()
  where id = p_job_id;

  perform nexora.emit_notification_once(
    p_uid,'manufacturing-complete:'||p_job_id,
    'اكتمل التصنيع','Manufacturing completed',
    'اكتمل التصنيع وأُضيف الإنتاج إلى مخزونك.','Your production finished and the output was added to inventory.','economy'
  );

  return jsonb_build_object('ok', true, 'output_item', v_job.output_item_id, 'output_qty', v_job.output_qty);
end;
$function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.create_market_listing(p_uid text, p_item_id text, p_qty integer, p_unit_price bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_inventory nexora.inventory%rowtype; v_username text; v_id text := 'lst_' || gen_random_uuid()::text; v_previous_transfer_setting text;
begin
  if p_item_id not in (
    'silicon_ore','copper_wire','energy_cells','crude_alloy','carbon_fiber','rare_minerals',
    'titanium_ore','polymer_resin','biotech_gel','quantum_dust',
    'microchips','precision_frame','synth_polymer','quantum_server','logistics_drone','bio_module'
  ) then raise exception 'INVALID_ITEM'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 10000 or p_unit_price is null or p_unit_price < 1 or p_unit_price > 1000000 then
    raise exception 'INVALID_LISTING_PARAMS';
  end if;
  select username into v_username from nexora.player_profiles where user_id=p_uid;
  if v_username is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=p_item_id for update;
  if not found or v_inventory.quantity < p_qty then raise exception 'INSUFFICIENT_INVENTORY'; end if;
  update nexora.inventory set quantity=quantity-p_qty,updated_at=now() where user_id=p_uid and item_id=p_item_id;
  v_previous_transfer_setting:=coalesce(current_setting('nexora.market_listing_transfer',true),'false');
  perform set_config('nexora.market_listing_transfer','true',true);
  insert into nexora.market_listings(id,seller_uid,seller_name,item_id,quantity,remaining_qty,unit_price,status)
  values(v_id,p_uid,v_username,p_item_id,p_qty,p_qty,p_unit_price,'active');
  perform set_config('nexora.market_listing_transfer',v_previous_transfer_setting,true);
  return jsonb_build_object('ok',true,'listing_id',v_id);
end;
$function$
;

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
 update nexora.player_profiles set xp=v_xp,level=v_level,reputation=reputation+round(20*v_leadership)::bigint,influence=influence+round(25*v_leadership)::bigint,org_id=v_id,updated_at=now()
 where user_id=p_uid;
 return jsonb_build_object('ok',true,'org_id',v_id);
exception when unique_violation then raise exception 'TAG_TAKEN';
end;$function$
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.deliver_dynamic_contract(p_uid text, p_contract_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_inventory nexora.inventory%rowtype;
  v_fee bigint;
  v_remaining_secs integer;
  v_progression jsonb;
  v_fee_rate numeric;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_now timestamptz:=now();
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select config_value into v_progression from nexora.contract_config where config_key='progression';
  v_fee_rate:=coalesce((v_progression->>'fee_rate')::numeric,0.04);
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  insert into nexora.inventory(user_id,item_id,quantity) values(p_uid,v_contract.item_id,0)
    on conflict(user_id,item_id) do nothing;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=v_contract.item_id for update;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' and v_contract.claimed_by<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.status<>'accepted' then raise exception 'CONTRACT_NOT_ACCEPTED'; end if;
  if v_contract.deadline_at<=v_now then
    update nexora.contract_offers set status='expired',updated_at=v_now where id=p_contract_id;
    if v_contract.scope='personal' and v_contract.board_date=(v_now at time zone 'UTC')::date and
      (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
        and e.active=true and e.starts_at<=v_now and e.ends_at>v_now)) then
      perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
        v_contract.slot_no,(v_now at time zone 'UTC')::date,v_contract.item_id,v_contract.tier,v_contract.event_id);
    end if;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'ntf_'||gen_random_uuid()::text,p_uid,'CONTRACT_EXPIRED','Contract deadline expired','economy',false
    where exists(select 1 from nexora.player_private pp where pp.user_id=p_uid and pp.notifications_enabled=true);
    return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED');
  end if;
  if v_inventory.quantity<v_contract.quantity then raise exception 'MISSING_INPUTS'; end if;
  v_fee:=round(v_contract.payout*v_fee_rate)::bigint;
  if v_wallet.balance<v_fee then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_remaining_secs:=greatest(0,ceil(extract(epoch from (v_contract.deadline_at-v_now)))::integer);
  update nexora.inventory set quantity=quantity-v_contract.quantity,updated_at=v_now
    where user_id=p_uid and item_id=v_contract.item_id;
  update nexora.wallets set balance=balance-v_fee,total_spent=total_spent+v_fee,last_tx_id=v_tx,updated_at=v_now
    where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_fee,v_fee,0,'contract_fee',p_contract_id,'Contract processing fee','completed');
  update nexora.contract_offers set status='processing',deadline_remaining_secs=v_remaining_secs,
    deadline_at=null,processing_started_at=v_now,ready_at=v_now+make_interval(mins=>v_contract.processing_minutes),
    delivered_at=v_now,fee_paid=v_fee,updated_at=v_now where id=p_contract_id;
  return jsonb_build_object('ok',true,'ready_at',v_now+make_interval(mins=>v_contract.processing_minutes),
    'fee',v_fee,'remaining_secs',v_remaining_secs);
end;
$function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.emit_notification_once(p_uid text, p_event_key text, p_title_ar text, p_title_en text, p_body_ar text, p_body_en text, p_type text DEFAULT 'economy'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_language text;
  v_enabled boolean;
  v_inserted text;
begin
  select language,notifications_enabled into v_language,v_enabled
  from nexora.player_private where user_id=p_uid;
  if not found or not coalesce(v_enabled,false) then return; end if;

  insert into nexora.notification_events(user_id,event_key)
  values(p_uid,p_event_key)
  on conflict(user_id,event_key) do nothing
  returning event_key into v_inserted;
  if v_inserted is null then return; end if;

  insert into nexora.notifications(id,user_id,title,body,type,is_read,event_key)
  values(
    'ntf_'||gen_random_uuid()::text,p_uid,
    case when v_language='ar' then p_title_ar else p_title_en end,
    case when v_language='ar' then p_body_ar else p_body_en end,
    p_type,false,p_event_key
  );
end;
$function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.enforce_market_listing_capacity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_level integer;
  v_capacity bigint;
  v_total bigint;
  v_previous_total bigint;
  v_new_contribution bigint;
  v_old_contribution bigint;
begin
  if new.seller_uid='SYSTEM' or current_setting('nexora.market_listing_transfer',true)='true'
    or new.status <> 'active' or new.remaining_qty <= 0 then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.seller_uid,0));
  select level into v_level from nexora.player_profiles where user_id=new.seller_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_capacity:=nexora.player_inventory_capacity(v_level);
  v_total:=nexora.player_inventory_usage(new.seller_uid);
  if v_total>v_capacity then
    if tg_op='INSERT' then
      raise exception 'INVENTORY_CAPACITY_EXCEEDED'
        using detail=format('Inventory capacity is %s units including active market offers; attempted total is %s units.',v_capacity,v_total);
    else
      v_new_contribution:=case when new.status='active' then greatest(0,new.remaining_qty) else 0 end;
      v_old_contribution:=case when old.status='active' then greatest(0,old.remaining_qty) else 0 end;
      v_previous_total:=v_total-v_new_contribution+v_old_contribution;
      if v_total>v_previous_total then
        raise exception 'INVENTORY_CAPACITY_EXCEEDED'
          using detail=format('Inventory capacity is %s units including active market offers; attempted total is %s units.',v_capacity,v_total);
      end if;
    end if;
  end if;
  return null;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.enforce_market_listing_price_bounds()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_min bigint;
  v_max bigint;
begin
  select min_price, max_price into v_min, v_max
  from nexora.market_price_bounds(new.item_id);
  if v_min is null or v_max is null then raise exception 'INVALID_ITEM'; end if;
  if new.unit_price < v_min then raise exception 'PRICE_BELOW_MINIMUM'; end if;
  if new.unit_price > v_max then raise exception 'PRICE_ABOVE_MAXIMUM'; end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.enforce_market_order_price_bounds()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_min bigint;
  v_max bigint;
begin
  select min_price, max_price into v_min, v_max
  from nexora.market_price_bounds(new.item_id);
  if v_min is null or v_max is null then raise exception 'INVALID_ITEM'; end if;
  if new.unit_price < v_min then raise exception 'PRICE_BELOW_MINIMUM'; end if;
  if new.unit_price > v_max then raise exception 'PRICE_ABOVE_MAXIMUM'; end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.enforce_player_inventory_capacity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_level integer;
  v_capacity bigint;
  v_total bigint;
begin
  if current_setting('nexora.allow_inventory_refund', true) = 'true' then
    return null;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.user_id, 0));
  select level into v_level
  from nexora.player_profiles
  where user_id = new.user_id;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_capacity := nexora.player_inventory_capacity(v_level);
  v_total := nexora.player_inventory_usage(new.user_id);

  if v_total > v_capacity then
    if tg_op='INSERT' then
      raise exception 'INVENTORY_CAPACITY_EXCEEDED'
        using detail = format('Inventory capacity is %s units including active market offers; attempted total is %s units.',v_capacity,v_total);
    elsif new.quantity > old.quantity then
      raise exception 'INVENTORY_CAPACITY_EXCEEDED'
        using detail = format('Inventory capacity is %s units including active market offers; attempted total is %s units.',v_capacity,v_total);
    end if;
  end if;
  return null;
end;
$function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.ensure_org_weekly_goals(p_org_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_org nexora.organizations%rowtype;
  v_week date := date_trunc('week',timezone('UTC',now()))::date;
  v_bases jsonb;
  v_rewards jsonb;
  v_scaling jsonb;
  v_types text[] := array['produce_units','trade_volume','treasury_donations','personal_contracts_completed','org_contracts_completed','company_revenue','factory_upgrades','company_upgrades','companies_founded','factories_founded'];
  v_type text;
  v_difficulty text;
  v_target numeric;
  v_reward bigint;
  v_id text;
  v_count integer;
  v_existing text[];
begin
  select * into v_org from nexora.organizations where id=p_org_id for update;
  if not found then raise exception 'ORG_NOT_FOUND'; end if;
  select coalesce(array_agg(goal_type),array[]::text[]) into v_existing from nexora.org_weekly_goals where org_id=p_org_id and week_start=v_week;
  foreach v_type in array v_existing loop
    v_types:=array_remove(v_types,v_type);
  end loop;
  if cardinality(v_types)=0 then return; end if;
  select config_value into v_bases from nexora.contract_config where config_key='weekly_goal_bases';
  select config_value into v_rewards from nexora.contract_config where config_key='weekly_goal_rewards';
  select config_value into v_scaling from nexora.contract_config where config_key='weekly_goal_scaling';
  -- Three distinct goals are generated for each ISO week in UTC.
  for v_count in 1..least(coalesce((v_scaling->>'goal_count')::integer,10),cardinality(v_types)) loop
    v_type:=v_types[1+floor(random()*cardinality(v_types))::integer];
    v_types:=array_remove(v_types,v_type);
    v_difficulty:=case when v_type in ('produce_units','companies_founded','factories_founded') then 'easy' when v_type in ('trade_volume','treasury_donations','company_revenue') then 'medium' else 'hard' end;
    v_target:=round((coalesce((v_bases->>v_type)::numeric,100)
      * (1+coalesce((v_scaling->>'level_rate')::numeric,0.15)*greatest(1,v_org.level))
      * power(greatest(1,v_org.member_count)::numeric,coalesce((v_scaling->>'member_exponent')::numeric,0.7)))::numeric,0);
    v_reward:=coalesce((v_rewards->>v_difficulty)::bigint,100);
    v_id:='og_'||gen_random_uuid()::text;
    insert into nexora.org_weekly_goals(id,org_id,week_start,goal_type,difficulty,target_amount,reward_reputation)
    values(v_id,p_org_id,v_week,v_type,v_difficulty,v_target,v_reward)
    on conflict(org_id,week_start,goal_type) do nothing;
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.extend_company_auction_on_late_bid()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if old.status='active' and new.status='active'
     and (new.current_price>old.current_price or new.highest_bidder_uid is distinct from old.highest_bidder_uid)
     and old.ends_at>now() and old.ends_at<=now()+interval '5 minutes' then
    new.ends_at:=now()+interval '5 minutes';
    if new.asset_type='factory' and new.factory_id is not null then
      update nexora.factories set auction_ends_at=new.ends_at,updated_at=now() where id=new.factory_id and auction_id=new.id;
    elsif new.company_id is not null then
      update nexora.companies set auction_ends_at=new.ends_at,updated_at=now() where id=new.company_id and auction_id=new.id;
    end if;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.factory_progression_multiplier(p_resource_id text, p_level integer)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select 1 + 0.04 * greatest(0, coalesce(p_level, 1) - 1)
    + 0.0003 * power(greatest(0, coalesce(p_level, 1) - 1)::numeric, 2)
$function$
;

CREATE OR REPLACE FUNCTION nexora.factory_resource_config(p_resource_id text)
 RETURNS TABLE(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select cfg.founding_cost, cfg.production_rate, cfg.operating_cost, cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,20.000::numeric,500.00::numeric,1.00::numeric),
    ('silicon_ore',2800,18.000,520.00,1.20),
    ('energy_cells',4200,16.000,630.00,1.40),
    ('crude_alloy',6200,14.000,500.00,1.65),
    ('carbon_fiber',8500,11.000,520.00,2.10),
    ('rare_minerals',12000,8.000,500.00,3.60),
    ('titanium_ore',16000,7.000,530.00,4.00),
    ('polymer_resin',21000,6.000,500.00,4.50),
    ('biotech_gel',28000,4.000,430.00,5.00),
    ('quantum_dust',36000,3.000,390.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id = p_resource_id;
$function$
;

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
;

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
;

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
;

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
    when 'trade' then v_cost:=1200; v_revenue:=160; v_expense:=30;
    when 'services' then v_cost:=2200; v_revenue:=220; v_expense:=60;
    when 'logistics' then v_cost:=3800; v_revenue:=300; v_expense:=85;
    when 'manufacturing' then v_cost:=6000; v_revenue:=410; v_expense:=120;
    when 'tech' then v_cost:=9000; v_revenue:=550; v_expense:=160;
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
  update nexora.player_profiles set xp=v_xp,level=v_level,reputation=reputation+round(10*v_leadership)::bigint,influence=influence+round(8*v_leadership)::bigint,
    stats=v_stats,updated_at=now() where user_id=p_uid;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,v_id,p_uid,'founded',-v_cost,'Company established in ' || p_sector || ' sector');
  return jsonb_build_object('ok',true,'company_id',v_id);
end;
$function$
;

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
;

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
  update nexora.player_profiles set xp=v_new_xp,level=v_level,reputation=reputation+round(v_rep*v_leadership)::bigint,influence=influence+round(5*v_leadership)::bigint,
    stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'payout',v_payout,'contract_id',v_claim);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.generate_dynamic_contract(p_scope text, p_uid text, p_org_id text, p_slot integer, p_board_date date, p_previous_item text DEFAULT NULL::text, p_previous_tier text DEFAULT NULL::text, p_event_id text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_org nexora.organizations%rowtype;
  v_catalog jsonb;
  v_rules jsonb;
  v_progression jsonb;
  v_weights jsonb;
  v_tier text;
  v_item text;
  v_base bigint;
  v_qty integer;
  v_multiplier numeric;
  v_min_hours integer;
  v_max_hours integer;
  v_rep integer;
  v_org_rep integer;
  v_premium numeric:=0;
  v_event_multiplier numeric:=1;
  v_event_end timestamptz;
  v_payout bigint;
  v_processing integer;
  v_id text:='ctr_'||gen_random_uuid()::text;
  v_generation integer;
  v_roll numeric:=random()*100;
  v_acc numeric:=0;
  v_key text;
  v_value jsonb;
  v_min_level integer;
  v_item_weight_exponent numeric:=0.30;
  v_level integer:=1;
  v_board_end timestamptz;
begin
  select config_value into v_catalog from nexora.contract_config where config_key='catalog_prices';
  select config_value into v_rules from nexora.contract_config where config_key='tier_rules';
  select config_value into v_progression from nexora.contract_config where config_key='progression';
  select coalesce((config_value->>'price_exponent')::numeric,0.30) into v_item_weight_exponent
    from nexora.contract_config where config_key='item_selection';
  if p_scope='personal' then
    select * into v_profile from nexora.player_profiles where user_id=p_uid;
    if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
    v_level:=v_profile.level;
    v_weights:= (select config_value from nexora.contract_config where config_key='personal_tier_weights');
    v_min_level:=1;
  else
    select * into v_org from nexora.organizations where id=p_org_id;
    if not found then raise exception 'ORG_NOT_FOUND'; end if;
    v_level:=v_org.level;
    v_weights:= (select config_value from nexora.contract_config where config_key='org_tier_weights')
      -> case when v_level<=2 then '1-2' when v_level<=5 then '3-5' when v_level<=8 then '6-8' else '9-10' end;
  end if;

  if p_event_id is not null then
    select target_item_id,price_multiplier,ends_at into v_item,v_event_multiplier,v_event_end
    from nexora.world_events where id=p_event_id and active=true
      and starts_at<=now() and ends_at>now() and target_item_id is not null and price_multiplier>1;
    if v_item is null then raise exception 'EVENT_NOT_ACTIVE'; end if;
    v_tier:=coalesce(v_catalog->v_item->>'tier','common');
    v_premium:=least(coalesce((v_progression->>'event_premium_cap')::numeric,0.10),
      greatest(0,(v_event_multiplier-1)*coalesce((v_progression->>'event_premium_slope')::numeric,0.5)));
  else
    for v_key,v_value in select key,value from jsonb_each(v_weights) loop
      if v_key='uncommon' and p_scope='personal' and v_level<coalesce((v_progression->>'uncommon_level')::integer,3) then continue; end if;
      if v_key='rare' and p_scope='personal' and v_level<coalesce((v_progression->>'rare_level')::integer,8) then continue; end if;
      if v_key='epic' and p_scope='personal' then continue; end if;
      v_acc:=v_acc+coalesce((v_value#>>'{}')::numeric,0);
      if v_roll<=v_acc then v_tier:=v_key; exit; end if;
    end loop;
    v_tier:=coalesce(v_tier,'common');
    select item_id into v_item
    from jsonb_each(v_catalog) c(item_id,item_cfg)
    where ((v_tier='epic' and item_cfg->>'tier'='rare') or item_cfg->>'tier'=v_tier)
      and (p_previous_item is null or item_id<>p_previous_item or v_tier<>coalesce(p_previous_tier,''))
      and not exists (
        select 1 from nexora.contract_offers o
        where o.board_date=p_board_date and o.status in ('offered','accepted','processing','ready')
          and o.item_id=item_id and o.tier=v_tier and o.slot_no=p_slot
          and ((p_scope='personal' and o.scope='personal' and o.user_id=p_uid)
            or (p_scope='organization' and o.scope='organization' and o.org_id=p_org_id))
      )
    order by random()/power((item_cfg->>'price')::numeric,-v_item_weight_exponent) limit 1;
    if v_item is null then
      -- If the weighted tier has no unused item left, fall back to another
      -- unlocked tier, while still avoiding every active board item.
      select c.item_id,c.item_cfg->>'tier' into v_item,v_tier
      from jsonb_each(v_catalog) c(item_id,item_cfg)
      where (p_previous_item is null or c.item_id<>p_previous_item)
        and (p_scope='organization' or
          (c.item_cfg->>'tier'<>'uncommon' or v_level>=coalesce((v_progression->>'uncommon_level')::integer,3)) and
          (c.item_cfg->>'tier'<>'rare' or v_level>=coalesce((v_progression->>'rare_level')::integer,8)))
        and not exists (
          select 1 from nexora.contract_offers o
          where o.board_date=p_board_date and o.status in ('offered','accepted','processing','ready')
            and o.item_id=c.item_id and o.tier=c.item_cfg->>'tier' and o.slot_no=p_slot
            and ((p_scope='personal' and o.scope='personal' and o.user_id=p_uid)
              or (p_scope='organization' and o.scope='organization' and o.org_id=p_org_id))
        )
      order by random()/power((c.item_cfg->>'price')::numeric,-v_item_weight_exponent) limit 1;
    end if;
  end if;
  if v_item is null then return null; end if;
  v_base:=(v_catalog->v_item->>'price')::bigint;
  select value into v_value from jsonb_each(v_rules) where key=v_tier;
  v_qty:=coalesce((v_value->>'min_qty')::integer,1)
    +floor(random()*(coalesce((v_value->>'max_qty')::integer,1)-coalesce((v_value->>'min_qty')::integer,1)+1))::integer;
  if p_scope='organization' then v_qty:=ceil(v_qty*coalesce((v_progression->>'org_quantity_multiplier')::numeric,1.5))::integer; end if;
  v_multiplier:=(v_value->>'multiplier')::numeric;
  v_min_hours:=(v_value->>'min_hours')::integer;
  v_max_hours:=(v_value->>'max_hours')::integer;
  v_rep:=(v_value->>'reputation')::integer;
  v_org_rep:=(v_value->>'org_reputation')::integer;
  v_payout:=least(coalesce((v_progression->>'payout_cap')::bigint,2500),
    round(v_qty*v_base*v_multiplier*(
      coalesce((v_progression->>'payout_random_min')::numeric,0.95)
      +random()*(coalesce((v_progression->>'payout_random_max')::numeric,1.05)
        -coalesce((v_progression->>'payout_random_min')::numeric,0.95))
      )*(1+v_premium))::bigint);
  v_processing:=greatest(coalesce((v_progression->>'processing_min_minutes')::integer,10),
    least(coalesce((v_progression->>'processing_max_minutes')::integer,120),
      round(v_payout/coalesce((v_progression->>'processing_divisor')::numeric,12))::integer));
  v_board_end:=((p_board_date+1)::timestamp at time zone 'UTC');
  if p_event_id is not null then
    v_board_end:=least(v_board_end,coalesce(v_event_end,v_board_end));
  end if;
  select coalesce(max(slot_generation),0)+1 into v_generation
  from nexora.contract_offers
  where scope=p_scope and slot_no=p_slot and board_date=p_board_date
    and ((p_scope='personal' and user_id=p_uid) or (p_scope='organization' and org_id=p_org_id));
  insert into nexora.contract_offers(
    id,scope,user_id,org_id,slot_no,slot_generation,board_date,event_id,item_id,tier,quantity,
    base_price,payout,reputation_reward,org_reputation_reward,processing_minutes,event_premium,
    offer_expires_at
  ) values (
    v_id,p_scope,case when p_scope='personal' then p_uid end,
    case when p_scope='organization' then p_org_id end,p_slot,greatest(1,v_generation),
    p_board_date,p_event_id,v_item,v_tier,v_qty,v_base,v_payout,v_rep,
    case when p_scope='organization' then v_org_rep else 0 end,
    v_processing,v_premium,v_board_end
  );
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.get_contract_slot_cooldowns(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_org_id text;
  v_can_refresh_org boolean:=false;
  v_personal_refresh_used integer:=0;
  v_org_refresh_used integer:=0;
begin
  select org_id into v_org_id from nexora.player_profiles where user_id=p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select exists(select 1 from nexora.organization_members
    where org_id=v_org_id and user_id=p_uid and role in ('leader','deputy'))
    into v_can_refresh_org;
  select coalesce(used_count,0) into v_personal_refresh_used
    from nexora.contract_slot_refresh_usage
    where scope='personal' and owner_id=p_uid and date_key=(now() at time zone 'UTC')::date;
  select coalesce(used_count,0) into v_org_refresh_used
    from nexora.contract_slot_refresh_usage
    where scope='organization' and owner_id=v_org_id and date_key=(now() at time zone 'UTC')::date;

  return jsonb_build_object(
    'server_now',now(),
    'can_refresh_org',v_can_refresh_org,
    'personal_refresh_used',v_personal_refresh_used,
    'personal_refresh_limit',3,
    'org_refresh_used',v_org_refresh_used,
    'org_refresh_limit',5,
    'personal',coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no',c.slot_no,'board_date',c.board_date,'cooldown_until',c.cooldown_until
      ) order by c.slot_no)
      from (
        select slot_no,max(board_date) as board_date,max(cooldown_until) as cooldown_until
        from nexora.contract_slot_cooldowns
        where scope='personal' and owner_id=p_uid and slot_no between 1 and 5
          and cooldown_until>now()
        group by slot_no
      ) c
    ),'[]'::jsonb),
    'organization',coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no',c.slot_no,'board_date',c.board_date,'cooldown_until',c.cooldown_until
      ) order by c.slot_no)
      from (
        select slot_no,max(board_date) as board_date,max(cooldown_until) as cooldown_until
        from nexora.contract_slot_cooldowns
        where scope='organization' and owner_id=v_org_id
          and cooldown_until>now()
        group by slot_no
      ) c
    ),'[]'::jsonb)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.get_dynamic_contract_board(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_org nexora.organizations%rowtype;
  v_progression jsonb;
  v_personal_slots integer;
  v_daily_limit integer;
  v_org_slots_base integer;
  v_org_slots_divisor integer;
  v_today date:=(now() at time zone 'UTC')::date;
  v_end timestamptz:=((date_trunc('day',timezone('UTC',now()))+interval '1 day') at time zone 'UTC');
  v_personal jsonb;
  v_org_board jsonb:='[]'::jsonb;
  v_active integer;
  v_slots integer;
  v_slot integer;
  v_event record;
  v_event_slot integer;
  v_event_offer_count integer;
  v_event_index integer;
  v_claims integer;
  v_org_claims integer;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select config_value into v_progression from nexora.contract_config where config_key='progression';
  v_personal_slots:=coalesce((v_progression->>'personal_slots')::integer,6);
  v_daily_limit:=coalesce((v_progression->>'daily_claim_limit')::integer,5);
  v_org_slots_base:=coalesce((v_progression->>'org_slots_base')::integer,2);
  v_org_slots_divisor:=greatest(1,coalesce((v_progression->>'org_slots_level_divisor')::integer,2));
  perform nexora.settle_dynamic_contracts(p_uid);
  for v_slot in 1..v_personal_slots loop
    if not exists(select 1 from nexora.contract_offers where scope='personal' and user_id=p_uid
      and board_date=v_today and slot_no=v_slot and status in ('offered','accepted','processing','ready')) then
      perform nexora.generate_dynamic_contract('personal',p_uid,null,v_slot,v_today,null,null,null);
    end if;
  end loop;
  -- One or two event offers per active targeted event, outside the six standard slots.
  for v_event in
    select id from nexora.world_events where active=true and starts_at<=now() and ends_at>now()
      and target_item_id is not null and price_multiplier>1
      and exists(select 1 from nexora.contract_config c where c.config_key='catalog_prices'
        and c.config_value ? nexora.world_events.target_item_id)
    order by starts_at,id
  loop
    select coalesce(max(slot_no),0) into v_event_slot from nexora.contract_offers
      where scope='personal' and user_id=p_uid and board_date=v_today and event_id=v_event.id;
    if v_event_slot=0 then
      v_event_offer_count:=1+floor(random()*2)::integer;
      for v_event_index in 1..v_event_offer_count loop
        perform nexora.generate_dynamic_contract('personal',p_uid,null,
          (1000+((select count(*) from nexora.world_events e2 where e2.id<=v_event.id)-1)*2+v_event_index)::integer,
          v_today,null,null,v_event.id);
      end loop;
    end if;
  end loop;
  select coalesce(jsonb_agg(to_jsonb(o) order by o.slot_no,o.slot_generation),'[]'::jsonb)
    into v_personal from nexora.contract_offers o
    where o.scope='personal' and o.user_id=p_uid
      and (o.board_date=v_today or o.status in ('accepted','processing','ready'))
      and o.status in ('offered','accepted','processing','ready');
  select count(*) into v_active from nexora.contract_offers
    where scope='personal' and user_id=p_uid and status in ('accepted','processing','ready');
  select coalesce(personal_used_count,0),coalesce(org_used_count,0)
    into v_claims,v_org_claims from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today;
  if v_profile.org_id is not null then
    -- The profile, wallet and contract rows are already locked before the
    -- shared organization row, serializing board-slot generation safely.
    select * into v_org from nexora.organizations where id=v_profile.org_id for update;
    if found then
      perform nexora.ensure_org_weekly_goals(v_org.id);
      v_slots:=least(100,greatest(10,v_org.level*10));
      for v_slot in 1..v_slots loop
        if not exists(select 1 from nexora.contract_offers where scope='organization' and org_id=v_org.id
          and board_date=v_today and slot_no=v_slot and status in ('offered','accepted','processing','ready'))
          and (
            not exists(select 1 from nexora.contract_offers where scope='organization' and org_id=v_org.id
              and board_date=v_today and slot_no=v_slot)
            or exists(select 1 from nexora.contract_slot_cooldowns c
              where c.scope='organization' and c.owner_id=v_org.id and c.slot_no=v_slot
                and c.board_date=v_today and c.cooldown_until<=now())
          ) then
          perform nexora.generate_dynamic_contract('organization',null,v_org.id,v_slot,v_today,null,null,null);
        end if;
      end loop;
      select coalesce(jsonb_agg(to_jsonb(o) order by o.slot_no,o.slot_generation),'[]'::jsonb)
      into v_org_board from nexora.contract_offers o
      where o.scope='organization' and o.org_id=v_org.id
        and (o.board_date=v_today or o.status in ('accepted','processing','ready'))
        and o.status in ('offered','accepted','processing','ready');
    end if;
  end if;
  return jsonb_build_object('personal',coalesce(v_personal,'[]'::jsonb),
    'organization',coalesce(v_org_board,'[]'::jsonb),'organization_slots',coalesce(v_slots,0),'organization_max_slots',100,'active_personal',v_active,
    'daily_used',coalesce(v_claims,0),'daily_limit',5,
    'org_daily_used',coalesce(v_org_claims,0),'org_daily_limit',5,'offer_expires_at',v_end);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.get_manufacturing_job(p_uid text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce((
    select jsonb_build_object(
      'id', j.id,
      'recipe_id', j.recipe_id,
      'output_item_id', j.output_item_id,
      'output_qty', j.output_qty,
      'started_at', j.started_at,
      'ends_at', j.ends_at,
      'status', j.status
    )
    from nexora.manufacturing_jobs j
    where j.user_id = p_uid and j.status = 'running'
    order by j.created_at desc
    limit 1
  ), 'null'::jsonb);
$function$
;

CREATE OR REPLACE FUNCTION nexora.get_mission_progress(p_uid text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with bounds as (
    select
      date_trunc('day',now() at time zone 'UTC') at time zone 'UTC' as day_start,
      date_trunc('week',now() at time zone 'UTC') at time zone 'UTC' as week_start,
      date_trunc('quarter',now() at time zone 'UTC') at time zone 'UTC' as quarter_start
  ),
  activity as (
    select
      count(*) filter(where t.from_uid=p_uid and t.type='market_buy' and t.created_at>=b.day_start) as daily_market_buys,
      count(*) filter(where t.from_uid=p_uid and t.type='manufacturing' and t.created_at>=b.day_start) as daily_manufacturing,
      count(*) filter(where t.to_uid=p_uid and t.type='company_collect' and t.created_at>=b.day_start) as daily_company_collections,
      coalesce(sum(t.amount) filter(where t.from_uid=p_uid and t.type='market_buy' and t.created_at>=b.day_start),0) as daily_market_spend,
      count(*) filter(where t.from_uid=p_uid and t.type='market_buy' and t.created_at>=b.week_start) as weekly_market_buys,
      count(*) filter(where t.from_uid=p_uid and t.type='manufacturing' and t.created_at>=b.week_start) as weekly_manufacturing,
      count(*) filter(where t.to_uid=p_uid and t.type='company_collect' and t.created_at>=b.week_start) as weekly_company_collections,
      coalesce(sum(t.amount) filter(where t.from_uid=p_uid and t.type='market_buy' and t.created_at>=b.week_start),0) as weekly_market_spend,
      count(*) filter(where t.from_uid=p_uid and t.type='market_buy' and t.created_at>=b.quarter_start) as seasonal_market_buys,
      count(*) filter(where t.from_uid=p_uid and t.type='manufacturing' and t.created_at>=b.quarter_start) as seasonal_manufacturing,
      count(*) filter(where t.to_uid=p_uid and t.type='company_collect' and t.created_at>=b.quarter_start) as seasonal_company_collections,
      coalesce(sum(t.amount) filter(where t.from_uid=p_uid and t.type='market_buy' and t.created_at>=b.quarter_start),0) as seasonal_market_spend
    from nexora.transactions t
    cross join bounds b
    where t.status='completed'
      and (
        (t.from_uid=p_uid and t.type in ('market_buy','manufacturing') and t.created_at>=least(b.week_start,b.quarter_start))
        or (t.to_uid=p_uid and t.type='company_collect' and t.created_at>=least(b.week_start,b.quarter_start))
      )
  )
  select jsonb_build_object(
    'dailyTradesCount',daily_market_buys,
    'dailyManufacturingCount',daily_manufacturing,
    'dailyCompanyCollectionsCount',daily_company_collections,
    'dailyMarketSpend',daily_market_spend,
    'weeklyTradesCount',weekly_market_buys,
    'weeklyManufacturingCount',weekly_manufacturing,
    'weeklyCompanyCollectionsCount',weekly_company_collections,
    'weeklyMarketSpend',weekly_market_spend,
    'seasonalMarketBuys',seasonal_market_buys,
    'seasonalManufacturingCount',seasonal_manufacturing,
    'seasonalCompanyCollectionsCount',seasonal_company_collections,
    'seasonalMarketSpend',seasonal_market_spend,
    'companyRevenueTotal',(select coalesce(sum(amount),0) from nexora.transactions where to_uid=p_uid and type='company_collect' and status='completed')
  )
  from activity;
$function$
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.get_org_weekly_goals(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_org_id text;
  v_goals jsonb;
begin
  select org_id into v_org_id from nexora.player_profiles where user_id=p_uid;
  if v_org_id is null then raise exception 'NOT_IN_ORG'; end if;
  if not exists(select 1 from nexora.organization_members where org_id=v_org_id and user_id=p_uid) then
    raise exception 'UNAUTHORIZED';
  end if;
  perform nexora.ensure_org_weekly_goals(v_org_id);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',g.id,'type',g.goal_type,'difficulty',g.difficulty,'target',g.target_amount,
    'current',g.current_amount,'rewardReputation',g.reward_reputation,'status',g.status,
    'weekStart',g.week_start,'completedAt',g.completed_at,
    'contributions',coalesce((
      select jsonb_agg(jsonb_build_object('uid',c.user_id,'username',m.username,'amount',c.amount)
        order by c.amount desc,m.username)
      from nexora.org_goal_contributions c
      left join nexora.organization_members m on m.org_id=c.org_id and m.user_id=c.user_id
      where c.goal_id=g.id
    ),'[]'::jsonb)
  ) order by g.goal_type),'[]'::jsonb) into v_goals
  from nexora.org_weekly_goals g
  where g.org_id=v_org_id and g.week_start=date_trunc('week',timezone('UTC',now()))::date
    and g.goal_type<>'contracts_completed';
  return jsonb_build_object('weekStart',date_trunc('week',timezone('UTC',now()))::date,'goals',v_goals);
end;
$function$
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.guard_contract_slot_cooldown_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_owner_id text;
  v_until timestamptz;
begin
  v_owner_id:=case when new.scope='personal' then new.user_id else new.org_id end;
  if v_owner_id is null then return new; end if;

  select c.cooldown_until into v_until
  from nexora.contract_slot_cooldowns c
  where c.scope=new.scope and c.owner_id=v_owner_id
    and c.slot_no=new.slot_no
  order by c.cooldown_until desc limit 1
  for update;

  if v_until is not null and v_until>now() then return null; end if;

  if v_until is not null then
    delete from nexora.contract_slot_cooldowns c
    where c.scope=new.scope and c.owner_id=v_owner_id
      and c.slot_no=new.slot_no and c.cooldown_until<=now();
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.guard_player_achievement_claim_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'nexora'
AS $function$
begin
  if (to_jsonb(new) - 'claimed_at') is distinct from (to_jsonb(old) - 'claimed_at') then
    raise exception 'NEXORA immutable achievement records cannot be modified';
  end if;
  if old.claimed_at is not null and new.claimed_at is distinct from old.claimed_at then
    raise exception 'NEXORA achievement reward claim is immutable';
  end if;
  return new;
end;
$function$
;

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
;

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
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.list_blocked_players(p_user_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
 select jsonb_build_object('blockedUids',coalesce(jsonb_agg(target_uid),'[]'::jsonb))
 from user_blocks where owner_uid=p_user_id
$function$
;

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
;

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
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.list_global_chat_messages(p_user_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
 select jsonb_build_object('messages',coalesce(jsonb_agg(jsonb_build_object('id',m.id,'senderUid',m.sender_uid,'senderName',m.sender_name,'avatarId',m.avatar_id,'text',m.message_text,'createdAt',m.created_at) order by m.created_at),'[]'::jsonb))
 from (select * from global_chat_messages order by created_at desc limit 60) m
$function$
;

CREATE OR REPLACE FUNCTION nexora.list_organization_chat_messages(p_user_id text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_messages jsonb;
begin
  if p_org_id is null or not exists(
    select 1 from nexora.organization_members
    where org_id=p_org_id and user_id=p_user_id
  ) or not exists(
    select 1 from nexora.player_profiles
    where user_id=p_user_id and org_id=p_org_id
  ) then
    raise exception 'ORG_CHAT_ACCESS_DENIED';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',m.id,'senderUid',m.sender_uid,'senderName',m.sender_name,
    'text',m.message_text,'createdAt',m.created_at
  ) order by m.created_at),'[]'::jsonb)
  into v_messages
  from (
    select id,sender_uid,sender_name,message_text,created_at
    from nexora.organization_chat_messages
    where org_id=p_org_id
    order by created_at desc
    limit 80
  ) m;
  return jsonb_build_object('messages',v_messages);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.list_organization_invites(p_user_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
 select jsonb_build_object('invites',coalesce(jsonb_agg(jsonb_build_object('id',i.id,'orgId',i.org_id,'orgName',i.org_name,'orgTag',i.org_tag,'inviterName',i.inviter_name,'status',i.status,'targetUid',i.target_uid) order by i.created_at desc),'[]'::jsonb))
 from organization_invites i where i.target_uid=p_user_id and i.status='pending'
$function$
;

CREATE OR REPLACE FUNCTION nexora.manufacture_recipe(p_uid text, p_recipe_id text, p_batches integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_inputs jsonb;
  v_output text;
  v_output_qty integer;
  v_cost integer;
  v_xp integer;
  v_required integer;
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_item record;
  v_qty integer;
  v_discount numeric;
  v_unit_cost integer;
  v_total bigint;
  v_seconds integer;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_job text := 'mfg_' || gen_random_uuid()::text;
  v_ends timestamptz;
begin
  if p_batches is null or p_batches < 1 or p_batches > 999 then
    raise exception 'INVALID_QUANTITY';
  end if;

  case p_recipe_id
    when 'rec_microchips' then v_output:='microchips'; v_output_qty:=2; v_cost:=40; v_xp:=8; v_required:=0; v_inputs:='[{"itemId":"silicon_ore","qty":2},{"itemId":"copper_wire","qty":2}]'::jsonb;
    when 'rec_precision_frame' then v_output:='precision_frame'; v_output_qty:=2; v_cost:=50; v_xp:=9; v_required:=0; v_inputs:='[{"itemId":"crude_alloy","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    when 'rec_synth_polymer' then v_output:='synth_polymer'; v_output_qty:=2; v_cost:=60; v_xp:=10; v_required:=1; v_inputs:='[{"itemId":"energy_cells","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb;
    when 'rec_quantum_server' then v_output:='quantum_server'; v_output_qty:=1; v_cost:=90; v_xp:=12; v_required:=1; v_inputs:='[{"itemId":"microchips","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    when 'rec_logistics_drone' then v_output:='logistics_drone'; v_output_qty:=1; v_cost:=110; v_xp:=14; v_required:=2; v_inputs:='[{"itemId":"precision_frame","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    when 'rec_bio_module' then v_output:='bio_module'; v_output_qty:=1; v_cost:=125; v_xp:=15; v_required:=2; v_inputs:='[{"itemId":"synth_polymer","qty":2},{"itemId":"rare_minerals","qty":2}]'::jsonb;
    when 'rec_titanium_frame' then v_output:='precision_frame'; v_output_qty:=2; v_cost:=80; v_xp:=11; v_required:=1; v_inputs:='[{"itemId":"titanium_ore","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    when 'rec_polymer_composite' then v_output:='synth_polymer'; v_output_qty:=2; v_cost:=90; v_xp:=12; v_required:=1; v_inputs:='[{"itemId":"polymer_resin","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    when 'rec_biotech_module' then v_output:='bio_module'; v_output_qty:=1; v_cost:=320; v_xp:=16; v_required:=2; v_inputs:='[{"itemId":"biotech_gel","qty":2},{"itemId":"quantum_dust","qty":1}]'::jsonb; v_output_qty:=1; v_cost:=60; v_xp:=18; v_required:=3; v_inputs:='[{"itemId":"quantum_dust","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    else raise exception 'INVALID_RECIPE';
  end case;

  select * into v_profile from nexora.player_profiles where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if coalesce((v_profile.skills->>'industry')::integer, 0) < v_required then
    raise exception 'INDUSTRY_SKILL_TOO_LOW';
  end if;

  if exists (
    select 1 from nexora.manufacturing_jobs
    where user_id = p_uid and status = 'running'
  ) then raise exception 'MANUFACTURING_JOB_IN_PROGRESS'; end if;

  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_discount := least(0.45, greatest(0, coalesce((v_profile.skills->>'industry')::integer, 0)) * 0.06);
  v_unit_cost := greatest(10, round(v_cost * (1 - v_discount))::integer);
  v_total := v_unit_cost * p_batches;
  if v_wallet.balance < v_total then raise exception 'INSUFFICIENT_FUNDS'; end if;

  -- Aggregate repeated recipe inputs before checking and consuming them.
  -- This prevents duplicate item entries from validating against the same stock twice.
  for v_item in
    select value->>'itemId' as item_id, sum((value->>'qty')::integer)::integer as qty
    from jsonb_array_elements(v_inputs)
    group by value->>'itemId'
    order by value->>'itemId'
  loop
    select quantity into v_qty
    from nexora.inventory
    where user_id = p_uid and item_id = v_item.item_id
    for update;
    if not found or v_qty < v_item.qty * p_batches then raise exception 'MISSING_INPUTS'; end if;
  end loop;

  -- Intermediate goods take 30 seconds per output unit; final goods take 60 seconds.
  v_seconds := greatest(15, (case when v_output in ('quantum_server','logistics_drone','bio_module') then 60 else 30 end) * v_output_qty * p_batches);
  v_ends := now() + make_interval(secs => v_seconds);

  update nexora.wallets
  set balance = balance - v_total, total_spent = total_spent + v_total, last_tx_id = v_tx, updated_at = now()
  where user_id = p_uid;

  for v_item in
    select value->>'itemId' as item_id, sum((value->>'qty')::integer)::integer as qty
    from jsonb_array_elements(v_inputs)
    group by value->>'itemId'
    order by value->>'itemId'
  loop
    update nexora.inventory
    set quantity = quantity - v_item.qty * p_batches, updated_at = now()
    where user_id = p_uid and item_id = v_item.item_id;
  end loop;

  insert into nexora.manufacturing_jobs(
    id, user_id, recipe_id, output_item_id, output_qty, xp_reward, started_at, ends_at, status
  ) values (
    v_job, p_uid, p_recipe_id, v_output, v_output_qty * p_batches, v_xp * p_batches, now(), v_ends, 'running'
  );

  insert into nexora.transactions(id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status)
  values (
    v_tx, p_uid, 'SYSTEM', v_total, 0, v_total, 'manufacturing', p_recipe_id,
    'Started manufacturing ' || (v_output_qty * p_batches)::text || 'x ' || v_output || ' (' || p_batches::text || ' batches)',
    'completed'
  );

  return jsonb_build_object(
    'id', v_job, 'recipe_id', p_recipe_id, 'output_item_id', v_output,
    'output_qty', v_output_qty * p_batches, 'started_at', now(), 'ends_at', v_ends,
    'processing_seconds', v_seconds, 'status', 'running'
  );
end;
$function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.mark_company_vault_notification_claimed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.vault_balance<old.vault_balance
    or new.last_collected_at is distinct from old.last_collected_at
    or new.vault_level>old.vault_level then
    update nexora.notifications set is_read=true,event_key=null
    where user_id=new.owner_uid
      and (event_key like 'company-vault-full:'||new.id||':%'
        or (event_key is null and title in ('خزنة الشركة ممتلئة','Company vault is full')
          and body like '%'||new.name||'%'));
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.mark_daily_stipend_notification_claimed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update nexora.notifications set is_read=true,event_key=null
  where user_id=new.user_id
    and event_key like 'daily-stipend-ready:%'
    and is_read=false;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.mark_factory_warehouse_notification_claimed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.warehouse_qty<old.warehouse_qty or new.warehouse_level>old.warehouse_level then
    update nexora.notifications set is_read=true,event_key=null
    where user_id=new.owner_uid
      and (event_key like 'factory-warehouse-full:'||new.id||':%'
        or (event_key is null and title in ('مستودع المصنع ممتلئ','Factory warehouse is full')
          and body like '%'||new.name||'%'));
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.mark_mission_reward_notification_claimed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update nexora.notifications set is_read=true,event_key=null
  where user_id=new.user_id
    and event_key='mission-ready:'||new.mission_id||':'||new.period_key;
  return new;
end;
$function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.market_price_bounds(p_item_id text)
 RETURNS TABLE(min_price bigint, max_price bigint)
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select greatest(1, floor(prices.base_price * 0.5)::bigint),
         greatest(1, ceil(prices.base_price * 2)::bigint)
  from (values
    ('silicon_ore', 35::numeric), ('copper_wire', 28::numeric),
    ('energy_cells', 45::numeric), ('crude_alloy', 40::numeric),
    ('carbon_fiber', 55::numeric), ('rare_minerals', 70::numeric),
    ('titanium_ore', 85::numeric), ('polymer_resin', 95::numeric),
    ('biotech_gel', 120::numeric), ('quantum_dust', 160::numeric),
    ('microchips', 145::numeric), ('precision_frame', 175::numeric),
    ('synth_polymer', 190::numeric), ('quantum_server', 560::numeric),
    ('logistics_drone', 620::numeric), ('bio_module', 680::numeric)
  ) as prices(item_id, base_price)
  where prices.item_id = p_item_id
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_company_vault_full()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caps bigint[]:=array[3500,7000,14000,25000,40000];
  v_capacity bigint;
begin
  v_capacity:=v_caps[greatest(1,least(5,coalesce(new.vault_level,1)))];
  if coalesce(old.vault_balance,0)<v_capacity and coalesce(new.vault_balance,0)>=v_capacity then
    perform nexora.emit_notification_once(
      new.owner_uid,'company-vault-full:'||new.id||':'||new.vault_level||':'||coalesce(new.last_collected_at,new.created_at,now())::text,
      'خزنة الشركة ممتلئة','Company vault is full',
      'وصلت خزنة أرباح شركة «'||new.name||'» إلى سعتها القصوى. حصّل الإيرادات لتجنب ضياع الدخل القادم.',
      'The profit vault for "'||new.name||'" is full. Collect revenue so future income is not lost.','economy'
    );
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_daily_stipend_ready()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_player record;
  v_count integer:=0;
begin
  for v_player in select user_id from nexora.player_profiles order by user_id loop
    v_count:=v_count+nexora.notify_daily_stipend_ready_for_user(v_player.user_id);
  end loop;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_daily_stipend_ready_for_user(p_uid text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_date text:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
begin
  if exists(select 1 from nexora.daily_claims where user_id=p_uid and date_key=v_date) then
    return 0;
  end if;
  perform nexora.emit_notification_once(
    p_uid,'daily-stipend-ready:'||v_date,
    'التشغيل اليومي جاهز','Daily stipend ready',
    'مكافأة التشغيل اليومية جاهزة للاستلام.',
    'Your daily operating stipend is ready to claim.',
    'economy'
  );
  return 1;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_factory_warehouse_full()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_capacity bigint;
  v_event_key text;
begin
  v_capacity:=nexora.factory_warehouse_capacity(new.resource_id,new.warehouse_level);
  v_event_key:='factory-warehouse-full:'||new.id||':'||new.warehouse_level;
  if coalesce(new.warehouse_qty,0)<v_capacity then
    delete from nexora.notification_events
    where user_id=new.owner_uid and event_key=v_event_key;
  elsif coalesce(old.warehouse_qty,0)<v_capacity and coalesce(new.warehouse_qty,0)>=v_capacity then
    perform nexora.emit_notification_once(
      new.owner_uid,v_event_key,
      'مستودع المصنع ممتلئ','Factory warehouse is full',
      'امتلأ مستودع مصنع «'||new.name||'». اسحب الموارد إلى مخزونك أو وسّع المستودع لاستئناف الإنتاج.',
      'The warehouse for "'||new.name||'" is full. Withdraw resources or expand the warehouse to resume production.','economy'
    );
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_full_company_vaults()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_company record;
  v_caps bigint[]:=array[3500,7000,14000,25000,40000];
  v_capacity bigint;
  v_elapsed numeric;
  v_hourly bigint;
  v_balance bigint;
  v_count integer:=0;
begin
  for v_company in
    select id,owner_uid,name,vault_level,vault_balance,last_collected_at,created_at
    from nexora.companies
    where is_deleted=false
    order by id
  loop
    v_capacity:=v_caps[greatest(1,least(5,coalesce(v_company.vault_level,1)))];
    v_elapsed:=least(12,greatest(0,extract(epoch from (now()-coalesce(v_company.last_collected_at,v_company.created_at)))/3600));
    v_hourly:=greatest(0,nexora.company_net_hourly(v_company.id));
    v_balance:=least(v_capacity,coalesce(v_company.vault_balance,0)
      + floor(v_hourly*v_elapsed)::bigint);
    if v_balance>=v_capacity then
      perform nexora.emit_notification_once(
        v_company.owner_uid,
        'company-vault-full:'||v_company.id||':'||v_company.vault_level||':'||coalesce(v_company.last_collected_at,v_company.created_at,now())::text,
        'خزنة الشركة ممتلئة','Company vault is full',
        'وصلت خزنة أرباح شركة «'||v_company.name||'» إلى سعتها القصوى. حصّل الإيرادات لتجنب ضياع الدخل القادم.',
        'The profit vault for "'||v_company.name||'" is full. Collect revenue so future income is not lost.','economy'
      );
      v_count:=v_count+1;
    end if;
  end loop;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_full_factory_warehouses()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_factory record;
  v_count integer:=0;
begin
  for v_factory in
    select id,owner_uid,name,resource_id,warehouse_level,warehouse_qty
    from nexora.factories
    where warehouse_qty>=nexora.factory_warehouse_capacity(resource_id,warehouse_level)
    order by id
  loop
    perform nexora.emit_notification_once(
      v_factory.owner_uid,'factory-warehouse-full:'||v_factory.id||':'||v_factory.warehouse_level,
      'مستودع المصنع ممتلئ','Factory warehouse is full',
      'امتلأ مستودع مصنع «'||v_factory.name||'». اسحب الموارد إلى مخزونك أو وسّع المستودع لاستئناف الإنتاج.',
      'The warehouse for "'||v_factory.name||'" is full. Withdraw resources or expand the warehouse to resume production.','economy'
    );
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_ready_contracts(p_uid text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_contract record;
  v_count integer:=0;
begin
  for v_contract in
    select id from nexora.contract_offers
    where status='ready'
      and ((scope='personal' and user_id=p_uid)
        or (scope='organization' and claimed_by=p_uid))
    order by created_at,id
  loop
    perform nexora.emit_notification_once(
      p_uid,'contract-ready:'||v_contract.id,
      'العقد جاهز للاستلام','Contract ready to claim',
      'أصبحت مكافأة أحد عقودك جاهزة للاستلام.','A contract reward is ready to claim.','economy'
    );
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_ready_missions(p_uid text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_progress jsonb;
  v_mission record;
  v_period text;
  v_value bigint;
  v_notified integer:=0;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid;
  if not found then return 0; end if;
  v_progress:=nexora.get_mission_progress(p_uid);

  for v_mission in
    select * from (values
      ('tut_first_trade','tutorial','trades',1::bigint,'دخول السوق','Enter the Market'),
      ('tut_first_production','tutorial','produced',1::bigint,'بداية الإنتاج','First Production'),
      ('tut_first_company','tutorial','companies',1::bigint,'تأسيس الشركة','Found Your Company'),
      ('daily_market_orders','daily','dailyTradesCount',5::bigint,'نشاط السوق','Market Activity'),
      ('daily_factory_shift','daily','dailyManufacturingCount',3::bigint,'وردية إنتاج','Production Shift'),
      ('daily_market_volume','daily','dailyMarketSpend',2500::bigint,'حركة رأس المال','Capital in Motion'),
      ('daily_company_cycle','daily','dailyCompanyCollectionsCount',2::bigint,'دورة تشغيل','Operating Cycle'),
      ('weekly_market_network','weekly','weeklyTradesCount',35::bigint,'شبكة التوريد','Supply Network'),
      ('weekly_industrial_output','weekly','weeklyManufacturingCount',25::bigint,'إنتاج متواصل','Sustained Output'),
      ('weekly_capital_flow','weekly','weeklyMarketSpend',30000::bigint,'تدفق استثماري','Investment Flow'),
      ('weekly_corporate_returns','weekly','weeklyCompanyCollectionsCount',12::bigint,'عوائد مؤسسية','Corporate Returns'),
      ('seasonal_market_leadership','seasonal','seasonalMarketBuys',250::bigint,'قيادة السوق','Market Leadership'),
      ('seasonal_industry_scale','seasonal','seasonalManufacturingCount',180::bigint,'توسع صناعي','Industrial Scale'),
      ('seasonal_capital_commitment','seasonal','seasonalMarketSpend',500000::bigint,'التزام رأسمالي','Capital Commitment'),
      ('seasonal_corporate_scale','seasonal','seasonalCompanyCollectionsCount',75::bigint,'إدارة المحافظ','Portfolio Management')
    ) as missions(mission_id,category,metric,target,title_ar,title_en)
  loop
    v_period:=case v_mission.category
      when 'daily' then to_char(now() at time zone 'UTC','YYYY-MM-DD')
      when 'weekly' then to_char(now() at time zone 'UTC','IYYY-"W"IW')
      when 'seasonal' then to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text
      else 'lifetime'
    end;

    v_value:=case v_mission.metric
      when 'trades' then coalesce((v_profile.stats->>'tradesCount')::bigint,0)
      when 'produced' then coalesce((v_profile.stats->>'totalProduced')::bigint,0)
      when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::bigint,0)
      when 'org' then case when v_profile.org_id is null then 0 else 1 end
      else coalesce((v_progress->>v_mission.metric)::bigint,0)
    end;

    if v_value>=v_mission.target and not exists(
      select 1 from nexora.player_missions pm
      where pm.user_id=p_uid and pm.mission_id=v_mission.mission_id and pm.period_key=v_period
    ) then
      perform nexora.emit_notification_once(
        p_uid,'mission-ready:'||v_mission.mission_id||':'||v_period,
        'مكافأة مهمة جاهزة','Mission reward ready',
        'أكملت مهمة «'||v_mission.title_ar||'» ويمكنك استلام مكافأتها الآن.',
        'You completed "'||v_mission.title_en||'". Its reward is ready to claim.','mission'
      );
      v_notified:=v_notified+1;
    end if;
  end loop;
  return v_notified;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_ready_missions_after_profile_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.stats is distinct from old.stats or new.org_id is distinct from old.org_id then
    perform nexora.notify_ready_missions(new.user_id);
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.notify_ready_missions_after_transaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text;
begin
  if new.status<>'completed' then return new; end if;
  v_uid:=case when new.type='company_collect' then new.to_uid else new.from_uid end;
  if v_uid is not null and v_uid<>'SYSTEM' and new.type in ('market_buy','manufacturing','company_collect') then
    perform nexora.notify_ready_missions(v_uid);
  end if;
  return new;
end;
$function$
;

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
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.player_inventory_capacity(p_level integer)
 RETURNS bigint
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select 250::bigint + 15::bigint * greatest(0, least(199, coalesce(p_level, 1) - 1));
$function$
;

CREATE OR REPLACE FUNCTION nexora.player_inventory_usage(p_uid text)
 RETURNS bigint
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    coalesce((select sum(i.quantity) from nexora.inventory i where i.user_id=p_uid),0)
    + coalesce((select sum(l.remaining_qty) from nexora.market_listings l
      where l.seller_uid=p_uid and l.status='active' and l.remaining_qty>0),0);
$function$
;

CREATE OR REPLACE FUNCTION nexora.prepare_manufacturing_job()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  -- There must be exactly one player-facing recipe for Quantum Server.
  if new.recipe_id = 'rec_quantum_server_advanced' then
    raise exception 'INVALID_RECIPE';
  end if;

  if new.input_snapshot is null or new.input_snapshot = '[]'::jsonb then
    new.input_snapshot := case new.recipe_id
      when 'rec_microchips' then '[{"itemId":"silicon_ore","qty":2},{"itemId":"copper_wire","qty":2}]'::jsonb
      when 'rec_precision_frame' then '[{"itemId":"crude_alloy","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb
      when 'rec_synth_polymer' then '[{"itemId":"energy_cells","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb
      when 'rec_quantum_server' then '[{"itemId":"microchips","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb
      when 'rec_logistics_drone' then '[{"itemId":"precision_frame","qty":2},{"itemId":"microchips","qty":1}]'::jsonb
      when 'rec_bio_module' then '[{"itemId":"synth_polymer","qty":2},{"itemId":"rare_minerals","qty":2}]'::jsonb
      when 'rec_titanium_frame' then '[{"itemId":"titanium_ore","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb
      when 'rec_polymer_composite' then '[{"itemId":"polymer_resin","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb
      when 'rec_biotech_module' then '[{"itemId":"biotech_gel","qty":2},{"itemId":"quantum_dust","qty":1}]'::jsonb
      else '[]'::jsonb
    end;
  end if;

  if jsonb_typeof(new.input_snapshot) <> 'array' or jsonb_array_length(new.input_snapshot) = 0 then
    raise exception 'INVALID_RECIPE';
  end if;

  if new.recipe_id in ('rec_microchips','rec_precision_frame','rec_synth_polymer','rec_titanium_frame','rec_polymer_composite') then
    if new.output_qty % 2 <> 0 then raise exception 'INVALID_MANUFACTURING_OUTPUT'; end if;
    new.batch_count := greatest(1, new.output_qty / 2);
  else
    new.batch_count := greatest(1, new.output_qty);
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_company_founding()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform nexora.record_org_goal_progress(new.owner_uid,'companies_founded',1);
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_company_revenue()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_delta numeric;
begin
  v_delta:=new.total_revenue-old.total_revenue;
  if v_delta>0 then perform nexora.record_org_goal_progress(new.owner_uid,'company_revenue',v_delta); end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_company_upgrade()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.level>old.level then perform nexora.record_org_goal_progress(new.owner_uid,'company_upgrades',1); end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_factory()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_delta numeric;
begin
  v_delta:=new.warehouse_qty-old.warehouse_qty;
  if v_delta>0 then perform nexora.record_org_goal_progress(new.owner_uid,'produce_units',v_delta); end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_factory_founding()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform nexora.record_org_goal_progress(new.owner_uid,'factories_founded',1);
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_factory_upgrade()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.level>old.level then perform nexora.record_org_goal_progress(new.owner_uid,'factory_upgrades',1); end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_market_order()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform nexora.record_org_goal_progress(new.buyer_uid,'trade_volume',new.total_price);
  if new.seller_uid is not null and new.seller_uid is distinct from new.buyer_uid then
    perform nexora.record_org_goal_progress(new.seller_uid,'trade_volume',new.total_price);
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_org_transaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.type='deposit' then
    perform nexora.record_org_goal_progress(new.user_id,'treasury_donations',new.amount);
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_from_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_delta numeric;
begin
  v_delta:=coalesce((new.stats->>'totalProduced')::numeric,0)-coalesce((old.stats->>'totalProduced')::numeric,0);
  if v_delta>0 then perform nexora.record_org_goal_progress(new.user_id,'produce_units',v_delta); end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.record_org_goal_progress(p_uid text, p_type text, p_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_org_id text;
  v_org nexora.organizations%rowtype;
  v_week date := date_trunc('week',timezone('UTC',now()))::date;
  v_goal nexora.org_weekly_goals%rowtype;
  v_new numeric;
  v_completed integer:=0;
begin
  if p_type not in ('produce_units','trade_volume','contracts_completed','treasury_donations','personal_contracts_completed','org_contracts_completed','company_revenue','factory_upgrades','company_upgrades','companies_founded','factories_founded')
     or p_amount is null or p_amount<=0 then
    return jsonb_build_object('ok',true,'recorded',false);
  end if;
  select org_id into v_org_id from nexora.player_profiles where user_id=p_uid;
  if v_org_id is null then return jsonb_build_object('ok',true,'recorded',false); end if;
  select * into v_org from nexora.organizations where id=v_org_id for update;
  if not found then return jsonb_build_object('ok',true,'recorded',false); end if;
  perform nexora.ensure_org_weekly_goals(v_org_id);
  for v_goal in
    select * from nexora.org_weekly_goals
    where org_id=v_org_id and week_start=v_week and goal_type=p_type and status='active'
    for update
  loop
    insert into nexora.org_goal_contributions(id,goal_id,org_id,user_id,amount)
    values('ogc_'||gen_random_uuid()::text,v_goal.id,v_org_id,p_uid,p_amount)
    on conflict(goal_id,user_id) do update
      set amount=nexora.org_goal_contributions.amount+excluded.amount,updated_at=now();
    v_new:=least(v_goal.target_amount,v_goal.current_amount+p_amount);
    update nexora.org_weekly_goals set current_amount=v_new,
      status=case when v_new>=target_amount then 'completed' else 'active' end,
      completed_at=case when v_new>=target_amount then now() else null end
    where id=v_goal.id and status='active';
    if v_new>=v_goal.target_amount then
      update nexora.organizations set reputation=reputation+v_goal.reward_reputation,updated_at=now()
      where id=v_org_id;
      v_completed:=v_completed+1;
    end if;
  end loop;
  return jsonb_build_object('ok',true,'completed',v_completed);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.refresh_dynamic_contract(p_uid text, p_contract_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_owner text;
  v_today date := (now() at time zone 'UTC')::date;
  v_limit integer;
  v_used integer;
  v_until timestamptz := now() + interval '15 minutes';
begin
  select * into v_profile from nexora.player_profiles
  where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers
  where id=p_contract_id for update;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  if v_contract.status <> 'offered' then raise exception 'CONTRACT_NOT_REFRESHABLE'; end if;
  if v_contract.board_date <> v_today then raise exception 'CONTRACT_NOT_REFRESHABLE'; end if;

  if v_contract.scope='personal' then
    if v_contract.user_id is distinct from p_uid then raise exception 'UNAUTHORIZED'; end if;
    v_owner := p_uid;
    v_limit := 3;
  else
    if v_profile.org_id is distinct from v_contract.org_id then raise exception 'UNAUTHORIZED'; end if;
    if not exists (
      select 1 from nexora.organization_members
      where org_id=v_contract.org_id and user_id=p_uid and role in ('leader','deputy')
    ) then raise exception 'ORG_REFRESH_PERMISSION_REQUIRED'; end if;
    v_owner := v_contract.org_id;
    v_limit := 5;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    'contract-refresh:'||v_contract.scope||':'||v_owner||':'||v_today::text,0
  ));
  insert into nexora.contract_slot_refresh_usage(scope,owner_id,date_key,used_count)
  values(v_contract.scope,v_owner,v_today,0)
  on conflict(scope,owner_id,date_key) do nothing;

  select used_count into v_used
  from nexora.contract_slot_refresh_usage
  where scope=v_contract.scope and owner_id=v_owner and date_key=v_today
  for update;
  if v_used >= v_limit then raise exception 'CONTRACT_REFRESH_LIMIT_REACHED'; end if;

  update nexora.contract_slot_refresh_usage
  set used_count=used_count+1,updated_at=now()
  where scope=v_contract.scope and owner_id=v_owner and date_key=v_today;

  update nexora.contract_offers
  set status='abandoned',completed_at=now(),updated_at=now()
  where id=p_contract_id;

  if v_contract.scope='organization' then
    insert into nexora.contract_slot_cooldowns(scope,owner_id,slot_no,board_date,cooldown_until,updated_at)
    values('organization',v_contract.org_id,v_contract.slot_no,v_contract.board_date,v_until,now())
    on conflict(scope,owner_id,slot_no,board_date)
    do update set cooldown_until=greatest(nexora.contract_slot_cooldowns.cooldown_until,excluded.cooldown_until),
      updated_at=now();
  end if;

  return jsonb_build_object(
    'ok',true,'scope',v_contract.scope,'slot_no',v_contract.slot_no,
    'cooldown_until',v_until,'refreshes_used',v_used+1,'refreshes_limit',v_limit
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.reject_immutable_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'nexora'
AS $function$
begin
  raise exception 'NEXORA immutable records cannot be updated or deleted';
end;
$function$
;

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
;

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
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.restock_system_raw_market()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_today date := (now() at time zone 'UTC')::date;
  v_item record;
  v_refreshed integer := 0;
begin
  insert into nexora.market_system_restock_runs(restock_date)
  values(v_today)
  on conflict(restock_date) do nothing;
  if not found then return 0; end if;

  for v_item in
    select * from (values
      ('silicon_ore'::text,35::bigint),
      ('copper_wire',28),
      ('energy_cells',45),
      ('crude_alloy',40),
      ('carbon_fiber',55),
      ('rare_minerals',70)
    ) as raw(item_id,unit_price)
  loop
    update nexora.market_listings
    set seller_name='NEXORA CITY',
        quantity=250,
        remaining_qty=250,
        unit_price=v_item.unit_price,
        status='active',
        updated_at=now()
    where id='seed_' || v_item.item_id
      and seller_uid='SYSTEM';

    if not found then
      insert into nexora.market_listings(
        id,seller_uid,seller_name,item_id,quantity,remaining_qty,unit_price,status
      ) values (
        'seed_' || v_item.item_id,'SYSTEM','NEXORA CITY',
        v_item.item_id,250,250,v_item.unit_price,'active'
      );
    end if;

    update nexora.market_listings
    set status='cancelled',remaining_qty=0,updated_at=now()
    where seller_uid='SYSTEM'
      and seller_name='NOVA Exchange'
      and id like 'sys_%'
      and item_id=v_item.item_id
      and status='active';

    v_refreshed := v_refreshed + 1;
  end loop;

  return v_refreshed;
end
$function$
;

CREATE OR REPLACE FUNCTION nexora.rotate_world_events(p_now timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_templates jsonb := jsonb_build_array(
    jsonb_build_object('id','evt_silicon_boom','title_ar','طفرة الطلب على الرقائق','title_en','Silicon & Microchip Demand Surge','description_ar','ارتفاع الطلب العالمي على أشباه الموصلات يرفع تقييم الرقائق (+18%) وعوائد شركات التقنية (+15%).','description_en','Global semiconductor demand boosts Microchip index (+18%) and Tech company yields (+15%).','effect_type','demand_surge','target_item_id','microchips','affected_sectors',jsonb_build_array('tech'),'price_multiplier',1.18,'revenue_multiplier',1.15,'tax_delta',0,'stack_group','sector_tech','duration_hours',24,'event_class','positive'),
    jsonb_build_object('id','evt_raw_shortage','title_ar','شح المعادن والخامات','title_en','Raw Material Supply Squeeze','description_ar','تباطؤ الإمدادات العالمية يرفع قيمة خام السيليكون (+22%) ويضغط على هوامش التصنيع (-6%).','description_en','Global extraction bottleneck elevates Silicon Ore value (+22%) while tightening factory margins (-6%).','effect_type','supply_shortage','target_item_id','silicon_ore','affected_sectors',jsonb_build_array('manufacturing'),'price_multiplier',1.22,'revenue_multiplier',0.94,'tax_delta',0.01,'stack_group','supply_raw','duration_hours',18,'event_class','positive'),
    jsonb_build_object('id','evt_industrial_surge','title_ar','ذروة الطلب الصناعي','title_en','Industrial Compute Expansion','description_ar','موجة توسع في مراكز البيانات ترفع قيمة الخادم الكمومي (+15%) وعائد قطاعي التصنيع والتقنية (+18%).','description_en','Data-center expansion lifts Quantum Server prices (+15%) and Tech/Manufacturing output (+18%).','effect_type','industrial_boom','target_item_id','quantum_server','affected_sectors',jsonb_build_array('manufacturing','tech'),'price_multiplier',1.15,'revenue_multiplier',1.18,'tax_delta',0,'stack_group','sector_industry','duration_hours',24,'event_class','positive'),
    jsonb_build_object('id','evt_service_crisis','title_ar','تباطؤ قطاع الخدمات','title_en','Service Sector Contraction','description_ar','انخفاض مؤقت في الإنفاق المؤسسي يخفض عوائد قطاعي الخدمات والتجارة (-15%) ويرفع الرسوم 1%.','description_en','Temporary corporate spending pullback trims Services & Trade yields (-15%) and nudges fees +1%.','effect_type','service_crisis','target_item_id','','affected_sectors',jsonb_build_array('services','trade'),'price_multiplier',0.92,'revenue_multiplier',0.85,'tax_delta',0.01,'stack_group','macro_demand','duration_hours',12,'event_class','negative'),
    jsonb_build_object('id','evt_tax_holiday','title_ar','حافز التجارة الحرة','title_en','Free Trade Tax Incentive','description_ar','خفض مؤقت لضريبة معاملات السوق بمقدار 1% مع دفعة تشجيعية لقطاع التجارة (+8%).','description_en','Temporary 1% market transaction tax cut with a +8% Trade sector liquidity boost.','effect_type','tax_cut','target_item_id','','affected_sectors',jsonb_build_array('trade'),'price_multiplier',1.0,'revenue_multiplier',1.08,'tax_delta',-0.01,'stack_group','fiscal_policy','duration_hours',24,'event_class','positive'),
    jsonb_build_object('id','evt_logistics_boom','title_ar','ازدهار النقل والإمداد','title_en','Global Logistics & Freight Boom','description_ar','تسارع حركة الشحن العالمية يرفع قيمة طائرات الشحن (+14%) وعوائد النقل والتجارة (+16%).','description_en','Surging freight corridors boost Logistics Drone valuations (+14%) and Logistics/Trade output (+16%).','effect_type','logistics_boom','target_item_id','logistics_drone','affected_sectors',jsonb_build_array('logistics','trade'),'price_multiplier',1.14,'revenue_multiplier',1.16,'tax_delta',0,'stack_group','sector_logistics','duration_hours',24,'event_class','positive'),
    jsonb_build_object('id','evt_global_recession','title_ar','ركود اقتصادي عالمي','title_en','Global Economic Recession','description_ar','انكماش حاد في الطلب العالمي يخفض مؤشر الرقائق إلى 60% ويقلص عوائد قطاعات الاقتصاد.','description_en','A sharp global demand contraction cuts the Microchip market index to 60% and reduces company yields across sectors.','effect_type','economic_recession','target_item_id','microchips','affected_sectors',jsonb_build_array('trade','manufacturing','services','tech','logistics'),'price_multiplier',0.6,'revenue_multiplier',0.72,'tax_delta',0.01,'stack_group','macro_demand','duration_hours',12,'event_class','negative'),
    jsonb_build_object('id','evt_raw_material_glut','title_ar','تخمة المعروض من الخامات','title_en','Raw Material Supply Glut','description_ar','وفرة مفاجئة في المعروض تضغط على أسعار خام السيليكون إلى 70% وتضعف عوائد التصنيع.','description_en','A sudden supply glut pushes Silicon Ore prices to 70% and softens manufacturing yields.','effect_type','supply_glut','target_item_id','silicon_ore','affected_sectors',jsonb_build_array('manufacturing'),'price_multiplier',0.7,'revenue_multiplier',0.88,'tax_delta',0,'stack_group','supply_raw','duration_hours',12,'event_class','negative'),
    jsonb_build_object('id','evt_logistics_disruption','title_ar','تعطل سلاسل الإمداد','title_en','Global Logistics Disruption','description_ar','تعطل الشحن يرفع تكاليف التشغيل ويخفض عوائد قطاعي النقل والتجارة إلى 75%.','description_en','Shipping disruption increases operating pressure and cuts Logistics and Trade yields to 75%.','effect_type','logistics_disruption','target_item_id','logistics_drone','affected_sectors',jsonb_build_array('logistics','trade'),'price_multiplier',0.82,'revenue_multiplier',0.75,'tax_delta',0.01,'stack_group','sector_logistics','duration_hours',10,'event_class','negative')
  );
  v_rotation_index bigint := floor(extract(epoch from p_now) / 21600)::bigint;
  v_negative_window boolean;
  v_negative_count integer;
  v_positive_count integer;
  v_offset integer;
  v_negative_tpl jsonb;
  v_positive_candidates jsonb := '[]'::jsonb;
  v_candidates jsonb := '[]'::jsonb;
  v_tpl jsonb;
  v_event record;
  v_kept_ids text[] := array[]::text[];
  v_kept_groups text[] := array[]::text[];
  v_expired_ids text[] := array[]::text[];
  v_slots_needed integer;
  v_negative_active boolean := false;
  v_activated integer := 0;
  v_deactivated integer := 0;
  v_id text;
  v_group text;
  v_is_negative boolean;
begin
  select coalesce(array_agg(id),array[]::text[]) into v_expired_ids
  from nexora.world_events where active=true and ends_at<=p_now;
  update nexora.world_events set active=false
  where active=true and ends_at<=p_now;
  v_deactivated := cardinality(v_expired_ids);

  for v_event in
    select id,effect_type,coalesce(stack_group,id) as stack_group
    from nexora.world_events
    where active=true and ends_at>p_now
    order by starts_at,id
  loop
    if cardinality(v_kept_ids)<3 and not (v_event.stack_group=any(v_kept_groups)) then
      v_kept_ids:=array_append(v_kept_ids,v_event.id);
      v_kept_groups:=array_append(v_kept_groups,v_event.stack_group);
      if v_event.effect_type in ('service_crisis','economic_recession','supply_glut','logistics_disruption') then
        v_negative_active:=true;
      end if;
    else
      update nexora.world_events set active=false where id=v_event.id and active=true;
      v_deactivated:=v_deactivated+1;
    end if;
  end loop;

  v_slots_needed:=greatest(0,3-cardinality(v_kept_ids));
  v_negative_window:=mod(v_rotation_index,5)=4;

  if v_slots_needed>0 then
    select count(*) into v_positive_count
    from jsonb_array_elements(v_templates) t(value)
    where value->>'event_class'='positive';
    select count(*) into v_negative_count
    from jsonb_array_elements(v_templates) t(value)
    where value->>'event_class'='negative';

    if v_negative_window and not v_negative_active and v_negative_count>0 then
      select value into v_negative_tpl
      from jsonb_array_elements(v_templates) with ordinality as t(value,ordinality)
      where value->>'event_class'='negative'
      order by ordinality
      offset mod((v_rotation_index/5),v_negative_count)::integer
      limit 1;
      if v_negative_tpl is not null then
        if (v_negative_tpl->>'id')=any(v_expired_ids) then
          v_candidates:=v_candidates || '[]'::jsonb;
        else
          v_candidates:=v_candidates || jsonb_build_array(v_negative_tpl);
        end if;
      end if;
    end if;

    v_offset:=mod(v_rotation_index,greatest(1,v_positive_count))::integer;
    select coalesce(jsonb_agg(value order by
      case when (value->>'id')=any(v_expired_ids) then 1 else 0 end,
      mod((ordinality-1-v_offset+v_positive_count),greatest(1,v_positive_count))
    ),'[]'::jsonb) into v_positive_candidates
    from jsonb_array_elements(v_templates) with ordinality as t(value,ordinality)
    where value->>'event_class'='positive';
    v_candidates:=v_candidates || v_positive_candidates;

    if v_negative_window and not v_negative_active and v_negative_tpl is not null
      and (v_negative_tpl->>'id')=any(v_expired_ids) then
      v_candidates:=v_candidates || jsonb_build_array(v_negative_tpl);
    end if;

    for v_tpl in select value from jsonb_array_elements(v_candidates) as c(value)
    loop
      exit when v_activated>=v_slots_needed;
      v_id:=v_tpl->>'id';
      v_group:=v_tpl->>'stack_group';
      v_is_negative:=v_tpl->>'event_class'='negative';
      if v_id=any(v_kept_ids) or v_group=any(v_kept_groups) then continue; end if;
      if v_is_negative and v_negative_active then continue; end if;

      insert into nexora.world_events(
        id,title_ar,title_en,description_ar,description_en,effect_type,target_item_id,
        affected_sectors,price_multiplier,revenue_multiplier,tax_delta,stack_group,
        starts_at,ends_at,active
      ) values (
        v_id,v_tpl->>'title_ar',v_tpl->>'title_en',v_tpl->>'description_ar',v_tpl->>'description_en',
        v_tpl->>'effect_type',coalesce(v_tpl->>'target_item_id',''),
        v_tpl->'affected_sectors',(v_tpl->>'price_multiplier')::numeric,
        (v_tpl->>'revenue_multiplier')::numeric,(v_tpl->>'tax_delta')::numeric,
        v_group,p_now,p_now+make_interval(hours=>(v_tpl->>'duration_hours')::integer),true
      )
      on conflict(id) do update set
        title_ar=excluded.title_ar,title_en=excluded.title_en,
        description_ar=excluded.description_ar,description_en=excluded.description_en,
        effect_type=excluded.effect_type,target_item_id=excluded.target_item_id,
        affected_sectors=excluded.affected_sectors,price_multiplier=excluded.price_multiplier,
        revenue_multiplier=excluded.revenue_multiplier,tax_delta=excluded.tax_delta,
        stack_group=excluded.stack_group,starts_at=excluded.starts_at,
        ends_at=excluded.ends_at,active=true;

      v_kept_ids:=array_append(v_kept_ids,v_id);
      v_kept_groups:=array_append(v_kept_groups,v_group);
      if v_is_negative then v_negative_active:=true; end if;
      v_activated:=v_activated+1;
    end loop;
  end if;

  return jsonb_build_object(
    'active_count',cardinality(v_kept_ids),
    'activated_count',v_activated,
    'deactivated_count',v_deactivated,
    'negative_window',v_negative_window
  );
end;
$function$
;

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
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.send_organization_chat_message(p_user_id text, p_org_id text, p_text text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_message text;
  v_message_id text;
  v_rate_id text;
begin
  if p_request_id is null or p_org_id is null then raise exception 'INVALID_REQUEST'; end if;
  select * into v_profile from nexora.player_profiles
  where user_id=p_user_id and org_id=p_org_id;
  if not found or not exists(
    select 1 from nexora.organization_members
    where org_id=p_org_id and user_id=p_user_id
  ) then
    raise exception 'ORG_CHAT_ACCESS_DENIED';
  end if;

  v_message:=left(trim(regexp_replace(regexp_replace(coalesce(p_text,''),'[<>]','','g'),'[[:space:]]+',' ','g')),280);
  if v_message='' then raise exception 'EMPTY_MESSAGE'; end if;

  v_message_id:='orgmsg_'||p_user_id||'_'||p_request_id::text;
  if exists(select 1 from nexora.organization_chat_messages where id=v_message_id and sender_uid=p_user_id and org_id=p_org_id) then
    return jsonb_build_object('ok',true,'replayed',true);
  end if;

  insert into nexora.chat_rate_limits(id,last_sent_at)
  values('orgchat_'||p_user_id,now())
  on conflict(id) do update set last_sent_at=excluded.last_sent_at
  where nexora.chat_rate_limits.last_sent_at<=now()-interval '3 seconds'
  returning id into v_rate_id;
  if v_rate_id is null then raise exception 'CHAT_RATE_LIMIT'; end if;

  insert into nexora.organization_chat_messages(id,org_id,sender_uid,sender_name,message_text)
  values(v_message_id,p_org_id,p_user_id,v_profile.username,v_message);
  return jsonb_build_object('ok',true);
end;
$function$
;

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
  if coalesce(p_active,false)=false then raise exception 'FACTORY_ALWAYS_AUTOMATIC'; end if;
  update nexora.factories set is_active=true,last_produced_at=now(),updated_at=now() where id=p_factory_id;
  return jsonb_build_object('ok',true,'is_active',true);
end
$function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.settle_dynamic_contracts(p_uid text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_row nexora.contract_offers%rowtype;
  v_count integer:=0;
  v_today date:=(now() at time zone 'UTC')::date;
begin
  -- Ready transitions are persisted on every contract RPC, not inferred by the client.
  for v_row in
    select * from nexora.contract_offers
    where ((scope='personal' and user_id=p_uid) or (scope='organization' and claimed_by=p_uid))
      and status='processing' and ready_at<=now()
    order by id for update
  loop
    update nexora.contract_offers set status='ready',updated_at=now() where id=v_row.id and status='processing';
    perform nexora.emit_notification_once(
      p_uid,'contract-ready:'||v_row.id,
      'العقد جاهز للاستلام','Contract ready to claim',
      'انتهت معالجة عقدك وأصبحت المكافأة جاهزة للاستلام.','Your contract has finished processing and its reward is ready to claim.','economy'
    );
  end loop;
  for v_row in
    select * from nexora.contract_offers
    where ((scope='personal' and user_id=p_uid) or
      (scope='organization' and (claimed_by=p_uid or org_id=(select org_id from nexora.player_profiles where user_id=p_uid))))
      and ((status='offered' and offer_expires_at<=now())
        or (status='offered' and event_id is not null and not exists(
          select 1 from nexora.world_events e where e.id=contract_offers.event_id
            and e.active=true and e.starts_at<=now() and e.ends_at>now()))
        or (status='accepted' and deadline_at<=now()))
    order by id for update
  loop
    update nexora.contract_offers set status='expired',updated_at=now() where id=v_row.id;
    v_count:=v_count+1;
    if v_row.scope='personal' and v_row.board_date=v_today and not exists(select 1 from nexora.contract_offers replacement
        where replacement.scope=v_row.scope and replacement.board_date=v_today
          and replacement.slot_no=v_row.slot_no and replacement.status='offered'
          and ((v_row.scope='personal' and replacement.user_id=v_row.user_id)
            or (v_row.scope='organization' and replacement.org_id=v_row.org_id))) and
      (v_row.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_row.event_id
        and e.active=true and e.starts_at<=now() and e.ends_at>now())) then
      perform nexora.generate_dynamic_contract(v_row.scope,v_row.user_id,v_row.org_id,
        v_row.slot_no,v_today,v_row.item_id,v_row.tier,v_row.event_id);
    end if;
    if v_row.status='accepted' and v_row.deadline_at is not null and v_row.deadline_at<=now() and coalesce(v_row.claimed_by,v_row.user_id) is not null then
      insert into nexora.notifications(id,user_id,title,body,type,is_read)
      select 'ntf_'||gen_random_uuid()::text,pp.user_id,
        case when pp.language='ar' then 'انتهت مهلة العقد' else 'Contract expired' end,
        case when pp.language='ar' then 'انتهت المهلة وتم تحديث خانة العقد بعرض جديد.' else 'The deadline expired and the contract slot was refreshed.' end,
        'economy',false
      from nexora.player_private pp
      where pp.user_id=coalesce(v_row.claimed_by,v_row.user_id) and pp.notifications_enabled=true;
    end if;
  end loop;
  return v_count;
end;
$function$
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.settle_finished_manufacturing_jobs()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_job record;
  v_completed integer:=0;
begin
  for v_job in
    select id,user_id
    from nexora.manufacturing_jobs
    where status='running' and ends_at<=now()
    order by ends_at,id
    for update skip locked
  loop
    begin
      perform nexora.complete_manufacturing_job(v_job.user_id,v_job.id);
      v_completed:=v_completed+1;
    exception when others then
      if sqlerrm='INVENTORY_CAPACITY_EXCEEDED' then
        perform nexora.emit_notification_once(
          v_job.user_id,'manufacturing-capacity:'||v_job.id,
          'الإنتاج جاهز لكن المخزون ممتلئ','Production ready — inventory full',
          'اكتمل وقت التصنيع، لكن سعة المخزون لا تكفي لاستلام الإنتاج. أفرغ مساحة وسيُضاف تلقائيًا.',
          'The production timer ended, but your inventory has no room. Free capacity and the output will be added automatically.','economy'
        );
      else
        raise warning 'Could not settle manufacturing job %: %',v_job.id,sqlerrm;
      end if;
    end;
  end loop;
  return v_completed;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.settle_finished_upgrades()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_row record; v_count integer:=0;
begin
  for v_row in select id,owner_uid from nexora.companies where level_upgrade_ends_at<=now() or vault_upgrade_ends_at<=now() order by id loop
    begin
      if exists(select 1 from nexora.companies where id=v_row.id and level_upgrade_ends_at<=now()) then perform nexora.complete_company_upgrade(v_row.owner_uid,v_row.id); v_count:=v_count+1; end if;
      if exists(select 1 from nexora.companies where id=v_row.id and vault_upgrade_ends_at<=now()) then perform nexora.complete_company_vault_upgrade(v_row.owner_uid,v_row.id); v_count:=v_count+1; end if;
    exception when others then raise warning 'Could not settle company upgrade %: %',v_row.id,sqlerrm; end;
  end loop;
  for v_row in select id,owner_uid from nexora.factories where upgrade_ends_at<=now() or warehouse_upgrade_ends_at<=now() order by id loop
    begin
      if exists(select 1 from nexora.factories where id=v_row.id and upgrade_ends_at<=now()) then perform nexora.complete_factory_upgrade(v_row.owner_uid,v_row.id); v_count:=v_count+1; end if;
      if exists(select 1 from nexora.factories where id=v_row.id and warehouse_upgrade_ends_at<=now()) then perform nexora.complete_factory_warehouse_upgrade(v_row.owner_uid,v_row.id); v_count:=v_count+1; end if;
    exception when others then raise warning 'Could not settle factory upgrade %: %',v_row.id,sqlerrm; end;
  end loop;
  return v_count;
end;
$function$
;

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
  v_duration_ms numeric;
  v_ends timestamptz;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_log text := 'clog_' || gen_random_uuid()::text;
begin
  select * into v_company from nexora.companies where id = p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid <> p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.level >= 100 then raise exception 'MAX_LEVEL'; end if;
  if v_company.level_upgrade_started_at is not null
     or v_company.level_upgrade_ends_at is not null
     or v_company.level_upgrade_target_level is not null then
    raise exception 'UPGRADE_IN_PROGRESS';
  end if;
  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_target := v_company.level + 1;
  v_cost := nexora.company_upgrade_cost(v_company.sector, v_company.level);
  v_duration_ms := nexora.company_upgrade_duration_seconds(v_target) * 1000;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_ends := now() + make_interval(secs => greatest(1, v_duration_ms / 1000));
  update nexora.wallets
  set balance = balance - v_cost, total_spent = total_spent + v_cost, last_tx_id = v_tx, updated_at = now()
  where user_id = p_uid;
  update nexora.companies
  set level_upgrade_started_at = now(), level_upgrade_ends_at = v_ends,
      level_upgrade_target_level = v_target, level_upgrade_cost = v_cost, updated_at = now()
  where id = p_company_id;
  insert into nexora.transactions(id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status)
  values(v_tx, p_uid, 'SYSTEM', v_cost, 0, v_cost, 'company_upgrade', p_company_id,
    'Started upgrade of ' || v_company.name || ' to Lv.' || v_target::text, 'completed');
  insert into nexora.company_logs(id, company_id, owner_uid, action, amount, details)
  values(v_log, p_company_id, p_uid, 'upgrade_started', -v_cost, 'Started upgrade to Level ' || v_target::text);
  return jsonb_build_object('ok', true, 'target_level', v_target, 'ends_at', v_ends, 'duration_ms', v_duration_ms, 'cost', v_cost);
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.start_contract_slot_cooldown()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_owner_id text;
begin
  if old.status is distinct from new.status
    and new.status in ('completed','abandoned','expired')
    and new.scope='personal'
    and new.slot_no between 1 and 5
  then
    v_owner_id:=new.user_id;
    if v_owner_id is not null then
      insert into nexora.contract_slot_cooldowns
        (scope,owner_id,slot_no,board_date,cooldown_until,updated_at)
      values
        ('personal',v_owner_id,new.slot_no,new.board_date,now()+interval '15 minutes',now())
      on conflict(scope,owner_id,slot_no,board_date)
      do update set cooldown_until=greatest(
        nexora.contract_slot_cooldowns.cooldown_until,excluded.cooldown_until
      ),updated_at=now();

      if pg_trigger_depth()=1 then
        update nexora.contract_offers
        set status='expired',updated_at=now()
        where scope='personal' and user_id=v_owner_id and slot_no=new.slot_no
          and id<>new.id and status='offered';
      end if;
    end if;
  end if;
  return new;
end;
$function$
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.sync_all_factory_production()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_factory record;
  v_count integer:=0;
begin
  for v_factory in select id,owner_uid from nexora.factories order by id
  loop
    begin
      perform nexora.sync_factory_production(v_factory.owner_uid,v_factory.id);
      v_count:=v_count+1;
    exception when others then
      raise warning 'Could not synchronize factory %: %',v_factory.id,sqlerrm;
    end;
  end loop;
  perform nexora.notify_full_factory_warehouses();
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.sync_factory_production(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_capacity bigint;
  v_space bigint;
  v_elapsed numeric;
  v_hours numeric;
  v_desired_hours numeric;
  v_rate numeric;
  v_expense numeric;
  v_raw_cost numeric;
  v_cost bigint;
  v_cost_remainder numeric;
  v_raw_output numeric;
  v_qty bigint;
  v_production_remainder numeric;
  v_funds_exhausted boolean := false;
  v_min_balance constant bigint := 300;
  v_available numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  if not found then raise exception 'INVALID_RESOURCE'; end if;
  v_capacity:=nexora.factory_warehouse_capacity(v_factory.resource_id,v_factory.warehouse_level);
  v_space:=greatest(0,v_capacity-v_factory.warehouse_qty);
  v_elapsed:=least(12,greatest(0,extract(epoch from (now()-v_factory.last_produced_at))/3600));
  v_rate := v_cfg.production_rate * nexora.factory_progression_multiplier(v_factory.resource_id, v_factory.level) * (1 + v_factory.skill_level * 0.01);
  v_expense:=v_cfg.operating_cost
    * (1+greatest(0,v_factory.level-1)*0.018)
    * (1-v_factory.skill_level*0.005);

  if v_elapsed<=0 or v_space<=0 then
    update nexora.factories
    set is_active=(v_wallet.balance>v_min_balance+coalesce(v_factory.operating_cost_remainder,0)),
        last_produced_at=now(),updated_at=now()
    where id=p_factory_id;
    return jsonb_build_object(
      'produced',0,'operating_cost',0,'warehouse_qty',v_factory.warehouse_qty,
      'capacity',v_capacity,
      'is_active',(v_wallet.balance>v_min_balance+coalesce(v_factory.operating_cost_remainder,0)),'minimum_balance',v_min_balance
    );
  end if;

  v_desired_hours:=least(v_elapsed,greatest(0,(v_space-v_factory.production_remainder)/v_rate));
  v_available:=greatest(0,v_wallet.balance-v_min_balance-coalesce(v_factory.operating_cost_remainder,0));
  if v_expense>0 and v_available < v_expense*v_desired_hours then
    v_hours:=least(v_desired_hours,v_available/v_expense);
    v_funds_exhausted:=true;
  else
    v_hours:=v_desired_hours;
  end if;
  v_raw_cost:=coalesce(v_factory.operating_cost_remainder,0)+v_expense*v_hours;
  v_cost:=floor(v_raw_cost)::bigint;
  v_cost_remainder:=v_raw_cost-v_cost;

  v_raw_output:=v_factory.production_remainder+v_rate*v_hours;
  v_qty:=least(v_space,floor(v_raw_output)::bigint);
  v_production_remainder:=case when v_qty>=v_space then 0 else v_raw_output-v_qty end;

  if v_cost>0 then
    update nexora.wallets
    set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now()
    where user_id=p_uid;
    insert into nexora.transactions(
      id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
    ) values(
      v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_operating',p_factory_id,
      'Factory operating costs: '||v_factory.name,'completed'
    );
  end if;

  v_funds_exhausted:=v_funds_exhausted or (v_wallet.balance-v_cost<=v_min_balance);

  update nexora.factories
  set warehouse_qty=warehouse_qty+v_qty,
      production_remainder=v_production_remainder,
      operating_cost_remainder=v_cost_remainder,
      is_active=not v_funds_exhausted,
      last_produced_at=now(),updated_at=now()
  where id=p_factory_id;

  return jsonb_build_object(
    'produced',v_qty,'operating_cost',v_cost,
    'warehouse_qty',v_factory.warehouse_qty+v_qty,'capacity',v_capacity,
    'is_active',not v_funds_exhausted,'minimum_balance',v_min_balance
  );
end
$function$
;

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
;

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
;

CREATE OR REPLACE FUNCTION nexora.transfer_credits(p_uid text, p_recipient_username text, p_amount bigint, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_to_uid text;
  v_profile nexora.player_profiles%rowtype;
  v_from nexora.wallets%rowtype;
  v_to nexora.wallets%rowtype;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_notification text:='ntf_'||gen_random_uuid()::text;
  v_note text:=left(coalesce(btrim(p_note),''),180);
  v_recipient_name text;
  v_fee bigint;
  v_net bigint;
  v_day_start timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
  v_transferred_today bigint;
begin
  if p_amount is null or p_amount<=0 then raise exception 'INVALID_AMOUNT'; end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_profile.level<10 then raise exception 'TRANSFER_LEVEL_REQUIRED'; end if;
  select uid,username into v_to_uid,v_recipient_name from nexora.usernames where username_lower=lower(btrim(p_recipient_username));
  if v_to_uid is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
  if v_to_uid=p_uid then raise exception 'SELF_OR_MISSING_RECIPIENT'; end if;
  perform 1 from nexora.wallets where user_id in (p_uid,v_to_uid) order by user_id for update;
  select * into v_from from nexora.wallets where user_id=p_uid;
  select * into v_to from nexora.wallets where user_id=v_to_uid;
  if v_from.user_id is null or v_to.user_id is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
  select coalesce(sum(amount),0) into v_transferred_today from nexora.transactions
    where from_uid=p_uid and type='transfer' and status='completed' and created_at>=v_day_start;
  if v_transferred_today+p_amount>10000 then raise exception 'TRANSFER_DAILY_LIMIT'; end if;
  if p_amount>v_from.balance then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_fee:=round(p_amount*0.03)::bigint;
  v_net:=p_amount-v_fee;
  if v_net<1 then raise exception 'INVALID_AMOUNT'; end if;
  update nexora.wallets set balance=balance-p_amount,total_spent=total_spent+p_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.wallets set balance=balance+v_net,total_earned=total_earned+v_net,last_tx_id=v_tx,updated_at=now() where user_id=v_to_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,v_to_uid,p_amount,v_fee,v_net,'transfer',v_to_uid,coalesce(nullif(v_note,''),'Transfer to '||v_recipient_name),'completed');
  insert into nexora.audit_logs(id,user_id,action,entity_type,entity_id,details)
    values('aud_'||gen_random_uuid()::text,p_uid,'wallet_transfer','transaction',v_tx,jsonb_build_object('recipient_uid',v_to_uid,'amount',p_amount,'fee',v_fee,'net_amount',v_net));
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
    values(v_notification,p_uid,'Transfer Sent','-$'||p_amount::text||' -> '||v_recipient_name||' (3% fee: $'||v_fee::text||')','economy',false);
  return jsonb_build_object('ok',true,'transaction_id',v_tx,'amount',p_amount,'fee',v_fee,'net_amount',v_net,'daily_remaining',greatest(0,10000-v_transferred_today-p_amount));
end;
$function$
;

CREATE OR REPLACE FUNCTION nexora.unblock_player(p_user_id text, p_target_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'nexora', 'pg_temp'
AS $function$
begin delete from user_blocks where owner_uid=p_user_id and target_uid=p_target_uid; return jsonb_build_object('ok',true); end $function$
;

CREATE OR REPLACE FUNCTION nexora.unlock_eligible_achievements(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_new_ids text[] := '{}'::text[];
  v_all_ids text[] := '{}'::text[];
  v_achievement_id text;
  v_revenue bigint;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select coalesce(sum(amount),0) into v_revenue
  from nexora.transactions
  where to_uid=p_uid and type='company_collect' and status='completed';

  with eligible as (
    select a.id
    from (values
      ('nova_whale_i','spent',50000,2000),
      ('nova_whale_ii','spent',250000,8000),
      ('nova_whale_iii','spent',1000000,25000),
      ('nova_whale_iv','spent',5000000,75000),
      ('nova_market_i','trades',250,1500),
      ('nova_market_ii','trades',1000,6000),
      ('nova_market_iii','trades',5000,25000),
      ('nova_market_iv','trades',20000,75000),
      ('nova_industry_i','produced',500,2000),
      ('nova_industry_ii','produced',2500,8000),
      ('nova_industry_iii','produced',10000,30000),
      ('nova_industry_iv','produced',50000,90000),
      ('nova_enterprise_i','revenue',100000,5000),
      ('nova_enterprise_ii','revenue',500000,15000),
      ('nova_enterprise_iii','revenue',2000000,50000),
      ('nova_enterprise_iv','revenue',10000000,150000)
    ) as a(id,metric,threshold,reward)
    where case a.metric
      when 'spent' then v_wallet.total_spent
      when 'trades' then coalesce((v_profile.stats->>'tradesCount')::bigint,0)
      when 'produced' then coalesce((v_profile.stats->>'totalProduced')::bigint,0)
      when 'revenue' then v_revenue
      else 0
    end >= a.threshold
  ), inserted as (
    insert into nexora.player_achievements(user_id,achievement_id)
    select p_uid,eligible.id from eligible
    on conflict(user_id,achievement_id) do nothing
    returning achievement_id
  )
  select coalesce(array_agg(achievement_id),'{}'::text[]) into v_new_ids from inserted;

  foreach v_achievement_id in array v_new_ids loop
    perform nexora.emit_notification_once(
      p_uid,'achievement-ready:'||v_achievement_id,
      'مكافأة الإنجاز جاهزة','Achievement reward ready',
      'اكتمل إنجازك وأصبحت مكافأته جاهزة للاستلام ('||v_achievement_id||').',
      'You completed an achievement. Its reward is ready to claim ('||v_achievement_id||').',
      'mission'
    );
  end loop;

  select coalesce(array_agg(achievement_id),'{}'::text[]) into v_all_ids
  from nexora.player_achievements where user_id=p_uid;

  return jsonb_build_object(
    'unlocked_ids',v_all_ids,
    'newly_unlocked_ids',v_new_ids,
    'new_rewards',coalesce((
      select sum(reward) from (values
        ('nova_whale_i',2000::bigint),('nova_whale_ii',8000::bigint),('nova_whale_iii',25000::bigint),('nova_whale_iv',75000::bigint),
        ('nova_market_i',1500::bigint),('nova_market_ii',6000::bigint),('nova_market_iii',25000::bigint),('nova_market_iv',75000::bigint),
        ('nova_industry_i',2000::bigint),('nova_industry_ii',8000::bigint),('nova_industry_iii',30000::bigint),('nova_industry_iv',90000::bigint),
        ('nova_enterprise_i',5000::bigint),('nova_enterprise_ii',15000::bigint),('nova_enterprise_iii',50000::bigint),('nova_enterprise_iv',150000::bigint)
      ) as rewards(id,reward) where id=any(v_new_ids)
    ),0)
  );
end;
$function$
;

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
;

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
;

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
;

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
    when 1 then v_cost:=2500;v_item1:='copper_wire';v_qty1:=20;v_item2:='crude_alloy';v_qty2:=10;
    when 2 then v_cost:=7000;v_item1:='silicon_ore';v_qty1:=20;v_item2:='energy_cells';v_qty2:=15;
    when 3 then v_cost:=18000;v_item1:='carbon_fiber';v_qty1:=15;v_item2:='precision_frame';v_qty2:=10;
    when 4 then v_cost:=45000;v_item1:='rare_minerals';v_qty1:=20;v_item2:='quantum_server';v_qty2:=5;
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
  v_duration:=case v_target when 2 then 1200 when 3 then 4500 when 4 then 14400 else 43200 end;
  v_ends:=v_now+make_interval(secs=>greatest(1,v_duration));
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
;

CREATE OR REPLACE FUNCTION nexora.upgrade_factory(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_factory nexora.factories%rowtype; v_wallet nexora.wallets%rowtype; v_cfg record;
 v_cost bigint; v_materials integer; v_owned bigint; v_target integer; v_ends timestamptz;
 v_duration_seconds numeric; v_tx text:='tx_'||gen_random_uuid()::text;
begin
 select * into v_factory from nexora.factories where id=p_factory_id for update;
 if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
 if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
 if v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;
 if v_factory.level>=100 then raise exception 'MAX_LEVEL'; end if;
 select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
 v_target:=v_factory.level+1;
 v_cost:=ceil(v_cfg.founding_cost*0.22*power(v_factory.level::numeric,1.22))::bigint;
 v_materials:=ceil(v_factory.level*v_cfg.rarity_factor*2)::integer;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;
 if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
 if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
 select quantity into v_owned from nexora.inventory where user_id=p_uid and item_id=v_factory.resource_id for update;
 if not found or coalesce(v_owned,0)<v_materials then raise exception 'MISSING_FACTORY_MATERIALS'; end if;
 v_duration_seconds:=600*power(v_target::numeric,1.35);
 v_ends:=now()+make_interval(secs=>v_duration_seconds::double precision);
 update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 update nexora.inventory set quantity=quantity-v_materials,updated_at=now() where user_id=p_uid and item_id=v_factory.resource_id;
 update nexora.factories set upgrade_started_at=now(),upgrade_ends_at=v_ends,upgrade_target_level=v_target,upgrade_cost=v_cost,updated_at=now() where id=p_factory_id;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
 values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_upgrade',p_factory_id,'Started factory upgrade: '||v_factory.name,'completed');
 return jsonb_build_object('target_level',v_target,'ends_at',v_ends,'cost',v_cost,'materials',v_materials,'duration_seconds',round(v_duration_seconds));
end $function$
;

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
;

CREATE OR REPLACE FUNCTION nexora.upgrade_factory_warehouse(p_uid text, p_factory_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_factory nexora.factories%rowtype; v_wallet nexora.wallets%rowtype;
  v_cost bigint; v_target integer; v_ends timestamptz; v_tx text:='tx_'||gen_random_uuid()::text;
  v_costs bigint[]:=array[2500,7000,18000,45000];
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
  v_ends:=now()+make_interval(mins=>case v_target when 2 then 30 when 3 then 90 when 4 then 240 else 720 end);
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.factories set warehouse_upgrade_started_at=now(),warehouse_upgrade_ends_at=v_ends,warehouse_upgrade_target_level=v_target,warehouse_upgrade_cost=v_cost,updated_at=now() where id=p_factory_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_warehouse_upgrade',p_factory_id,'Factory warehouse expansion: '||v_factory.name,'completed');
  return jsonb_build_object('target_level',v_target,'ends_at',v_ends,'cost',v_cost,'capacity',nexora.factory_warehouse_capacity(v_factory.resource_id,v_target));
end;
$function$
;

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
;

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
;

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
;

CREATE TRIGGER audit_logs_immutable BEFORE DELETE OR UPDATE ON nexora.audit_logs FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

CREATE TRIGGER companies_capacity_guard BEFORE INSERT ON nexora.companies FOR EACH ROW EXECUTE FUNCTION nexora.enforce_company_capacity();

CREATE TRIGGER nova_company_vault_full_notification AFTER UPDATE OF vault_balance ON nexora.companies FOR EACH ROW EXECUTE FUNCTION nexora.notify_company_vault_full();

CREATE TRIGGER nova_mark_company_vault_notification_claimed AFTER UPDATE OF vault_balance, last_collected_at, vault_level ON nexora.companies FOR EACH ROW EXECUTE FUNCTION nexora.mark_company_vault_notification_claimed();

CREATE TRIGGER nova_org_goal_company_founding AFTER INSERT ON nexora.companies FOR EACH ROW EXECUTE FUNCTION nexora.record_org_goal_from_company_founding();

CREATE TRIGGER nova_org_goal_company_revenue AFTER UPDATE OF total_revenue ON nexora.companies FOR EACH ROW WHEN (new.total_revenue > old.total_revenue) EXECUTE FUNCTION nexora.record_org_goal_from_company_revenue();

CREATE TRIGGER nova_org_goal_company_upgrade AFTER UPDATE OF level ON nexora.companies FOR EACH ROW WHEN (new.level > old.level) EXECUTE FUNCTION nexora.record_org_goal_from_company_upgrade();

CREATE TRIGGER company_auction_late_bid_extension BEFORE UPDATE OF current_price ON nexora.company_auctions FOR EACH ROW EXECUTE FUNCTION nexora.extend_company_auction_on_late_bid();

CREATE TRIGGER company_auction_sale_fee AFTER UPDATE OF status ON nexora.company_auctions FOR EACH ROW EXECUTE FUNCTION nexora.apply_company_auction_sale_fee();

CREATE TRIGGER company_logs_immutable BEFORE DELETE OR UPDATE ON nexora.company_logs FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

CREATE TRIGGER contract_claims_immutable BEFORE DELETE OR UPDATE ON nexora.contract_claims FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

CREATE TRIGGER nova_contract_slot_cooldown AFTER UPDATE OF status ON nexora.contract_offers FOR EACH ROW EXECUTE FUNCTION nexora.start_contract_slot_cooldown();

CREATE TRIGGER nova_contract_slot_cooldown_guard BEFORE INSERT ON nexora.contract_offers FOR EACH ROW EXECUTE FUNCTION nexora.guard_contract_slot_cooldown_insert();

CREATE TRIGGER daily_claims_immutable BEFORE DELETE OR UPDATE ON nexora.daily_claims FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

CREATE TRIGGER nova_mark_daily_stipend_notification_claimed AFTER INSERT ON nexora.daily_claims FOR EACH ROW EXECUTE FUNCTION nexora.mark_daily_stipend_notification_claimed();

CREATE TRIGGER nova_factory_warehouse_full_notification AFTER UPDATE OF warehouse_qty ON nexora.factories FOR EACH ROW EXECUTE FUNCTION nexora.notify_factory_warehouse_full();

CREATE TRIGGER nova_mark_factory_warehouse_notification_claimed AFTER UPDATE OF warehouse_qty, warehouse_level ON nexora.factories FOR EACH ROW EXECUTE FUNCTION nexora.mark_factory_warehouse_notification_claimed();

CREATE TRIGGER nova_org_goal_factory_founding AFTER INSERT ON nexora.factories FOR EACH ROW EXECUTE FUNCTION nexora.record_org_goal_from_factory_founding();

CREATE TRIGGER nova_org_goal_factory_production AFTER UPDATE OF warehouse_qty ON nexora.factories FOR EACH ROW WHEN (new.warehouse_qty > old.warehouse_qty) EXECUTE FUNCTION nexora.record_org_goal_from_factory();

CREATE TRIGGER nova_org_goal_factory_upgrade AFTER UPDATE OF level ON nexora.factories FOR EACH ROW WHEN (new.level > old.level) EXECUTE FUNCTION nexora.record_org_goal_from_factory_upgrade();

CREATE TRIGGER inventory_capacity_guard AFTER INSERT OR UPDATE OF quantity ON nexora.inventory FOR EACH ROW EXECUTE FUNCTION nexora.enforce_player_inventory_capacity();

CREATE TRIGGER manufacturing_job_input_snapshot BEFORE INSERT ON nexora.manufacturing_jobs FOR EACH ROW EXECUTE FUNCTION nexora.prepare_manufacturing_job();

CREATE TRIGGER market_listing_capacity_guard AFTER INSERT OR UPDATE OF remaining_qty, status ON nexora.market_listings FOR EACH ROW EXECUTE FUNCTION nexora.enforce_market_listing_capacity();

CREATE TRIGGER market_listing_price_bounds BEFORE INSERT OR UPDATE OF item_id, unit_price ON nexora.market_listings FOR EACH ROW EXECUTE FUNCTION nexora.enforce_market_listing_price_bounds();

CREATE TRIGGER market_order_price_bounds BEFORE INSERT ON nexora.market_orders FOR EACH ROW EXECUTE FUNCTION nexora.enforce_market_order_price_bounds();

CREATE TRIGGER nova_org_goal_market_volume AFTER INSERT ON nexora.market_orders FOR EACH ROW EXECUTE FUNCTION nexora.record_org_goal_from_market_order();

CREATE TRIGGER nova_org_goal_treasury_donation AFTER INSERT ON nexora.organization_transactions FOR EACH ROW EXECUTE FUNCTION nexora.record_org_goal_from_org_transaction();

CREATE TRIGGER organization_transactions_immutable BEFORE DELETE OR UPDATE ON nexora.organization_transactions FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

CREATE TRIGGER player_achievements_claim_guard BEFORE UPDATE ON nexora.player_achievements FOR EACH ROW EXECUTE FUNCTION nexora.guard_player_achievement_claim_update();

CREATE TRIGGER player_achievements_delete_immutable BEFORE DELETE ON nexora.player_achievements FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

CREATE TRIGGER nova_mark_mission_reward_notification_claimed AFTER INSERT ON nexora.player_missions FOR EACH ROW EXECUTE FUNCTION nexora.mark_mission_reward_notification_claimed();

CREATE TRIGGER player_missions_immutable BEFORE DELETE OR UPDATE ON nexora.player_missions FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

CREATE TRIGGER enforce_skill_point_progression BEFORE INSERT OR UPDATE ON nexora.player_profiles FOR EACH ROW EXECUTE FUNCTION nexora.enforce_skill_point_progression();

CREATE TRIGGER nova_notify_ready_missions_profile AFTER UPDATE OF stats, org_id ON nexora.player_profiles FOR EACH ROW EXECUTE FUNCTION nexora.notify_ready_missions_after_profile_update();

CREATE TRIGGER nova_org_goal_profile_production AFTER UPDATE OF stats ON nexora.player_profiles FOR EACH ROW WHEN (COALESCE((new.stats ->> 'totalProduced'::text)::numeric, 0::numeric) > COALESCE((old.stats ->> 'totalProduced'::text)::numeric, 0::numeric)) EXECUTE FUNCTION nexora.record_org_goal_from_profile();

CREATE TRIGGER nova_notify_ready_missions_transaction AFTER INSERT ON nexora.transactions FOR EACH ROW EXECUTE FUNCTION nexora.notify_ready_missions_after_transaction();

CREATE TRIGGER transactions_immutable BEFORE DELETE OR UPDATE ON nexora.transactions FOR EACH ROW EXECUTE FUNCTION nexora.reject_immutable_mutation();

ALTER TABLE nexora.audit_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.chat_rate_limits ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.companies ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.company_auction_bids ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.company_auction_escrows ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.company_auctions ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.company_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.contract_claims ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.contract_config ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.contract_daily_limits ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.contract_offers ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.contract_slot_cooldowns ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.contract_slot_refresh_usage ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.conversation_messages ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.conversations ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.daily_claims ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.diagnostics_admins ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.factories ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.global_chat_messages ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.inventory ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.market_listings ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.market_orders ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.market_system_restock_runs ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.notification_events ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.notifications ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.org_goal_contributions ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.org_weekly_goals ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.organization_chat_messages ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.organization_invites ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.organization_members ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.organization_requests ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.organization_transactions ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.organizations ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.player_achievements ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.player_missions ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.player_presence ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.player_private ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.player_profiles ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.player_reports ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.transactions ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.user_blocks ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.usernames ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.wallets ENABLE ROW LEVEL SECURITY;

ALTER TABLE nexora.world_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON SCHEMA nexora FROM PUBLIC, anon, authenticated;\nGRANT USAGE ON SCHEMA nexora TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA nexora TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA nexora TO service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA nexora FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA nexora FROM PUBLIC, anon, authenticated;
