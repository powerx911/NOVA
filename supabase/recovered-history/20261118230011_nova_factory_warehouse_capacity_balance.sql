-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118230011
-- Remote migration name: nova_factory_warehouse_capacity_balance
-- Source: Supabase postgres_logs at 2026-11-18 23:00:11 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.factory_warehouse_capacity(p_resource_id text,p_level integer)
returns bigint language sql immutable set search_path to '' as $function$
  select greatest(1,floor((array[3500,7000,14000,25000,40000]::bigint[])[greatest(1,least(5,coalesce(p_level,1)))]::numeric /
    case p_resource_id
      when 'copper_wire' then 28::numeric
      when 'silicon_ore' then 35::numeric
      when 'energy_cells' then 45::numeric
      when 'crude_alloy' then 40::numeric
      when 'carbon_fiber' then 55::numeric
      when 'rare_minerals' then 70::numeric
      else 30::numeric
    end))::bigint
$function$;

alter table nexora.factories alter column warehouse_level set default 1;
update nexora.factories set warehouse_level=1 where warehouse_level=0
  and warehouse_upgrade_ends_at is null and warehouse_upgrade_target_level is null;
alter table nexora.factories drop constraint if exists factories_warehouse_level_check;
alter table nexora.factories add constraint factories_warehouse_level_check check (warehouse_level between 1 and 5);

create or replace function nexora.sync_factory_production(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
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
$function$;

create or replace function nexora.upgrade_factory_warehouse(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
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
$function$;

create or replace function nexora.complete_factory_warehouse_upgrade(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
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
$function$;

revoke all on function nexora.factory_warehouse_capacity(text,integer) from public;
grant execute on function nexora.factory_warehouse_capacity(text,integer) to service_role;
revoke all on function nexora.upgrade_factory_warehouse(text,text) from public;
revoke all on function nexora.complete_factory_warehouse_upgrade(text,text) from public;
grant execute on function nexora.upgrade_factory_warehouse(text,text) to service_role;
grant execute on function nexora.complete_factory_warehouse_upgrade(text,text) to service_role;;
