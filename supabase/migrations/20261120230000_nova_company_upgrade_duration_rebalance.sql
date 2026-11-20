-- Shorten company upgrade durations while keeping a progressive late-game curve.
-- Client-side companyUpgradeDurationMs mirrors this formula exactly.

create or replace function nexora.company_upgrade_duration_seconds(p_target integer)
returns bigint language sql immutable set search_path = '' as $function$
  select greatest(60, round(8 * 60 * power(greatest(2, least(100, coalesce(p_target, 2)))::numeric, 1.05)))::bigint
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

revoke all on function nexora.company_upgrade_duration_seconds(integer) from public, anon, authenticated;
grant execute on function nexora.company_upgrade_duration_seconds(integer) to service_role;
