-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118230131
-- Remote migration name: nova_factory_auction_capacity_reservations
-- Source: Supabase postgres_logs at 2026-11-18 23:01:31 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.found_factory(p_uid text,p_name text,p_resource_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
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
$function$;;
