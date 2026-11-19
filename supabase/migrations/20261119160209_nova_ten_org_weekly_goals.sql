alter table nexora.org_weekly_goals
  drop constraint if exists org_weekly_goals_goal_type_check;
alter table nexora.org_weekly_goals
  add constraint org_weekly_goals_goal_type_check check (goal_type = any (array[
    'produce_units','trade_volume','contracts_completed','treasury_donations',
    'personal_contracts_completed','org_contracts_completed','company_revenue',
    'factory_upgrades','company_upgrades','companies_founded','factories_founded'
  ]));

update nexora.contract_config
set config_value = jsonb_set(config_value,'{goal_count}','10'::jsonb,true),
    updated_at=now()
where config_key='weekly_goal_scaling';

insert into nexora.contract_config(config_key,config_value)
values ('weekly_goal_bases', '{
  "produce_units":250,
  "trade_volume":5000,
  "contracts_completed":8,
  "treasury_donations":2500,
  "personal_contracts_completed":5,
  "org_contracts_completed":3,
  "company_revenue":10000,
  "factory_upgrades":2,
  "company_upgrades":2,
  "companies_founded":1,
  "factories_founded":1
}'::jsonb)
on conflict(config_key) do update
set config_value=excluded.config_value,updated_at=now();

do $$
declare v_def text;
begin
  select pg_get_functiondef('nexora.ensure_org_weekly_goals(text)'::regprocedure) into v_def;
  v_def:=replace(v_def,$old$v_count integer;$old$,$new$v_count integer;
  v_existing text[];$new$);
  v_def:=replace(v_def,
    $old$v_types text[] := array['produce_units','trade_volume','contracts_completed','treasury_donations'];$old$,
    $new$v_types text[] := array['produce_units','trade_volume','treasury_donations','personal_contracts_completed','org_contracts_completed','company_revenue','factory_upgrades','company_upgrades','companies_founded','factories_founded'];$new$);
  v_def:=replace(v_def,
    $old$if exists(select 1 from nexora.org_weekly_goals where org_id=p_org_id and week_start=v_week) then return; end if;$old$,
    $new$select coalesce(array_agg(goal_type),array[]::text[]) into v_existing from nexora.org_weekly_goals where org_id=p_org_id and week_start=v_week;
  foreach v_type in array v_existing loop
    v_types:=array_remove(v_types,v_type);
  end loop;
  if cardinality(v_types)=0 then return; end if;$new$);
  v_def:=replace(v_def,$old$coalesce((v_scaling->>'goal_count')::integer,3)$old$,$new$coalesce((v_scaling->>'goal_count')::integer,10)$new$);
  v_def:=replace(v_def,
    $old$for v_count in 1..coalesce((v_scaling->>'goal_count')::integer,10) loop$old$,
    $new$for v_count in 1..least(coalesce((v_scaling->>'goal_count')::integer,10),cardinality(v_types)) loop$new$);
  v_def:=replace(v_def,
    $old$v_difficulty:=case v_type when 'produce_units' then 'easy' when 'trade_volume' then 'medium'
      when 'contracts_completed' then 'hard' else 'medium' end;$old$,
    $new$v_difficulty:=case when v_type in ('produce_units','companies_founded','factories_founded') then 'easy' when v_type in ('trade_volume','treasury_donations','company_revenue') then 'medium' else 'hard' end;$new$);
  if position('personal_contracts_completed' in v_def)=0 then
    raise exception 'WEEKLY_GOAL_GENERATOR_PATCH_FAILED';
  end if;
  execute v_def;
end;
$$;

do $$
declare v_def text;
begin
  select pg_get_functiondef('nexora.record_org_goal_progress(text,text,numeric)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    $old$('produce_units','trade_volume','contracts_completed','treasury_donations')$old$,
    $new$('produce_units','trade_volume','contracts_completed','treasury_donations','personal_contracts_completed','org_contracts_completed','company_revenue','factory_upgrades','company_upgrades','companies_founded','factories_founded')$new$);
  if position('personal_contracts_completed' in v_def)=0 then
    raise exception 'WEEKLY_GOAL_PROGRESS_PATCH_FAILED';
  end if;
  execute v_def;
end;
$$;

do $$
declare v_def text;
begin
  select pg_get_functiondef('nexora.claim_dynamic_contract(text,text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    $old$perform nexora.record_org_goal_progress(p_uid,'contracts_completed',1);$old$,
    $new$if v_contract.scope='personal' then
    perform nexora.record_org_goal_progress(p_uid,'personal_contracts_completed',1);
  else
    perform nexora.record_org_goal_progress(p_uid,'org_contracts_completed',1);
  end if;$new$);
  if position('personal_contracts_completed' in v_def)=0 then
    raise exception 'CONTRACT_GOAL_PROGRESS_PATCH_FAILED';
  end if;
  execute v_def;
end;
$$;



do $$
declare v_def text;
begin
  select pg_get_functiondef('nexora.get_org_weekly_goals(text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    $old$where g.org_id=v_org_id and g.week_start=date_trunc('week',timezone('UTC',now()))::date;$old$,
    $new$where g.org_id=v_org_id and g.week_start=date_trunc('week',timezone('UTC',now()))::date
    and g.goal_type<>'contracts_completed';$new$);
  if position('g.goal_type<>''contracts_completed''' in v_def)=0 then
    raise exception 'LEGACY_WEEKLY_GOAL_FILTER_PATCH_FAILED';
  end if;
  execute v_def;
end;
$$;

create or replace function nexora.record_org_goal_from_market_order()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform nexora.record_org_goal_progress(new.buyer_uid,'trade_volume',new.total_price);
  if new.seller_uid is not null and new.seller_uid is distinct from new.buyer_uid then
    perform nexora.record_org_goal_progress(new.seller_uid,'trade_volume',new.total_price);
  end if;
  return new;
end;
$$;

create or replace function nexora.record_org_goal_from_company_revenue()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_delta numeric;
begin
  v_delta:=new.total_revenue-old.total_revenue;
  if v_delta>0 then perform nexora.record_org_goal_progress(new.owner_uid,'company_revenue',v_delta); end if;
  return new;
end;
$$;
drop trigger if exists nova_org_goal_company_revenue on nexora.companies;
create trigger nova_org_goal_company_revenue after update of total_revenue on nexora.companies
for each row when (new.total_revenue>old.total_revenue)
execute function nexora.record_org_goal_from_company_revenue();

create or replace function nexora.record_org_goal_from_factory_upgrade()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.level>old.level then perform nexora.record_org_goal_progress(new.owner_uid,'factory_upgrades',1); end if;
  return new;
end;
$$;
drop trigger if exists nova_org_goal_factory_upgrade on nexora.factories;
create trigger nova_org_goal_factory_upgrade after update of level on nexora.factories
for each row when (new.level>old.level)
execute function nexora.record_org_goal_from_factory_upgrade();

create or replace function nexora.record_org_goal_from_company_upgrade()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.level>old.level then perform nexora.record_org_goal_progress(new.owner_uid,'company_upgrades',1); end if;
  return new;
end;
$$;
drop trigger if exists nova_org_goal_company_upgrade on nexora.companies;
create trigger nova_org_goal_company_upgrade after update of level on nexora.companies
for each row when (new.level>old.level)
execute function nexora.record_org_goal_from_company_upgrade();

create or replace function nexora.record_org_goal_from_company_founding()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform nexora.record_org_goal_progress(new.owner_uid,'companies_founded',1);
  return new;
end;
$$;
drop trigger if exists nova_org_goal_company_founding on nexora.companies;
create trigger nova_org_goal_company_founding after insert on nexora.companies
for each row execute function nexora.record_org_goal_from_company_founding();

create or replace function nexora.record_org_goal_from_factory_founding()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform nexora.record_org_goal_progress(new.owner_uid,'factories_founded',1);
  return new;
end;
$$;
drop trigger if exists nova_org_goal_factory_founding on nexora.factories;
create trigger nova_org_goal_factory_founding after insert on nexora.factories
for each row execute function nexora.record_org_goal_from_factory_founding();

revoke all on function nexora.record_org_goal_from_company_revenue() from public,anon,authenticated;
revoke all on function nexora.record_org_goal_from_factory_upgrade() from public,anon,authenticated;
revoke all on function nexora.record_org_goal_from_company_upgrade() from public,anon,authenticated;
revoke all on function nexora.record_org_goal_from_company_founding() from public,anon,authenticated;
revoke all on function nexora.record_org_goal_from_factory_founding() from public,anon,authenticated;
