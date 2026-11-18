-- Factory economy rebalance: lower entry cost and operating expenses, increase raw output.
-- Existing player-owned factories and stored resources are not modified.
create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
language sql immutable set search_path to ''
as $function$
  select cfg.founding_cost,cfg.production_rate,cfg.operating_cost,cfg.rarity_factor
  from (values
    ('copper_wire'::text, 1800::bigint, 8.00::numeric, 25.00::numeric, 1.00::numeric),
    ('silicon_ore', 2400, 7.00, 28.00, 1.20),
    ('energy_cells', 3200, 6.00, 32.00, 1.40),
    ('crude_alloy', 4200, 5.00, 35.00, 1.65),
    ('carbon_fiber', 6000, 4.00, 42.00, 2.10),
    ('rare_minerals', 9000, 3.00, 50.00, 3.60)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$function$;

create or replace function nexora.sync_factory_production(p_uid text, p_factory_id text)
returns jsonb language plpgsql security definer set search_path to ''
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
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if not v_factory.is_active then
    update nexora.factories set last_produced_at=now(),updated_at=now() where id=p_factory_id;
    return jsonb_build_object('produced',0,'operating_cost',0,'warehouse_qty',v_factory.warehouse_qty,'capacity',150+v_factory.level*100,'is_active',false);
  end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_capacity:=150+v_factory.level*100;
  v_space:=greatest(0,v_capacity-v_factory.warehouse_qty);
  v_elapsed:=least(12,greatest(0,extract(epoch from (now()-v_factory.last_produced_at))/3600));
  if v_space=0 or v_elapsed=0 then
    update nexora.factories set last_produced_at=now(),updated_at=now() where id=p_factory_id;
    return jsonb_build_object('produced',0,'operating_cost',0,'warehouse_qty',v_factory.warehouse_qty,'capacity',v_capacity);
  end if;
  -- Production scales much faster than running costs so advanced factories become worthwhile.
  v_rate:=v_cfg.production_rate*(1+greatest(0,v_factory.level-1)*0.90)*(1+v_factory.skill_level*0.02);
  v_expense:=v_cfg.operating_cost*(1+greatest(0,v_factory.level-1)*0.025)*(1-v_factory.skill_level*0.015);
  v_hours:=least(v_elapsed,greatest(0,(v_space-v_factory.production_remainder)/v_rate));
  v_raw_cost:=v_factory.operating_cost_remainder+v_expense*v_hours;
  v_cost:=floor(v_raw_cost)::bigint;
  if v_raw_cost>v_wallet.balance then
    v_hours:=greatest(0,(v_wallet.balance-v_factory.operating_cost_remainder)/v_expense);
    v_cost:=v_wallet.balance;
    v_cost_remainder:=0;
  else
    v_cost_remainder:=v_raw_cost-v_cost;
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
end
$function$;

create or replace function nexora.upgrade_factory(p_uid text, p_factory_id text)
returns jsonb language plpgsql security definer set search_path to ''
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
$function$;
