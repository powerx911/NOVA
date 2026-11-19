-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118225603
-- Remote migration name: nova_factory_warehouse_and_level_100
-- Source: Supabase postgres_logs at 2026-11-18 22:56:03 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

alter table nexora.factories
  drop constraint if exists factories_level_check;
alter table nexora.factories
  add constraint factories_level_check check (level >= 1 and level <= 100),
  add column if not exists warehouse_level integer not null default 0,
  add column if not exists warehouse_upgrade_started_at timestamptz,
  add column if not exists warehouse_upgrade_ends_at timestamptz,
  add column if not exists warehouse_upgrade_target_level integer,
  add column if not exists warehouse_upgrade_cost bigint,
  add column if not exists auction_id text,
  add column if not exists auction_ends_at timestamptz,
  add column if not exists auction_status text;
alter table nexora.factories
  add constraint factories_warehouse_level_check check (warehouse_level >= 0 and warehouse_level <= 20);

alter table nexora.company_auctions
  add column if not exists asset_type text not null default 'company',
  add column if not exists factory_id text references nexora.factories(id) on delete set null;
alter table nexora.company_auctions
  alter column company_id drop not null;
alter table nexora.company_auctions
  add constraint company_auctions_asset_type_check check (asset_type in ('company','factory'));
alter table nexora.company_auctions
  drop constraint if exists company_auctions_company_level_check;
alter table nexora.company_auctions
  add constraint company_auctions_asset_level_check check (company_level >= 50);
create unique index if not exists company_auctions_factory_active_unique
  on nexora.company_auctions(factory_id) where factory_id is not null and status='active';
create unique index if not exists factories_auction_id_unique
  on nexora.factories(auction_id) where auction_id is not null;

create or replace function nexora.sync_factory_production(p_uid text, p_factory_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
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
  v_capacity:=150+v_factory.level*100+coalesce(v_factory.warehouse_level,0)*500;
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

create or replace function nexora.upgrade_factory_warehouse(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_cost bigint;
  v_target integer;
  v_ends timestamptz;
  v_tx text := 'tx_'||gen_random_uuid()::text;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_level>=20 then raise exception 'WAREHOUSE_MAX_LEVEL'; end if;
  if v_factory.warehouse_upgrade_ends_at is not null and v_factory.warehouse_upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;
  if v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_target:=v_factory.warehouse_level+1;
  v_cost:=ceil(v_cfg.founding_cost*0.65*power(v_target::numeric,1.45))::bigint;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_ends:=now()+make_interval(mins=>greatest(5,v_target*12));
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.factories set warehouse_upgrade_started_at=now(),warehouse_upgrade_ends_at=v_ends,
    warehouse_upgrade_target_level=v_target,warehouse_upgrade_cost=v_cost,updated_at=now() where id=p_factory_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_warehouse_upgrade',p_factory_id,'Factory warehouse expansion: '||v_factory.name,'completed');
  return jsonb_build_object('target_level',v_target,'ends_at',v_ends,'cost',v_cost,'capacity_increase',500);
end
$function$;

create or replace function nexora.complete_factory_warehouse_upgrade(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare v_factory nexora.factories%rowtype;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_upgrade_ends_at is null then raise exception 'NO_UPGRADE_IN_PROGRESS'; end if;
  if v_factory.warehouse_upgrade_ends_at>now() then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  update nexora.factories set warehouse_level=warehouse_upgrade_target_level,
    warehouse_upgrade_started_at=null,warehouse_upgrade_ends_at=null,warehouse_upgrade_target_level=null,
    warehouse_upgrade_cost=null,updated_at=now() where id=p_factory_id;
  return jsonb_build_object('ok',true,'warehouse_level',v_factory.warehouse_upgrade_target_level,
    'capacity',150+v_factory.level*100+v_factory.warehouse_upgrade_target_level*500);
end
$function$;

create or replace function nexora.fetch_company_auctions(p_uid text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
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
$function$;

revoke all on function nexora.upgrade_factory_warehouse(text,text) from public;
revoke all on function nexora.complete_factory_warehouse_upgrade(text,text) from public;
grant execute on function nexora.upgrade_factory_warehouse(text,text) to service_role;
grant execute on function nexora.complete_factory_warehouse_upgrade(text,text) to service_role;
;
