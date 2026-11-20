-- Audit follow-up: preserve a player wallet reserve, prevent duplicate upgrade charges,
-- and keep company vault upgrade durations in seconds rather than milliseconds/2000.

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
  v_available numeric;
  v_cost bigint;
  v_cost_remainder numeric;
  v_raw_output numeric;
  v_qty bigint;
  v_production_remainder numeric;
  v_funds_exhausted boolean := false;
  v_min_balance constant bigint := 300;
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

  v_rate := v_cfg.production_rate
    * (1 + 0.025 * greatest(0, v_factory.level - 1)
         + 0.00015 * power(greatest(0, v_factory.level - 1)::numeric, 2))
    * (1 + v_factory.skill_level * 0.04);
  v_expense := v_cfg.operating_cost
    * (1 + greatest(0, v_factory.level - 1) * 0.06)
    * (1 - v_factory.skill_level * 0.03);

  if v_elapsed <= 0 or v_space <= 0 then
    update nexora.factories
    set is_active = (
      v_wallet.balance > v_min_balance + coalesce(v_factory.operating_cost_remainder, 0)
    ),
        last_produced_at = now(),
        updated_at = now()
    where id = p_factory_id;
    return jsonb_build_object(
      'produced', 0,
      'operating_cost', 0,
      'warehouse_qty', v_factory.warehouse_qty,
      'capacity', v_capacity,
      'is_active', (
        v_wallet.balance > v_min_balance + coalesce(v_factory.operating_cost_remainder, 0)
      ),
      'minimum_balance', v_min_balance
    );
  end if;

  v_desired_hours := least(v_elapsed, greatest(0, (v_space - v_factory.production_remainder) / v_rate));
  v_available := greatest(
    0,
    v_wallet.balance - v_min_balance - coalesce(v_factory.operating_cost_remainder, 0)
  );

  if v_expense > 0 and v_available < v_expense * v_desired_hours then
    -- Use only funds above the protected reserve, then pause until the wallet is funded again.
    v_hours := least(v_desired_hours, v_available / v_expense);
    v_funds_exhausted := true;
  else
    v_hours := v_desired_hours;
  end if;

  v_raw_cost := coalesce(v_factory.operating_cost_remainder, 0) + v_expense * v_hours;
  v_cost := floor(v_raw_cost)::bigint;
  v_cost_remainder := v_raw_cost - v_cost;

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

  -- A sync that reaches the reserve is paused as well; a later sync resumes after funding.
  v_funds_exhausted := v_funds_exhausted or v_wallet.balance - v_cost <= v_min_balance;

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
    'is_active', not v_funds_exhausted,
    'minimum_balance', v_min_balance
  );
end
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
  if v_factory.upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  if v_factory.warehouse_upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
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

  v_duration_seconds := 120 * power(720::numeric, (v_target - 2)::numeric / 98);
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

create or replace function nexora.upgrade_factory_warehouse(p_uid text, p_factory_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cost bigint;
  v_target integer;
  v_ends timestamptz;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_costs bigint[] := array[1500,4000,10000,25000];
begin
  select * into v_factory from nexora.factories where id = p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid <> p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_level >= 5 then raise exception 'WAREHOUSE_MAX_LEVEL'; end if;
  if v_factory.warehouse_upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  if v_factory.upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  v_target := greatest(1, v_factory.warehouse_level) + 1;
  v_cost := v_costs[v_factory.warehouse_level];
  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_ends := now() + make_interval(mins => case v_target when 2 then 20 when 3 then 60 when 4 then 180 else 480 end);
  update nexora.wallets
  set balance = balance - v_cost, total_spent = total_spent + v_cost,
      last_tx_id = v_tx, updated_at = now()
  where user_id = p_uid;
  update nexora.factories
  set warehouse_upgrade_started_at = now(), warehouse_upgrade_ends_at = v_ends,
      warehouse_upgrade_target_level = v_target, warehouse_upgrade_cost = v_cost, updated_at = now()
  where id = p_factory_id;
  insert into nexora.transactions(
    id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
  ) values (
    v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_warehouse_upgrade',p_factory_id,
    'Factory warehouse expansion: ' || v_factory.name,'completed'
  );
  return jsonb_build_object(
    'target_level',v_target,'ends_at',v_ends,'cost',v_cost,
    'capacity',nexora.factory_warehouse_capacity(v_factory.resource_id,v_target)
  );
end
$function$;

create or replace function nexora.upgrade_company_vault(p_uid text, p_company_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_company nexora.companies%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_old integer;
  v_target integer;
  v_cost bigint;
  v_item1 text;
  v_qty1 integer;
  v_item2 text;
  v_qty2 integer;
  v_capacity bigint[] := array[3500,7000,14000,25000,40000];
  v_cap bigint;
  v_net bigint;
  v_preserved bigint;
  v_now timestamptz := now();
  v_elapsed numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_log text := 'clog_' || gen_random_uuid()::text;
  v_inv1 integer;
  v_inv2 integer;
  v_duration numeric;
  v_ends timestamptz;
begin
  select * into v_company from nexora.companies where id = p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid <> p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.vault_upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  v_old := greatest(1, least(5, v_company.vault_level));
  if v_old >= 5 then raise exception 'VAULT_MAX_LEVEL'; end if;
  case v_old
    when 1 then v_cost := 1500; v_item1 := 'copper_wire'; v_qty1 := 20; v_item2 := 'crude_alloy'; v_qty2 := 10;
    when 2 then v_cost := 4000; v_item1 := 'silicon_ore'; v_qty1 := 20; v_item2 := 'energy_cells'; v_qty2 := 15;
    when 3 then v_cost := 10000; v_item1 := 'carbon_fiber'; v_qty1 := 15; v_item2 := 'precision_frame'; v_qty2 := 10;
    when 4 then v_cost := 25000; v_item1 := 'rare_minerals'; v_qty1 := 20; v_item2 := 'quantum_server'; v_qty2 := 5;
  end case;
  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  select quantity into v_inv1 from nexora.inventory where user_id = p_uid and item_id = v_item1 for update;
  if not found or coalesce(v_inv1, 0) < v_qty1 then raise exception 'MISSING_VAULT_MATERIALS'; end if;
  select quantity into v_inv2 from nexora.inventory where user_id = p_uid and item_id = v_item2 for update;
  if not found or coalesce(v_inv2, 0) < v_qty2 then raise exception 'MISSING_VAULT_MATERIALS'; end if;
  v_net := nexora.company_net_hourly(p_company_id);
  v_cap := v_capacity[v_old];
  v_elapsed := greatest(0, extract(epoch from (v_now - coalesce(v_company.last_collected_at, v_now))) / 3600);
  v_preserved := least(v_cap, greatest(0, coalesce(v_company.vault_balance, 0) + floor(v_net * least(12, v_elapsed))::bigint));
  v_target := v_old + 1;
  if v_target <= 50 then
    v_duration := round(2000 * power(43200::numeric, (v_target - 2)::numeric / 48));
  else
    v_duration := round(86400000 * power(15::numeric, (v_target - 50)::numeric / 50));
  end if;
  -- v_duration is milliseconds; divide by 1000 so level 2 is two seconds, not one.
  v_ends := v_now + make_interval(secs => greatest(1, v_duration / 1000));
  update nexora.wallets
  set balance = balance - v_cost, total_spent = total_spent + v_cost,
      last_tx_id = v_tx, updated_at = now()
  where user_id = p_uid;
  update nexora.inventory set quantity = quantity - v_qty1, updated_at = now()
  where user_id = p_uid and item_id = v_item1;
  update nexora.inventory set quantity = quantity - v_qty2, updated_at = now()
  where user_id = p_uid and item_id = v_item2;
  update nexora.companies
  set vault_balance = v_preserved, last_collected_at = v_now,
      vault_upgrade_started_at = v_now, vault_upgrade_ends_at = v_ends,
      vault_upgrade_target_level = v_target, updated_at = now()
  where id = p_company_id;
  insert into nexora.transactions(
    id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
  ) values (
    v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_vault_upgrade',p_company_id,
    'Upgraded ' || v_company.name || ' profit vault to Lv.' || v_target::text,'completed'
  );
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'vault_upgrade',-v_cost,
         'Profit vault upgraded to Lv.' || v_target::text || '; preserved ' || v_preserved::text);
  return jsonb_build_object(
    'ok',true,'target_level',v_target,'ends_at',v_ends,
    'vault_balance',v_preserved,'capacity',v_cap
  );
end
$function$;

revoke all on function nexora.sync_factory_production(text,text) from public,anon,authenticated;
revoke all on function nexora.upgrade_factory(text,text) from public,anon,authenticated;
revoke all on function nexora.upgrade_factory_warehouse(text,text) from public,anon,authenticated;
revoke all on function nexora.upgrade_company_vault(text,text) from public,anon,authenticated;
grant execute on function nexora.sync_factory_production(text,text) to service_role;
grant execute on function nexora.upgrade_factory(text,text) to service_role;
grant execute on function nexora.upgrade_factory_warehouse(text,text) to service_role;
grant execute on function nexora.upgrade_company_vault(text,text) to service_role;
