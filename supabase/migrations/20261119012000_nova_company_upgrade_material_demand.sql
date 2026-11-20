-- Add sector- and tier-specific material demand to company level upgrades.
-- Materials are taken from the owner's inventory atomically with the credit charge.

create or replace function nexora.start_company_upgrade(p_uid text,p_company_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company nexora.companies%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cost bigint;
  v_target integer;
  v_duration numeric;
  v_ends timestamptz;
  v_item1 text;
  v_qty1 integer;
  v_item2 text;
  v_qty2 integer;
  v_inv1 integer;
  v_inv2 integer;
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

  v_target:=v_company.level+1;
  -- Early upgrades use common materials; later tiers introduce advanced inputs.
  case v_company.sector
    when 'trade' then
      if v_target<=10 then v_item1:='copper_wire';v_qty1:=3;v_item2:='silicon_ore';v_qty2:=2;
      elsif v_target<=25 then v_item1:='polymer_resin';v_qty1:=2;v_item2:='microchips';v_qty2:=2;
      elsif v_target<=50 then v_item1:='titanium_ore';v_qty1:=3;v_item2:='precision_frame';v_qty2:=2;
      else v_item1:='quantum_dust';v_qty1:=1;v_item2:='quantum_server';v_qty2:=1; end if;
    when 'manufacturing' then
      if v_target<=10 then v_item1:='crude_alloy';v_qty1:=3;v_item2:='carbon_fiber';v_qty2:=2;
      elsif v_target<=25 then v_item1:='titanium_ore';v_qty1:=2;v_item2:='precision_frame';v_qty2:=2;
      elsif v_target<=50 then v_item1:='biotech_gel';v_qty1:=2;v_item2:='bio_module';v_qty2:=1;
      else v_item1:='quantum_dust';v_qty1:=1;v_item2:='quantum_server';v_qty2:=1; end if;
    when 'services' then
      if v_target<=10 then v_item1:='energy_cells';v_qty1:=3;v_item2:='polymer_resin';v_qty2:=2;
      elsif v_target<=25 then v_item1:='biotech_gel';v_qty1:=2;v_item2:='bio_module';v_qty2:=1;
      elsif v_target<=50 then v_item1:='rare_minerals';v_qty1:=3;v_item2:='bio_module';v_qty2:=2;
      else v_item1:='quantum_dust';v_qty1:=1;v_item2:='quantum_server';v_qty2:=1; end if;
    when 'tech' then
      if v_target<=10 then v_item1:='silicon_ore';v_qty1:=3;v_item2:='microchips';v_qty2:=2;
      elsif v_target<=25 then v_item1:='polymer_resin';v_qty1:=2;v_item2:='synth_polymer';v_qty2:=2;
      elsif v_target<=50 then v_item1:='biotech_gel';v_qty1:=2;v_item2:='bio_module';v_qty2:=2;
      else v_item1:='quantum_dust';v_qty1:=2;v_item2:='quantum_server';v_qty2:=1; end if;
    when 'logistics' then
      if v_target<=10 then v_item1:='carbon_fiber';v_qty1:=3;v_item2:='precision_frame';v_qty2:=2;
      elsif v_target<=25 then v_item1:='titanium_ore';v_qty1:=2;v_item2:='logistics_drone';v_qty2:=1;
      elsif v_target<=50 then v_item1:='rare_minerals';v_qty1:=3;v_item2:='logistics_drone';v_qty2:=2;
      else v_item1:='quantum_dust';v_qty1:=1;v_item2:='logistics_drone';v_qty2:=2; end if;
    else
      raise exception 'INVALID_COMPANY_SECTOR';
  end case;

  select quantity into v_inv1 from nexora.inventory
    where user_id=p_uid and item_id=v_item1 for update;
  if not found or coalesce(v_inv1,0)<v_qty1 then raise exception 'MISSING_COMPANY_MATERIALS'; end if;
  select quantity into v_inv2 from nexora.inventory
    where user_id=p_uid and item_id=v_item2 for update;
  if not found or coalesce(v_inv2,0)<v_qty2 then raise exception 'MISSING_COMPANY_MATERIALS'; end if;

  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_cost:=v_company.level*550;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  if v_target<=50 then
    v_duration:=round(2000*power(43200::numeric,(v_target-2)::numeric/48));
  else
    v_duration:=round(86400000*power(15::numeric,(v_target-50)::numeric/50));
  end if;
  v_ends:=now()+make_interval(secs=>greatest(1,v_duration/1000));

  update nexora.inventory set quantity=quantity-v_qty1,updated_at=now()
    where user_id=p_uid and item_id=v_item1;
  update nexora.inventory set quantity=quantity-v_qty2,updated_at=now()
    where user_id=p_uid and item_id=v_item2;
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now()
    where user_id=p_uid;
  update nexora.companies set level_upgrade_started_at=now(),level_upgrade_ends_at=v_ends,
    level_upgrade_target_level=v_target,level_upgrade_cost=v_cost,updated_at=now()
    where id=p_company_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_upgrade',p_company_id,
    'Started upgrade of '||v_company.name||' to Lv.'||v_target::text||
    ' using '||v_qty1::text||' '||v_item1||' and '||v_qty2::text||' '||v_item2,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
  values(v_log,p_company_id,p_uid,'upgrade_started',-v_cost,
    'Started upgrade to Level '||v_target::text||'; consumed '||
    v_qty1::text||' '||v_item1||' and '||v_qty2::text||' '||v_item2);
  return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_ends,
    'materials',jsonb_build_object(v_item1,v_qty1,v_item2,v_qty2));
end;
$$;

revoke all on function nexora.start_company_upgrade(text,text) from public,anon,authenticated;
grant execute on function nexora.start_company_upgrade(text,text) to service_role;
