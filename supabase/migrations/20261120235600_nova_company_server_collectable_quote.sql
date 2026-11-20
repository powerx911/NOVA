-- Restore the read-only server quote consumed by the authenticated bootstrap API.
-- This does not collect revenue or mutate company balances.
create or replace function nexora.company_collectable_amount(p_company_id text)
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare
  v_company nexora.companies%rowtype;
  v_capacity bigint[] := array[3500,7000,14000,25000,40000];
  v_vault_level integer;
  v_net bigint;
  v_elapsed numeric;
  v_accrued bigint;
begin
  select * into v_company from nexora.companies where id = p_company_id;
  if not found then return jsonb_build_object('net_hourly', 0, 'collectable', 0); end if;
  v_net := nexora.company_net_hourly(p_company_id);
  v_vault_level := greatest(1, least(5, coalesce(v_company.vault_level, 1)));
  v_elapsed := greatest(0, extract(epoch from (now() - coalesce(v_company.last_collected_at, now()))) / 3600);
  v_accrued := least(
    v_capacity[v_vault_level],
    greatest(0, coalesce(v_company.vault_balance, 0) + floor(v_net * least(12, v_elapsed))::bigint)
  );
  return jsonb_build_object('net_hourly', v_net, 'collectable', v_accrued);
end;
$function$;
revoke all on function nexora.company_collectable_amount(text) from public, anon, authenticated;
grant execute on function nexora.company_collectable_amount(text) to service_role;
