-- Restrict only the automated daily exchange stock to the six base raw resources.
-- Player listings remain available for all catalog resources; price bounds remain universal.

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
      ('rare_minerals',70)
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

-- Remove only the old automated daily listings for advanced resources.
-- Event-created listings and every player listing are deliberately untouched.
update nexora.market_listings
set status = 'cancelled', remaining_qty = 0, updated_at = now()
where seller_uid = 'SYSTEM'
  and id like 'sys_%'
  and status = 'active'
  and item_id not in (
    'silicon_ore','copper_wire','energy_cells','crude_alloy','carbon_fiber','rare_minerals'
  );

-- Match company progression: 2 minutes at level 2, scaling smoothly to 24 hours at level 100.
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

  v_duration_seconds := 120
    * power(720::numeric, (v_target - 2)::numeric / 98);
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
