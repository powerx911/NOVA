-- Company economy v2: align client/server values and price upgrades from incremental profit.

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
  select ceil(
    nexora.company_sector_level_gain(p_sector)
    * (5 + 0.75 * greatest(1, least(99, coalesce(p_level, 1))))
  )::bigint
$function$;

create or replace function nexora.company_net_hourly(p_company_id text)
returns bigint
language plpgsql stable security definer set search_path = ''
as $function$
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
  v_gross := round(
    (v_company.base_revenue_per_hour + (v_company.level - 1) * v_level_gain)
    * (1 + v_management * .08)
    * v_event_mult
    * (1 + v_tier)
    * (1 + least(.05, v_income_bonus * .005))
  );
  v_expense := round(
    v_company.expense_per_hour * (1 + (v_company.level - 1) * .08)
    * (1 - least(.45, v_finance * .05))
  );
  return greatest(15, v_gross - v_expense)::bigint;
end;
$function$;

-- Keep the guarded RPC but replace only its duration assignment, preserving all safety checks.
do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.start_company_upgrade(text,text)'::regprocedure) into v_definition;
  v_definition := regexp_replace(
    v_definition,
    'v_duration_ms[[:space:]]*:=([^\n;]*);',
    'v_duration_ms := round(15 * power(v_target::numeric, 1.1) * 60 * 1000);',
    'g'
  );
  v_definition := regexp_replace(
    v_definition,
    'v_duration[[:space:]]*:=([^\n;]*);',
    'v_duration := round(15 * power(v_target::numeric, 1.1) * 60 * 1000);',
    'g'
  );
  execute v_definition;
end
$patch$;

revoke all on function nexora.company_sector_level_gain(text) from public, anon, authenticated;
revoke all on function nexora.company_upgrade_cost(text, integer) from public, anon, authenticated;
revoke all on function nexora.company_net_hourly(text) from public, anon, authenticated;
grant execute on function nexora.company_sector_level_gain(text) to service_role;
grant execute on function nexora.company_upgrade_cost(text, integer) to service_role;
grant execute on function nexora.company_net_hourly(text) to service_role;
