-- Anchor the company upgrade curve to the requested level 12 -> 13 values.
-- Tech level 12 costs 3,612 credits and target level 13 takes exactly 11 minutes.

create or replace function nexora.company_upgrade_duration_seconds(p_target integer)
returns bigint language sql immutable set search_path = '' as $function$
  select greatest(60, round(
    11 * power(greatest(2, least(100, coalesce(p_target, 2)))::numeric / 13, .85) * 60
  ))::bigint
$function$;

create or replace function nexora.company_upgrade_cost(p_sector text, p_level integer)
returns bigint
language sql immutable
set search_path = ''
as $function$
  select ceil(
    nexora.company_sector_level_gain(p_sector)
    * (8 + 2.411 * greatest(1, least(99, coalesce(p_level, 1))))
  )::bigint
$function$;

do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.start_company_upgrade(text,text)'::regprocedure) into v_definition;
  v_definition := regexp_replace(
    v_definition,
    'v_duration_ms[[:space:]]*:=([^\n;]*);',
    'v_duration_ms := nexora.company_upgrade_duration_seconds(v_target) * 1000;',
    'g'
  );
  v_definition := regexp_replace(
    v_definition,
    'v_duration[[:space:]]*:=([^\n;]*);',
    'v_duration := nexora.company_upgrade_duration_seconds(v_target) * 1000;',
    'g'
  );
  execute v_definition;
end
$patch$;
