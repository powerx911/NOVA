-- NOVA production parity repair: make factory, warehouse, vault and contract RPCs
-- use the exact economy curves presented by the current client.
-- No player balances, inventories, or historical transactions are rewritten.

create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
language sql immutable set search_path = '' as $function$
  select cfg.founding_cost, cfg.production_rate, cfg.operating_cost, cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,20.000::numeric,500.00::numeric,1.00::numeric),
    ('silicon_ore',2800,18.000,520.00,1.20),
    ('energy_cells',4200,16.000,630.00,1.40),
    ('crude_alloy',6200,14.000,500.00,1.65),
    ('carbon_fiber',8500,11.000,520.00,2.10),
    ('rare_minerals',12000,8.000,500.00,3.60),
    ('titanium_ore',16000,7.000,530.00,4.00),
    ('polymer_resin',21000,6.000,500.00,4.50),
    ('biotech_gel',28000,4.000,430.00,5.00),
    ('quantum_dust',36000,3.000,390.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id = p_resource_id;
$function$;

-- Preserve the ten distinct, accelerating resource curves requested by the factory progression system.
create or replace function nexora.factory_progression_multiplier(p_resource_id text, p_level integer)
returns numeric language sql immutable set search_path = '' as $function$
  with curve as (
    select
      case p_resource_id
        when 'copper_wire' then 0.028::numeric when 'silicon_ore' then 0.030::numeric
        when 'energy_cells' then 0.032::numeric when 'crude_alloy' then 0.034::numeric
        when 'carbon_fiber' then 0.036::numeric when 'rare_minerals' then 0.038::numeric
        when 'titanium_ore' then 0.040::numeric when 'polymer_resin' then 0.042::numeric
        when 'biotech_gel' then 0.044::numeric when 'quantum_dust' then 0.046::numeric
        else 0.028::numeric
      end as linear_growth,
      case p_resource_id
        when 'copper_wire' then 0.00020::numeric when 'silicon_ore' then 0.00022::numeric
        when 'energy_cells' then 0.00024::numeric when 'crude_alloy' then 0.00026::numeric
        when 'carbon_fiber' then 0.00028::numeric when 'rare_minerals' then 0.00030::numeric
        when 'titanium_ore' then 0.00032::numeric when 'polymer_resin' then 0.00034::numeric
        when 'biotech_gel' then 0.00036::numeric when 'quantum_dust' then 0.00038::numeric
        else 0.00020::numeric
      end as quadratic_growth
  )
  select 1
    + linear_growth * greatest(0, coalesce(p_level, 1) - 1)
    + quadratic_growth * power(greatest(0, coalesce(p_level, 1) - 1)::numeric, 2)
  from curve
$function$;

-- Preserve the existing guarded factory-upgrade RPC; replace only its price and timer formulas.
do $patch$
declare v_definition text;
begin
  select pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure) into v_definition;
  v_definition := replace(v_definition,
    'v_cost:=ceil(v_cfg.founding_cost*0.18*power(v_factory.level::numeric,1.25))::bigint;',
    'v_cost:=ceil(v_cfg.founding_cost*0.22*power(v_factory.level::numeric,1.22))::bigint;');
  v_definition := replace(v_definition,
    'v_duration_seconds:=120*power(720::numeric,(v_target-2)::numeric/98);',
    'v_duration_seconds:=600*power(v_target::numeric,1.35);');
  if position('0.22*power(v_factory.level::numeric,1.22)' in v_definition)=0
     or position('600*power(v_target::numeric,1.35)' in v_definition)=0 then
    raise exception 'FACTORY_UPGRADE_PARITY_PATCH_FAILED';
  end if;
  execute v_definition;
end
$patch$;

-- Match the displayed warehouse cost and time arrays exactly.
create or replace function nexora.upgrade_factory_warehouse(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cost bigint;
  v_target integer;
  v_ends timestamptz;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_costs bigint[]:=array[2500,7000,18000,45000];
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_level>=5 then raise exception 'WAREHOUSE_MAX_LEVEL'; end if;
  if v_factory.warehouse_upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  if v_factory.upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  v_target:=greatest(1,v_factory.warehouse_level)+1;
  v_cost:=v_costs[v_factory.warehouse_level];
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_ends:=now()+make_interval(mins=>case v_target when 2 then 30 when 3 then 90 when 4 then 240 else 720 end);
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.factories set warehouse_upgrade_started_at=now(),warehouse_upgrade_ends_at=v_ends,
    warehouse_upgrade_target_level=v_target,warehouse_upgrade_cost=v_cost,updated_at=now() where id=p_factory_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_warehouse_upgrade',p_factory_id,'Factory warehouse expansion: '||v_factory.name,'completed');
  return jsonb_build_object('target_level',v_target,'ends_at',v_ends,'cost',v_cost,
    'capacity',nexora.factory_warehouse_capacity(v_factory.resource_id,v_target));
end;
$function$;

-- Keep the factory operating-cost and operator-skill curves equal to the UI.
do $patch$
declare v_definition text;
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure) into v_definition;
  v_definition := replace(v_definition,
    'greatest(0,v_factory.level-1)*0.025',
    'greatest(0,v_factory.level-1)*0.018');
  if position('greatest(0,v_factory.level-1)*0.018' in v_definition)=0 then
    raise exception 'FACTORY_OPERATING_CURVE_PATCH_FAILED';
  end if;
  execute v_definition;
end
$patch$;

-- Vault UI defines four upgrades: costs 2,500/7,000/18,000/45,000
-- and durations 20m/75m/4h/12h. Preserve existing ownership, inventory,
-- locking, accrual-preservation and transaction guards.
do $patch$
declare v_definition text;
begin
  select pg_get_functiondef('nexora.upgrade_company_vault(text,text)'::regprocedure) into v_definition;
  v_definition := replace(v_definition,
    'when 1 then v_cost:=1500;', 'when 1 then v_cost:=2500;');
  v_definition := replace(v_definition,
    'when 2 then v_cost:=4000;', 'when 2 then v_cost:=7000;');
  v_definition := replace(v_definition,
    'when 3 then v_cost:=10000;', 'when 3 then v_cost:=18000;');
  v_definition := replace(v_definition,
    'when 4 then v_cost:=25000;', 'when 4 then v_cost:=45000;');
  v_definition := regexp_replace(v_definition,
    'if v_target<=50 then v_duration:=.*?;[[:space:]]*else v_duration:=.*?; end if;',
    'v_duration:=case v_target when 2 then 1200 when 3 then 4500 when 4 then 14400 else 43200 end;',
    'n');
  v_definition := replace(v_definition,
    'make_interval(secs=>greatest(1,v_duration/2000))',
    'make_interval(secs=>greatest(1,v_duration))');
  if position('v_cost:=2500' in v_definition)=0
     or position('v_cost:=7000' in v_definition)=0
     or position('when 2 then 1200' in v_definition)=0
     or position('v_duration))' in v_definition)=0 then
    raise exception 'COMPANY_VAULT_PARITY_PATCH_FAILED';
  end if;
  execute v_definition;
end
$patch$;

-- Keep the one-active-organization-contract-per-member rule consistent with
-- the partial unique index and the regression contract lifecycle tests.
do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.accept_dynamic_contract(text,text)'::regprocedure)
    into v_definition;
  if position('ORG_ACTIVE_CONTRACT_LIMIT' in v_definition)=0 then
    raise exception 'ORG_CONTRACT_LIMIT_GUARD_MISSING';
  end if;
end
$patch$;

-- Add idempotent server settlement for completed upgrades. Cron is installed only
-- when pg_cron exists; no player records are modified until their normal RPC runs.
create or replace function nexora.settle_finished_upgrades()
returns integer language plpgsql security definer set search_path = '' as $function$
declare
  v_row record;
  v_count integer:=0;
begin
  for v_row in
    select id,owner_uid from nexora.companies
    where level_upgrade_ends_at<=now() or vault_upgrade_ends_at<=now()
    order by id
  loop
    begin
      if exists(select 1 from nexora.companies where id=v_row.id and level_upgrade_ends_at<=now()) then
        perform nexora.complete_company_upgrade(v_row.owner_uid,v_row.id);
        v_count:=v_count+1;
      end if;
      if exists(select 1 from nexora.companies where id=v_row.id and vault_upgrade_ends_at<=now()) then
        perform nexora.complete_company_vault_upgrade(v_row.owner_uid,v_row.id);
        v_count:=v_count+1;
      end if;
    exception when others then
      raise warning 'Could not settle company upgrade %: %',v_row.id,sqlerrm;
    end;
  end loop;
  for v_row in
    select id,owner_uid from nexora.factories
    where upgrade_ends_at<=now() or warehouse_upgrade_ends_at<=now()
    order by id
  loop
    begin
      if exists(select 1 from nexora.factories where id=v_row.id and upgrade_ends_at<=now()) then
        perform nexora.complete_factory_upgrade(v_row.owner_uid,v_row.id);
        v_count:=v_count+1;
      end if;
      if exists(select 1 from nexora.factories where id=v_row.id and warehouse_upgrade_ends_at<=now()) then
        perform nexora.complete_factory_warehouse_upgrade(v_row.owner_uid,v_row.id);
        v_count:=v_count+1;
      end if;
    exception when others then
      raise warning 'Could not settle factory upgrade %: %',v_row.id,sqlerrm;
    end;
  end loop;
  return v_count;
end;
$function$;

do $schedule$
declare v_job record;
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    for v_job in select jobid from cron.job where jobname='nova-finished-upgrades-settlement' loop
      perform cron.unschedule(v_job.jobid);
    end loop;
    perform cron.schedule('nova-finished-upgrades-settlement','* * * * *',
      'select nexora.settle_finished_upgrades();');
  end if;
end
$schedule$;

revoke all on function nexora.settle_finished_upgrades() from public,anon,authenticated;
grant execute on function nexora.settle_finished_upgrades() to service_role;
