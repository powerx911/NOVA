create or replace function nexora.reset_player_skills(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_refund integer;
  v_cost bigint := 2500;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_profile from nexora.player_profiles where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_refund :=
    coalesce((v_profile.skills->>'trade')::integer, 0) +
    coalesce((v_profile.skills->>'management')::integer, 0) +
    coalesce((v_profile.skills->>'industry')::integer, 0) +
    coalesce((v_profile.skills->>'negotiation')::integer, 0) +
    coalesce((v_profile.skills->>'finance')::integer, 0) +
    coalesce((v_profile.skills->>'leadership')::integer, 0);
  if v_refund < 1 then raise exception 'NO_SKILLS_TO_RESET'; end if;

  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;

  update nexora.wallets
    set balance = balance - v_cost,
        total_spent = total_spent + v_cost,
        last_tx_id = v_tx,
        updated_at = now()
    where user_id = p_uid;

  update nexora.player_profiles
    set skills = jsonb_build_object(
      'trade', 0, 'management', 0, 'industry', 0,
      'negotiation', 0, 'finance', 0, 'leadership', 0
    ),
    skill_points = skill_points + v_refund,
    updated_at = now()
    where user_id = p_uid;

  insert into nexora.transactions(
    id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status
  ) values (
    v_tx, p_uid, 'SYSTEM', v_cost, 0, v_cost, 'skill_reset', p_uid,
    'Skill reset; refunded ' || v_refund::text || ' skill points', 'completed'
  );

  return jsonb_build_object('ok', true, 'refunded_points', v_refund, 'cost', v_cost);
end;
$$;

revoke all on function nexora.reset_player_skills(text) from public, anon, authenticated;
grant execute on function nexora.reset_player_skills(text) to service_role;

-- Factories produce raw resources only. All costs and production are enforced server-side.
create table if not exists nexora.factories (
  id text primary key,
  owner_uid text not null,
  owner_name text not null,
  name text not null check (char_length(name) between 2 and 48),
  resource_id text not null check (resource_id in ('silicon_ore','copper_wire','energy_cells','crude_alloy','carbon_fiber','rare_minerals')),
  level integer not null default 1 check (level between 1 and 50),
  skill_level integer not null default 0 check (skill_level between 0 and 10),
  is_active boolean not null default true,
  warehouse_qty bigint not null default 0 check (warehouse_qty >= 0),
  production_remainder numeric(12,6) not null default 0 check (production_remainder >= 0 and production_remainder < 1),
  operating_cost_remainder numeric(12,6) not null default 0 check (operating_cost_remainder >= 0 and operating_cost_remainder < 1),
  last_produced_at timestamptz not null default now(),
  upgrade_started_at timestamptz,
  upgrade_ends_at timestamptz,
  upgrade_target_level integer,
  upgrade_cost bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists factories_owner_created_idx on nexora.factories(owner_uid,created_at);
alter table nexora.factories enable row level security;
revoke all on nexora.factories from public,anon,authenticated;

create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
language sql immutable set search_path = '' as $$
  select cfg.founding_cost,cfg.production_rate,cfg.operating_cost,cfg.rarity_factor from (values
    ('copper_wire'::text, 5000::bigint, 5.00::numeric, 125.00::numeric, 1.00::numeric),
    ('silicon_ore', 6500, 4.20, 130.00, 1.20),
    ('energy_cells', 8000, 4.00, 140.00, 1.40),
    ('crude_alloy', 9500, 3.80, 145.00, 1.65),
    ('carbon_fiber', 12500, 3.00, 150.00, 2.10),
    ('rare_minerals', 26000, 2.50, 160.00, 3.60)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$$;

create or replace function nexora.found_factory(p_uid text,p_name text,p_resource_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_count integer;
  v_id text := 'fac_' || gen_random_uuid()::text;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  if p_name is null or char_length(btrim(p_name))<2 or char_length(btrim(p_name))>48 then raise exception 'INVALID_NAME'; end if;
  select * into v_cfg from nexora.factory_resource_config(p_resource_id);
  if not found then raise exception 'INVALID_RESOURCE'; end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select count(*) into v_count from nexora.factories where owner_uid=p_uid;
  if v_count>=3 then raise exception 'FACTORY_CAPACITY_REACHED'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cfg.founding_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;

  insert into nexora.factories(id,owner_uid,owner_name,name,resource_id,level,skill_level,warehouse_qty,last_produced_at)
  values(v_id,p_uid,v_profile.username,btrim(p_name),p_resource_id,1,0,0,now());
  update nexora.wallets set balance=balance-v_cfg.founding_cost,total_spent=total_spent+v_cfg.founding_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cfg.founding_cost,0,v_cfg.founding_cost,'factory_create',v_id,'Founded raw-resource factory: '||btrim(p_name),'completed');
  return jsonb_build_object('ok',true,'factory_id',v_id,'cost',v_cfg.founding_cost);
end $$;

create or replace function nexora.sync_factory_production(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
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

  v_rate:=v_cfg.production_rate*(1+greatest(0,v_factory.level-1)*0.08)*(1+v_factory.skill_level*0.02);
  v_expense:=v_cfg.operating_cost*(1+greatest(0,v_factory.level-1)*0.10)*(1-v_factory.skill_level*0.015);
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
  update nexora.factories set
    warehouse_qty=warehouse_qty+v_qty,
    production_remainder=v_production_remainder,
    operating_cost_remainder=v_cost_remainder,
    last_produced_at=now(),
    updated_at=now()
  where id=p_factory_id;
  return jsonb_build_object('produced',v_qty,'operating_cost',v_cost,'warehouse_qty',v_factory.warehouse_qty+v_qty,'capacity',v_capacity);
end $$;

create or replace function nexora.upgrade_factory(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
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
  if v_factory.level>=50 then raise exception 'MAX_LEVEL'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_target:=v_factory.level+1;
  v_cost:=ceil(v_cfg.founding_cost*0.65*power(v_factory.level::numeric,1.55))::bigint;
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
end $$;

create or replace function nexora.complete_factory_upgrade(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_factory nexora.factories%rowtype;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.upgrade_ends_at is null then raise exception 'NO_UPGRADE_IN_PROGRESS'; end if;
  if v_factory.upgrade_ends_at>now() then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  update nexora.factories set level=upgrade_target_level,upgrade_started_at=null,upgrade_ends_at=null,upgrade_target_level=null,upgrade_cost=null,updated_at=now() where id=p_factory_id;
  return jsonb_build_object('ok',true,'level',v_factory.upgrade_target_level);
end $$;

create or replace function nexora.upgrade_factory_skill(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_factory nexora.factories%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cfg record;
  v_cost bigint;
  v_materials integer;
  v_owned bigint;
  v_tx text := 'tx_' || gen_random_uuid()::text;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.skill_level>=10 then raise exception 'SKILL_MAXED'; end if;
  select * into v_cfg from nexora.factory_resource_config(v_factory.resource_id);
  v_cost:=ceil(v_cfg.founding_cost*0.18*power((v_factory.skill_level+1)::numeric,1.35))::bigint;
  v_materials:=ceil((v_factory.skill_level+1)*v_cfg.rarity_factor)::integer;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  select quantity into v_owned from nexora.inventory where user_id=p_uid and item_id=v_factory.resource_id for update;
  if not found or coalesce(v_owned,0)<v_materials then raise exception 'MISSING_FACTORY_MATERIALS'; end if;
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.inventory set quantity=quantity-v_materials,updated_at=now() where user_id=p_uid and item_id=v_factory.resource_id;
  update nexora.factories set skill_level=skill_level+1,updated_at=now() where id=p_factory_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_skill',p_factory_id,'Factory operator skill training: '||v_factory.name,'completed');
  return jsonb_build_object('ok',true,'skill_level',v_factory.skill_level+1,'cost',v_cost,'materials',v_materials);
end $$;

create or replace function nexora.set_factory_active(p_uid text,p_factory_id text,p_active boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_factory nexora.factories%rowtype;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  update nexora.factories set is_active=coalesce(p_active,false),last_produced_at=now(),updated_at=now() where id=p_factory_id;
  return jsonb_build_object('ok',true,'is_active',coalesce(p_active,false));
end $$;

create or replace function nexora.withdraw_factory_warehouse(p_uid text,p_factory_id text,p_quantity integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_factory nexora.factories%rowtype;
begin
  if p_quantity is null or p_quantity<1 or p_quantity>1000000 then raise exception 'INVALID_QUANTITY'; end if;
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_qty<p_quantity then raise exception 'WAREHOUSE_INSUFFICIENT_STOCK'; end if;
  update nexora.factories set warehouse_qty=warehouse_qty-p_quantity,updated_at=now() where id=p_factory_id;
  insert into nexora.inventory(user_id,item_id,quantity,updated_at) values(p_uid,v_factory.resource_id,p_quantity,now())
  on conflict(user_id,item_id) do update set quantity=nexora.inventory.quantity+excluded.quantity,updated_at=now();
  return jsonb_build_object('ok',true,'withdrawn',p_quantity,'remaining',v_factory.warehouse_qty-p_quantity);
end $$;

revoke all on function nexora.factory_resource_config(text) from public,anon,authenticated;
revoke all on function nexora.found_factory(text,text,text) from public,anon,authenticated;
revoke all on function nexora.sync_factory_production(text,text) from public,anon,authenticated;
revoke all on function nexora.upgrade_factory(text,text) from public,anon,authenticated;
revoke all on function nexora.complete_factory_upgrade(text,text) from public,anon,authenticated;
revoke all on function nexora.upgrade_factory_skill(text,text) from public,anon,authenticated;
revoke all on function nexora.withdraw_factory_warehouse(text,text,integer) from public,anon,authenticated;
revoke all on function nexora.set_factory_active(text,text,boolean) from public,anon,authenticated;
grant execute on function nexora.factory_resource_config(text) to service_role;
grant execute on function nexora.found_factory(text,text,text) to service_role;
grant execute on function nexora.sync_factory_production(text,text) to service_role;
grant execute on function nexora.upgrade_factory(text,text) to service_role;
grant execute on function nexora.complete_factory_upgrade(text,text) to service_role;
grant execute on function nexora.upgrade_factory_skill(text,text) to service_role;
grant execute on function nexora.withdraw_factory_warehouse(text,text,integer) to service_role;
grant execute on function nexora.set_factory_active(text,text,boolean) to service_role;
