
-- NOVA economy, organization goals, and daily raw-material market supply.
-- Existing ownership, wallet, inventory, and listing records are preserved.

create or replace function nexora.market_price_bounds(p_item_id text)
returns table(min_price bigint, max_price bigint)
language sql immutable
set search_path = ''
as $function$
  select greatest(1, floor(prices.base_price * 0.5)::bigint),
         greatest(1, ceil(prices.base_price * 2)::bigint)
  from (values
    ('silicon_ore', 35::numeric),
    ('copper_wire', 28::numeric),
    ('energy_cells', 45::numeric),
    ('crude_alloy', 40::numeric),
    ('carbon_fiber', 55::numeric),
    ('rare_minerals', 70::numeric),
    ('titanium_ore', 85::numeric),
    ('polymer_resin', 95::numeric),
    ('biotech_gel', 120::numeric),
    ('quantum_dust', 160::numeric),
    ('microchips', 145::numeric),
    ('precision_frame', 175::numeric),
    ('synth_polymer', 190::numeric),
    ('quantum_server', 560::numeric),
    ('logistics_drone', 620::numeric),
    ('bio_module', 680::numeric)
  ) as prices(item_id, base_price)
  where prices.item_id = p_item_id
$function$;

create or replace function nexora.create_market_listing(
  p_uid text, p_item_id text, p_qty integer, p_unit_price bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_inventory nexora.inventory%rowtype;
  v_username text;
  v_id text := 'lst_' || gen_random_uuid()::text;
begin
  if p_item_id not in (
    'silicon_ore','copper_wire','energy_cells','crude_alloy','carbon_fiber',
    'rare_minerals','titanium_ore','polymer_resin','biotech_gel','quantum_dust',
    'microchips','precision_frame','synth_polymer','quantum_server',
    'logistics_drone','bio_module'
  ) then
    raise exception 'INVALID_ITEM';
  end if;
  if p_qty is null or p_qty < 1 or p_qty > 10000
     or p_unit_price is null or p_unit_price < 1 or p_unit_price > 1000000 then
    raise exception 'INVALID_LISTING_PARAMS';
  end if;
  select username into v_username
  from nexora.player_profiles where user_id = p_uid;
  if v_username is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_inventory
  from nexora.inventory
  where user_id = p_uid and item_id = p_item_id
  for update;
  if not found or v_inventory.quantity < p_qty then
    raise exception 'INSUFFICIENT_INVENTORY';
  end if;
  update nexora.inventory
  set quantity = quantity - p_qty, updated_at = now()
  where user_id = p_uid and item_id = p_item_id;
  insert into nexora.market_listings(
    id, seller_uid, seller_name, item_id, quantity, remaining_qty, unit_price, status
  ) values (
    v_id, p_uid, v_username, p_item_id, p_qty, p_qty, p_unit_price, 'active'
  );
  return jsonb_build_object('ok', true, 'listing_id', v_id);
end;
$function$;

create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
language sql immutable
set search_path = ''
as $function$
  select cfg.founding_cost, cfg.production_rate, cfg.operating_cost, cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,2.750::numeric,25.00::numeric,1.00::numeric),
    ('silicon_ore',2400,2.575,28.00,1.20),
    ('energy_cells',3200,2.300,32.00,1.40),
    ('crude_alloy',4200,2.225,35.00,1.65),
    ('carbon_fiber',6000,2.200,42.00,2.10),
    ('rare_minerals',9000,2.175,50.00,3.60),
    ('titanium_ore',12000,2.150,60.00,4.00),
    ('polymer_resin',15000,2.125,65.00,4.50),
    ('biotech_gel',22000,2.100,80.00,5.00),
    ('quantum_dust',30000,2.075,110.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id = p_resource_id
$function$;

create or replace function nexora.upgrade_factory(p_uid text, p_factory_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_cost bigint;
  v_materials integer;
  v_owned bigint;
  v_target integer;
  v_ends timestamptz;
  v_duration_seconds numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_factory from nexora.factories where id = p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid <> p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at > now() then
    raise exception 'UPGRADE_IN_PROGRESS';
  end if;
  if v_factory.level >= 100 then raise exception 'MAX_LEVEL'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_target := v_factory.level + 1;
  v_cost := ceil(v_cfg.founding_cost * 0.18 * power(v_factory.level::numeric, 1.25))::bigint;
  v_materials := ceil(v_factory.level * v_cfg.rarity_factor * 2)::integer;
  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  select quantity into v_owned
  from nexora.inventory
  where user_id = p_uid and item_id = v_factory.resource_id
  for update;
  if not found or coalesce(v_owned, 0) < v_materials then
    raise exception 'MISSING_FACTORY_MATERIALS';
  end if;

  -- Level 2 starts around 2-3 minutes; progression rises smoothly and caps naturally.
  v_duration_seconds := 120
    * power(1.035::numeric, greatest(0, v_factory.level - 1))
    * sqrt(greatest(1, v_cfg.rarity_factor));
  v_ends := now() + make_interval(secs => v_duration_seconds::double precision);

  update nexora.wallets
  set balance = balance - v_cost, total_spent = total_spent + v_cost,
      last_tx_id = v_tx, updated_at = now()
  where user_id = p_uid;
  update nexora.inventory
  set quantity = quantity - v_materials, updated_at = now()
  where user_id = p_uid and item_id = v_factory.resource_id;
  update nexora.factories
  set upgrade_started_at = now(), upgrade_ends_at = v_ends,
      upgrade_target_level = v_target, upgrade_cost = v_cost, updated_at = now()
  where id = p_factory_id;
  insert into nexora.transactions(
    id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
  ) values (
    v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_upgrade',p_factory_id,
    'Started factory upgrade: ' || v_factory.name,'completed'
  );
  return jsonb_build_object(
    'target_level',v_target,'ends_at',v_ends,'cost',v_cost,
    'materials',v_materials,'duration_seconds',round(v_duration_seconds)
  );
end
$function$;

create or replace function nexora.sync_factory_production(p_uid text, p_factory_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_capacity bigint;
  v_space bigint;
  v_elapsed numeric;
  v_hours numeric;
  v_rate numeric;
  v_expense numeric;
  v_raw_cost numeric;
  v_cost bigint;
  v_cost_remainder numeric;
  v_raw_output numeric;
  v_qty bigint;
  v_production_remainder numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_factory from nexora.factories where id = p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid <> p_uid then raise exception 'UNAUTHORIZED'; end if;
  v_capacity := nexora.factory_warehouse_capacity(v_factory.resource_id, v_factory.warehouse_level);
  if not v_factory.is_active then
    update nexora.factories set last_produced_at = now(), updated_at = now() where id = p_factory_id;
    return jsonb_build_object(
      'produced',0,'operating_cost',0,'warehouse_qty',v_factory.warehouse_qty,
      'capacity',v_capacity,'is_active',false
    );
  end if;
  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_space := greatest(0, v_capacity - v_factory.warehouse_qty);
  v_elapsed := least(12, greatest(0, extract(epoch from (now() - v_factory.last_produced_at)) / 3600));
  if v_space = 0 or v_elapsed = 0 then
    update nexora.factories set last_produced_at = now(), updated_at = now() where id = p_factory_id;
    return jsonb_build_object('produced',0,'operating_cost',0,'warehouse_qty',v_factory.warehouse_qty,'capacity',v_capacity);
  end if;

  v_rate := v_cfg.production_rate
    * (1 + greatest(0, v_factory.level - 1) * 0.12)
    * (1 + v_factory.skill_level * 0.04);
  v_expense := v_cfg.operating_cost
    * (1 + greatest(0, v_factory.level - 1) * 0.06)
    * (1 - v_factory.skill_level * 0.03);

  v_hours := least(v_elapsed, greatest(0, (v_space - v_factory.production_remainder) / v_rate));
  v_raw_cost := v_factory.operating_cost_remainder + v_expense * v_hours;
  v_cost := floor(v_raw_cost)::bigint;
  if v_raw_cost > v_wallet.balance then
    v_hours := greatest(0, (v_wallet.balance - v_factory.operating_cost_remainder) / v_expense);
    v_cost := v_wallet.balance;
    v_cost_remainder := 0;
  else
    v_cost_remainder := v_raw_cost - v_cost;
  end if;
  v_raw_output := v_factory.production_remainder + v_rate * v_hours;
  v_qty := least(v_space, floor(v_raw_output)::bigint);
  v_production_remainder := case when v_qty >= v_space then 0 else v_raw_output - v_qty end;

  if v_cost > 0 then
    update nexora.wallets
    set balance = balance - v_cost, total_spent = total_spent + v_cost,
        last_tx_id = v_tx, updated_at = now()
    where user_id = p_uid;
    insert into nexora.transactions(
      id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
    ) values (
      v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_operating',p_factory_id,
      'Factory operating costs: ' || v_factory.name,'completed'
    );
  end if;
  update nexora.factories
  set warehouse_qty = warehouse_qty + v_qty,
      production_remainder = v_production_remainder,
      operating_cost_remainder = v_cost_remainder,
      last_produced_at = now(), updated_at = now()
  where id = p_factory_id;
  return jsonb_build_object(
    'produced',v_qty,'operating_cost',v_cost,
    'warehouse_qty',v_factory.warehouse_qty + v_qty,'capacity',v_capacity
  );
end
$function$;

create or replace function nexora.start_company_upgrade(p_uid text, p_company_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
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
  v_cost := v_company.level * 550;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_target := v_company.level + 1;

  -- Level 2 takes 2 minutes; time grows smoothly toward 24 hours at level 100.
  v_duration_ms := round(120000 * power(720::numeric, (v_target - 2)::numeric / 98));
  v_ends := now() + make_interval(secs => greatest(1, v_duration_ms / 1000));

  update nexora.wallets
  set balance = balance - v_cost, total_spent = total_spent + v_cost,
      last_tx_id = v_tx, updated_at = now()
  where user_id = p_uid;
  update nexora.companies
  set level_upgrade_started_at = now(), level_upgrade_ends_at = v_ends,
      level_upgrade_target_level = v_target, level_upgrade_cost = v_cost, updated_at = now()
  where id = p_company_id;
  insert into nexora.transactions(
    id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
  ) values (
    v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_upgrade',p_company_id,
    'Started upgrade of ' || v_company.name || ' to Lv.' || v_target::text,'completed'
  );
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'upgrade_started',-v_cost,'Started upgrade to Level ' || v_target::text);
  return jsonb_build_object(
    'ok',true,'target_level',v_target,'ends_at',v_ends,'duration_ms',v_duration_ms
  );
end
$function$;

-- Larger, shared weekly targets scale with both organization level and membership.
update nexora.contract_config
set config_value = '{
  "trade_volume": 25000,
  "produce_units": 1250,
  "company_revenue": 40000,
  "company_upgrades": 8,
  "factory_upgrades": 8,
  "companies_founded": 2,
  "factories_founded": 2,
  "treasury_donations": 12500,
  "contracts_completed": 20,
  "org_contracts_completed": 6,
  "personal_contracts_completed": 12
}'::jsonb
where config_key = 'weekly_goal_bases';

update nexora.contract_config
set config_value = '{"goal_count":10,"level_rate":0.20,"member_exponent":0.85}'::jsonb
where config_key = 'weekly_goal_scaling';

-- Raise active goals in the current week without wiping members' existing contributions.
with goal_bases as (
  select * from (values
    ('trade_volume',25000::numeric),
    ('produce_units',1250::numeric),
    ('company_revenue',40000::numeric),
    ('company_upgrades',8::numeric),
    ('factory_upgrades',8::numeric),
    ('companies_founded',2::numeric),
    ('factories_founded',2::numeric),
    ('treasury_donations',12500::numeric),
    ('contracts_completed',20::numeric),
    ('org_contracts_completed',6::numeric),
    ('personal_contracts_completed',12::numeric)
  ) as b(goal_type,base_target)
)
update nexora.org_weekly_goals g
set target_amount = round(
      b.base_target
      * (1 + 0.20 * greatest(1,o.level))
      * power(greatest(1,o.member_count)::numeric,0.85)
    ),
    status = case
      when g.current_amount >= round(b.base_target * (1 + 0.20 * greatest(1,o.level))
        * power(greatest(1,o.member_count)::numeric,0.85)) then 'completed'
      else 'active'
    end,
    completed_at = case
      when g.current_amount >= round(b.base_target * (1 + 0.20 * greatest(1,o.level))
        * power(greatest(1,o.member_count)::numeric,0.85)) then coalesce(g.completed_at,now())
      else null
    end
from nexora.organizations o
join goal_bases b on true
where g.org_id = o.id
  and g.goal_type = b.goal_type
  and g.week_start = date_trunc('week',timezone('UTC',now()))::date
  and g.status = 'active';

-- Private idempotency ledger: one 250-unit system supply drop per raw resource per UTC day.
create table if not exists nexora.market_system_restock_runs (
  restock_date date primary key,
  created_at timestamptz not null default now()
);
alter table nexora.market_system_restock_runs enable row level security;
revoke all on table nexora.market_system_restock_runs from public, anon, authenticated;

create or replace function nexora.restock_system_raw_market()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_today date := (now() at time zone 'UTC')::date;
  v_item record;
  v_inserted integer := 0;
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
      ('rare_minerals',70),
      ('titanium_ore',85),
      ('polymer_resin',95),
      ('biotech_gel',120),
      ('quantum_dust',160)
    ) as raw(item_id,unit_price)
  loop
    insert into nexora.market_listings(
      id,seller_uid,seller_name,item_id,quantity,remaining_qty,unit_price,status
    ) values (
      'sys_' || gen_random_uuid()::text,
      'SYSTEM',
      'NOVA Exchange',
      v_item.item_id,
      250,
      250,
      v_item.unit_price,
      'active'
    );
    v_inserted := v_inserted + 1;
  end loop;
  return v_inserted;
end
$function$;

revoke all on function nexora.restock_system_raw_market() from public, anon, authenticated;

do $schedule$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'nova-system-raw-market-restock'
  limit 1;
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
  perform cron.schedule(
    'nova-system-raw-market-restock',
    '0 0 * * *',
    'select nexora.restock_system_raw_market();'
  );
end
$schedule$;

-- Seed today's drop immediately; the date ledger prevents duplicate execution.
select nexora.restock_system_raw_market();
