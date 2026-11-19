-- Factories run automatically. Insufficient operating funds pause them; funding resumes them on the next sync.
-- Production starts at a resource-specific rate (20 down to 3 units/hour) and grows
-- with a smooth convex curve whose level-100 multiplier is capped below 4x before skill bonuses.

-- Keep server-side founding, production, and operating values aligned with the client catalog.
create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
language sql immutable
set search_path = ''
as $config$
  select cfg.founding_cost,cfg.production_rate,cfg.operating_cost,cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,20.000::numeric,60.00::numeric,1.00::numeric),
    ('silicon_ore',2400,18.000,70.00,1.20),
    ('energy_cells',3200,16.000,80.00,1.40),
    ('crude_alloy',4200,14.000,69.00,1.65),
    ('carbon_fiber',6000,11.000,94.00,2.10),
    ('rare_minerals',9000,8.000,118.00,3.60),
    ('titanium_ore',12000,7.000,141.00,4.00),
    ('polymer_resin',15000,6.000,156.00,4.50),
    ('biotech_gel',22000,4.000,194.00,5.00),
    ('quantum_dust',30000,3.000,256.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$config$;

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
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_factory
  from nexora.factories
  where id = p_factory_id
  for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid <> p_uid then raise exception 'UNAUTHORIZED'; end if;

  select * into v_wallet
  from nexora.wallets
  where user_id = p_uid
  for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select * into v_cfg
  from nexora.factory_resource_config(v_factory.resource_id);
  if not found then raise exception 'INVALID_RESOURCE'; end if;

  v_capacity := nexora.factory_warehouse_capacity(v_factory.resource_id, v_factory.warehouse_level);
  v_space := greatest(0, v_capacity - v_factory.warehouse_qty);
  v_elapsed := least(12, greatest(0, extract(epoch from (now() - v_factory.last_produced_at)) / 3600));

  -- Convex but bounded progression: each level adds more than the previous one,
  -- while level 100 reaches only 3.95x base output (before the separate skill bonus).
  v_rate := v_cfg.production_rate
    * (1 + 0.025 * greatest(0, v_factory.level - 1)
         + 0.00015 * power(greatest(0, v_factory.level - 1)::numeric, 2))
    * (1 + v_factory.skill_level * 0.04);
  v_expense := v_cfg.operating_cost
    * (1 + greatest(0, v_factory.level - 1) * 0.06)
    * (1 - v_factory.skill_level * 0.03);

  if v_elapsed <= 0 or v_space <= 0 then
    update nexora.factories
    set is_active = (v_wallet.balance > coalesce(v_factory.operating_cost_remainder, 0)),
        last_produced_at = now(),
        updated_at = now()
    where id = p_factory_id;
    return jsonb_build_object(
      'produced', 0,
      'operating_cost', 0,
      'warehouse_qty', v_factory.warehouse_qty,
      'capacity', v_capacity,
      'is_active', (v_wallet.balance > coalesce(v_factory.operating_cost_remainder, 0))
    );
  end if;

  v_desired_hours := least(v_elapsed, greatest(0, (v_space - v_factory.production_remainder) / v_rate));
  v_hours := v_desired_hours;
  v_raw_cost := coalesce(v_factory.operating_cost_remainder, 0) + v_expense * v_hours;
  v_cost := floor(v_raw_cost)::bigint;

  if v_raw_cost >= v_wallet.balance and v_raw_cost > 0 then
    -- Spend only what remains and produce only for the time that balance can fund.
    v_hours := greatest(0, (v_wallet.balance - coalesce(v_factory.operating_cost_remainder, 0)) / v_expense);
    v_hours := least(v_hours, v_desired_hours);
    v_cost := v_wallet.balance;
    v_cost_remainder := 0;
    v_funds_exhausted := true;
  else
    v_cost_remainder := v_raw_cost - v_cost;
  end if;

  v_raw_output := v_factory.production_remainder + v_rate * v_hours;
  v_qty := least(v_space, floor(v_raw_output)::bigint);
  v_production_remainder := case
    when v_qty >= v_space then 0
    else v_raw_output - v_qty
  end;

  if v_cost > 0 then
    update nexora.wallets
    set balance = balance - v_cost,
        total_spent = total_spent + v_cost,
        last_tx_id = v_tx,
        updated_at = now()
    where user_id = p_uid;

    insert into nexora.transactions(
      id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status
    ) values (
      v_tx, p_uid, 'SYSTEM', v_cost, 0, v_cost, 'factory_operating', p_factory_id,
      'Factory operating costs: ' || v_factory.name, 'completed'
    );
  end if;

  update nexora.factories
  set warehouse_qty = warehouse_qty + v_qty,
      production_remainder = v_production_remainder,
      operating_cost_remainder = v_cost_remainder,
      is_active = not v_funds_exhausted,
      last_produced_at = now(),
      updated_at = now()
  where id = p_factory_id;

  return jsonb_build_object(
    'produced', v_qty,
    'operating_cost', v_cost,
    'warehouse_qty', v_factory.warehouse_qty + v_qty,
    'capacity', v_capacity,
    'is_active', not v_funds_exhausted
  );
end
$function$;

-- Retain the RPC for compatibility with already-open clients, but no longer permit manual shutdown.
create or replace function nexora.set_factory_active(p_uid text, p_factory_id text, p_active boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_factory nexora.factories%rowtype;
begin
  select * into v_factory
  from nexora.factories
  where id = p_factory_id
  for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid <> p_uid then raise exception 'UNAUTHORIZED'; end if;
  if coalesce(p_active, false) = false then
    raise exception 'FACTORY_ALWAYS_AUTOMATIC';
  end if;

  update nexora.factories
  set is_active = true,
      last_produced_at = now(),
      updated_at = now()
  where id = p_factory_id;

  return jsonb_build_object('ok', true, 'is_active', true);
end
$function$;
