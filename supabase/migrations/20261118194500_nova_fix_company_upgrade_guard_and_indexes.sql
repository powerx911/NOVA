-- Prevent repeated charges while a company or vault upgrade is awaiting completion.
-- Normalize client-facing timestamp columns to epoch milliseconds in the Edge Function.

create or replace function nexora.start_company_upgrade(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_company nexora.companies%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cost bigint;
  v_target integer;
  v_duration numeric;
  v_ends timestamptz;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_log text:='clog_'||gen_random_uuid()::text;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.level>=100 then raise exception 'MAX_LEVEL'; end if;
  if v_company.level_upgrade_started_at is not null
     or v_company.level_upgrade_ends_at is not null
     or v_company.level_upgrade_target_level is not null then
    raise exception 'UPGRADE_IN_PROGRESS';
  end if;

  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_cost:=v_company.level*550;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_target:=v_company.level+1;
  if v_target<=50 then
    v_duration:=round(2000*power(43200::numeric,(v_target-2)::numeric/48));
  else
    v_duration:=round(86400000*power(15::numeric,(v_target-50)::numeric/50));
  end if;
  v_ends:=now()+make_interval(secs=>greatest(1,v_duration/1000));

  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.companies set level_upgrade_started_at=now(),level_upgrade_ends_at=v_ends,
    level_upgrade_target_level=v_target,level_upgrade_cost=v_cost,updated_at=now() where id=p_company_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_upgrade',p_company_id,
    'Started upgrade of '||v_company.name||' to Lv.'||v_target::text,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'upgrade_started',-v_cost,'Started upgrade to Level '||v_target::text);
  return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_ends);
end;
$$;

create or replace function nexora.upgrade_company_vault(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
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
    when 1 then v_cost:=1500;v_item1:='copper_wire';v_qty1:=20;v_item2:='crude_alloy';v_qty2:=10;
    when 2 then v_cost:=4000;v_item1:='silicon_ore';v_qty1:=20;v_item2:='energy_cells';v_qty2:=15;
    when 3 then v_cost:=10000;v_item1:='carbon_fiber';v_qty1:=15;v_item2:='precision_frame';v_qty2:=10;
    when 4 then v_cost:=25000;v_item1:='rare_minerals';v_qty1:=20;v_item2:='quantum_server';v_qty2:=5;
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
  if v_target<=50 then
    v_duration:=round(2000*power(43200::numeric,(v_target-2)::numeric/48));
  else
    v_duration:=round(86400000*power(15::numeric,(v_target-50)::numeric/50));
  end if;
  v_ends:=v_now+make_interval(secs=>greatest(1,v_duration/2000));

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
$$;

-- Cover foreign-key lookups used by company history and market order joins.
create index if not exists company_logs_company_id_idx on nexora.company_logs(company_id);
create index if not exists market_orders_listing_id_idx on nexora.market_orders(listing_id);
create index if not exists market_orders_tx_id_idx on nexora.market_orders(tx_id);

revoke all on function nexora.start_company_upgrade(text,text) from public,anon,authenticated;
revoke all on function nexora.upgrade_company_vault(text,text) from public,anon,authenticated;
grant execute on function nexora.start_company_upgrade(text,text) to service_role;
grant execute on function nexora.upgrade_company_vault(text,text) to service_role;
