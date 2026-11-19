-- RECOVERED UNTRACKED SQL EXECUTION — NOT A MIGRATION LEDGER ENTRY
-- PostgreSQL log timestamp: 2026-11-18 17:41:39 UTC
-- Source: postgres_logs client-backend statement event; POST /mcp metadata stripped.
-- Recovered 2026-11-19. SQL body preserved as logged.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.found_company(p_uid text,p_name text,p_sector text)
returns jsonb language plpgsql security definer set search_path = '' as $$
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
$$;

create or replace function nexora.buy_property(p_uid text,p_name text,p_type text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_cost bigint; v_rent bigint; v_maintenance bigint; v_wallet nexora.wallets%rowtype;
  v_profile nexora.player_profiles%rowtype; v_id text := 'prop_' || gen_random_uuid()::text;
  v_tx text := 'tx_' || gen_random_uuid()::text; v_xp bigint; v_level integer:=1;
  v_remaining bigint; v_step bigint; v_gained integer; v_leadership numeric; v_stats jsonb;
begin
  if p_name is null or length(btrim(p_name))<2 or length(btrim(p_name))>48 then raise exception 'INVALID_NAME'; end if;
  case p_type
    when 'shop' then v_cost:=950; v_rent:=115; v_maintenance:=25;
    when 'office' then v_cost:=1650; v_rent:=205; v_maintenance:=45;
    when 'facility' then v_cost:=2800; v_rent:=350; v_maintenance:=80;
    else raise exception 'INVALID_PROPERTY_TYPE';
  end case;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  insert into nexora.properties(id,owner_uid,name,property_type,level,purchase_price,rent_per_hour,maintenance_per_hour,is_rented,last_collected_at)
  values(v_id,p_uid,btrim(p_name),p_type,1,v_cost,v_rent,v_maintenance,true,now());
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'property_buy',v_id,'Acquired property: ' || btrim(p_name),'completed');
  v_xp:=v_profile.xp+90; v_remaining:=v_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120; exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step; v_level:=v_level+1;
  end loop;
  v_gained:=greatest(0,v_level-v_profile.level); v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{propertiesOwned}',to_jsonb(coalesce((v_profile.stats->>'propertiesOwned')::integer,0)+1),true);
  update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,
    reputation=reputation+round(8*v_leadership)::bigint,influence=influence+round(6*v_leadership)::bigint,
    stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'property_id',v_id);
end;
$$;

create or replace function nexora.toggle_property_lease(p_uid text,p_property_id text,p_next_state boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  update nexora.properties set is_rented=p_next_state,updated_at=now() where id=p_property_id and owner_uid=p_uid;
  if not found then raise exception 'PROPERTY_NOT_FOUND_OR_UNAUTHORIZED'; end if;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function nexora.upgrade_property(p_uid text,p_property_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_property nexora.properties%rowtype; v_wallet nexora.wallets%rowtype; v_cost bigint; v_tx text:='tx_'||gen_random_uuid()::text;
begin
  select * into v_property from nexora.properties where id=p_property_id for update;
  if not found then raise exception 'PROPERTY_NOT_FOUND'; end if;
  if v_property.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_property.level>=15 then raise exception 'MAX_LEVEL'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_cost:=v_property.level*480;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.properties set level=level+1,updated_at=now() where id=p_property_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'property_upgrade',p_property_id,'Upgraded property '||v_property.name||' to Lv.'||(v_property.level+1)::text,'completed');
  return jsonb_build_object('ok',true,'level',v_property.level+1);
end;
$$;

create or replace function nexora.collect_property_rent(p_uid text,p_property_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_property nexora.properties%rowtype; v_wallet nexora.wallets%rowtype; v_profile nexora.player_profiles%rowtype;
  v_now timestamptz:=now(); v_elapsed numeric; v_gross numeric; v_maintenance numeric; v_net numeric;
  v_payout bigint; v_tx text:='tx_'||gen_random_uuid()::text;
begin
  select * into v_property from nexora.properties where id=p_property_id for update;
  if not found then raise exception 'PROPERTY_NOT_FOUND'; end if;
  if v_property.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if not v_property.is_rented then raise exception 'PROPERTY_VACANT'; end if;
  if v_property.last_collected_at is null or v_now-v_property.last_collected_at<interval '60 seconds' then raise exception 'NOTHING_TO_COLLECT'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  select * into v_profile from nexora.player_profiles where user_id=p_uid;
  if not found or v_wallet.user_id is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_gross:=round(v_property.rent_per_hour*(1+(v_property.level-1)*0.28)*(1+greatest(0,coalesce((v_profile.skills->>'negotiation')::numeric,0))*0.07));
  v_maintenance:=round(v_property.maintenance_per_hour*(1+(v_property.level-1)*0.15));
  v_net:=v_gross-v_maintenance;
  if v_net<=0 then raise exception 'PROPERTY_VACANT'; end if;
  v_elapsed:=least(12,greatest(0,extract(epoch from (v_now-v_property.last_collected_at))/3600));
  v_payout:=least(15000,floor(v_net*v_elapsed)::bigint);
  if v_payout<1 then raise exception 'NOTHING_TO_COLLECT'; end if;
  update nexora.wallets set balance=balance+v_payout,total_earned=total_earned+v_payout,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.properties set last_collected_at=v_now,updated_at=v_now where id=p_property_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_payout,0,v_payout,'property_collect',p_property_id,'Collected rent from '||v_property.name,'completed');
  return jsonb_build_object('ok',true,'payout',v_payout);
end;
$$;

revoke all on function nexora.found_company(text,text,text) from public,anon,authenticated;
revoke all on function nexora.buy_property(text,text,text) from public,anon,authenticated;
revoke all on function nexora.toggle_property_lease(text,text,boolean) from public,anon,authenticated;
revoke all on function nexora.upgrade_property(text,text) from public,anon,authenticated;
revoke all on function nexora.collect_property_rent(text,text) from public,anon,authenticated;
grant execute on function nexora.found_company(text,text,text) to service_role;
grant execute on function nexora.buy_property(text,text,text) to service_role;
grant execute on function nexora.toggle_property_lease(text,text,boolean) to service_role;
grant execute on function nexora.upgrade_property(text,text) to service_role;
grant execute on function nexora.collect_property_rent(text,text) to service_role;
