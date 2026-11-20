-- NOVA economy curves, scheduled settlement, and organization contract capacity.
-- This migration is appended after the audit guards so it is safe on the live schema.

-- Smooth company progression: sector-specific gains replace the old flat 32% multiplier.
create or replace function nexora.company_sector_level_gain(p_sector text)
returns numeric
language sql immutable
set search_path = ''
as $function$
  select case p_sector
    when 'trade' then 37.8::numeric
    when 'services' then 47.0::numeric
    when 'logistics' then 60.0::numeric
    when 'manufacturing' then 76.8::numeric
    when 'tech' then 97.8::numeric
    else 37.8::numeric
  end
$function$;

create or replace function nexora.company_upgrade_cost(p_sector text, p_level integer)
returns bigint
language sql immutable
set search_path = ''
as $function$
  select ceil(nexora.company_sector_level_gain(p_sector) * (20 + 2.5 * greatest(1, coalesce(p_level, 1))))::bigint
$function$;

create or replace function nexora.company_net_hourly(p_company_id text)
returns bigint language plpgsql stable security definer set search_path = '' as $function$
declare
  v_company nexora.companies%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_management numeric;
  v_finance numeric;
  v_tier numeric := 0;
  v_event_mult numeric := 1;
  v_seen text[] := '{}';
  v_event record;
  v_income_bonus numeric := 0;
  v_level_gain numeric;
  v_gross numeric;
  v_expense numeric;
begin
  select * into v_company from nexora.companies where id = p_company_id;
  if not found then return 0; end if;
  select * into v_profile from nexora.player_profiles where user_id = v_company.owner_uid;
  if not found then return 0; end if;
  v_management := greatest(0, coalesce((v_profile.skills->>'management')::numeric, 0));
  v_finance := greatest(0, coalesce((v_profile.skills->>'finance')::numeric, 0));
  v_tier := case
    when v_profile.reputation >= 700 then .08
    when v_profile.reputation >= 350 then .06
    when v_profile.reputation >= 160 then .04
    when v_profile.reputation >= 60 then .02
    else 0
  end;
  if v_profile.org_id is not null then
    select greatest(0, least(10, coalesce((research->>'commerce')::numeric, 0)))
      into v_income_bonus
      from nexora.organizations where id = v_profile.org_id;
  end if;
  for v_event in select group_key, revenue_multiplier, affected_sectors from (
    select distinct on (coalesce(nullif(stack_group, ''), effect_type, id))
      coalesce(nullif(stack_group, ''), effect_type, id) group_key,
      revenue_multiplier, affected_sectors, starts_at
    from nexora.world_events
    where active = true and starts_at <= now() and ends_at > now()
    order by coalesce(nullif(stack_group, ''), effect_type, id), starts_at desc
  ) e order by group_key limit 3 loop
    if not (v_event.group_key = any(v_seen)) then
      v_seen := array_append(v_seen, v_event.group_key);
      if coalesce(v_event.affected_sectors, '[]'::jsonb) @> jsonb_build_array(v_company.sector) then
        v_event_mult := v_event_mult * coalesce(v_event.revenue_multiplier, 1);
      end if;
    end if;
  end loop;
  v_event_mult := greatest(.75, least(1.4, round(v_event_mult::numeric, 3)));
  v_level_gain := nexora.company_sector_level_gain(v_company.sector);
  v_gross := round((v_company.base_revenue_per_hour + (v_company.level - 1) * v_level_gain)
    * (1 + v_management * .08) * v_event_mult * (1 + v_tier) * (1 + least(.05, v_income_bonus * .005)));
  v_expense := round(v_company.expense_per_hour * (1 + (v_company.level - 1) * .2)
    * (1 - least(.45, v_finance * .05)));
  return greatest(15, v_gross - v_expense)::bigint;
end;
$function$;

-- Apply the smooth company upgrade cost and duration to the existing guarded RPC.
do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.start_company_upgrade(text,text)'::regprocedure) into v_definition;
  v_definition := replace(v_definition,
    'v_cost := v_company.level * 550;',
    'v_cost := nexora.company_upgrade_cost(v_company.sector, v_company.level);');
  v_definition := replace(v_definition,
    'v_cost:=v_company.level*550;',
    'v_cost:=nexora.company_upgrade_cost(v_company.sector,v_company.level);');
  v_definition := regexp_replace(v_definition,
    'v_duration_ms[[:space:]]*:=.*?;','v_duration_ms := round(1.2 * power(v_target::numeric, 1.2) * 60 * 1000);','');
  v_definition := regexp_replace(v_definition,
    'v_duration[[:space:]]*:=.*?;','v_duration := round(1.2 * power(v_target::numeric, 1.2) * 60 * 1000);','');
  if position('company_upgrade_cost' in v_definition) = 0
     or position('power(v_target::numeric, 1.2)' in v_definition) = 0 then
    raise exception 'COMPANY_CURVE_PATCH_FAILED';
  end if;
  execute v_definition;
end
$patch$;

-- The operating-cost curve is 1% per factory level; production remains resource-specific
-- and convex as defined by factory_progression_multiplier().
do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure) into v_definition;
  v_definition := regexp_replace(v_definition,
    'greatest\(0, v_factory\.level - 1\) \* 0\.06',
    'greatest(0, v_factory.level - 1) * 0.01','g');
  v_definition := regexp_replace(v_definition,
    'greatest\(0,v_factory\.level-1\)\*0\.06',
    'greatest(0,v_factory.level-1)*0.01','g');
  if position('0.01' in v_definition) = 0 then
    raise exception 'FACTORY_OPERATING_COST_CURVE_PATCH_FAILED';
  end if;
  execute v_definition;
end
$patch$;

-- Automatic completion is idempotent: each RPC clears its own pending markers.
create or replace function nexora.settle_finished_upgrades()
returns integer
language plpgsql security definer set search_path = '' as $function$
declare
  v_row record;
  v_count integer := 0;
begin
  for v_row in select id, owner_uid from nexora.companies
    where level_upgrade_ends_at <= now() or vault_upgrade_ends_at <= now()
    order by id
  loop
    begin
      if exists(select 1 from nexora.companies where id=v_row.id and level_upgrade_ends_at <= now()) then
        perform nexora.complete_company_upgrade(v_row.owner_uid, v_row.id);
        v_count := v_count + 1;
      end if;
      if exists(select 1 from nexora.companies where id=v_row.id and vault_upgrade_ends_at <= now()) then
        perform nexora.complete_company_vault_upgrade(v_row.owner_uid, v_row.id);
        v_count := v_count + 1;
      end if;
    exception when others then
      raise warning 'Could not settle company upgrade %: %', v_row.id, sqlerrm;
    end;
  end loop;
  for v_row in select id, owner_uid from nexora.factories
    where upgrade_ends_at <= now() or warehouse_upgrade_ends_at <= now()
    order by id
  loop
    begin
      if exists(select 1 from nexora.factories where id=v_row.id and upgrade_ends_at <= now()) then
        perform nexora.complete_factory_upgrade(v_row.owner_uid, v_row.id);
        v_count := v_count + 1;
      end if;
      if exists(select 1 from nexora.factories where id=v_row.id and warehouse_upgrade_ends_at <= now()) then
        perform nexora.complete_factory_warehouse_upgrade(v_row.owner_uid, v_row.id);
        v_count := v_count + 1;
      end if;
    exception when others then
      raise warning 'Could not settle factory upgrade %: %', v_row.id, sqlerrm;
    end;
  end loop;
  return v_count;
end;
$function$;

-- Server-side company accrual keeps vaults current without requiring a player to open Business.
create or replace function nexora.settle_company_revenue()
returns integer
language plpgsql security definer set search_path = '' as $function$
declare
  v_row record;
  v_count integer := 0;
begin
  for v_row in select id, owner_uid from nexora.companies
    where last_collected_at is null or last_collected_at <= now() - interval '5 minutes'
    order by id
  loop
    begin
      perform nexora.collect_company_revenue(v_row.owner_uid, v_row.id);
      v_count := v_count + 1;
    exception when others then
      raise warning 'Could not settle company revenue %: %', v_row.id, sqlerrm;
    end;
  end loop;
  return v_count;
end;
$function$;

-- Organization contracts now allow three active reservations per member, matching personal contracts.
do $patch$
declare
  v_definition text;
  v_old text := $old$if exists(select 1 from nexora.contract_offers where scope='organization' and claimed_by=p_uid
      and status in ('accepted','processing','ready')) then raise exception 'ORG_ACTIVE_CONTRACT_LIMIT'; end if;$old$;
  v_new text := $new$select count(*) into v_active from nexora.contract_offers
      where scope='organization' and claimed_by=p_uid and status in ('accepted','processing','ready');
    if v_active>=3 then raise exception 'ORG_ACTIVE_CONTRACT_LIMIT'; end if;$new$;
begin
  select pg_get_functiondef('nexora.accept_dynamic_contract(text,text)'::regprocedure) into v_definition;
  v_definition := replace(v_definition, v_old, v_new);
  if position('where scope=''organization'' and claimed_by=p_uid' in v_definition)=0
     or position('v_active>=3' in v_definition)=0 then
    raise exception 'ORG_CONTRACT_LIMIT_PATCH_FAILED';
  end if;
  execute v_definition;
end
$patch$;

-- Keep database work portable when pg_cron is not installed in migration replay.
do $schedule$
declare
  v_job record;
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    for v_job in select jobid from cron.job where jobname in (
      'nova-finished-upgrades-settlement','nova-company-revenue-settlement'
    ) loop
      perform cron.unschedule(v_job.jobid);
    end loop;
    perform cron.schedule('nova-finished-upgrades-settlement','* * * * *',
      'select nexora.settle_finished_upgrades();');
    perform cron.schedule('nova-company-revenue-settlement','*/5 * * * *',
      'select nexora.settle_company_revenue();');
  end if;
end
$schedule$;

revoke all on function nexora.company_sector_level_gain(text) from public,anon,authenticated;
revoke all on function nexora.company_upgrade_cost(text,integer) from public,anon,authenticated;
revoke all on function nexora.settle_finished_upgrades() from public,anon,authenticated;
revoke all on function nexora.settle_company_revenue() from public,anon,authenticated;
grant execute on function nexora.company_sector_level_gain(text) to service_role;
grant execute on function nexora.company_upgrade_cost(text,integer) to service_role;
grant execute on function nexora.settle_finished_upgrades() to service_role;
grant execute on function nexora.settle_company_revenue() to service_role;
