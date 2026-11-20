-- Keep the company upgrade RPC on the shared client/server cost and duration curves.
-- Also refund historical charges produced by the legacy level * 550 formula.

do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.start_company_upgrade(text,text)'::regprocedure) into v_definition;
  v_definition := regexp_replace(
    v_definition,
    'v_cost[[:space:]]*:=([^\n;]*);',
    'v_cost := nexora.company_upgrade_cost(v_company.sector, v_company.level);',
    'g'
  );
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

-- Return the same authoritative hourly net income and currently collectable amount
-- that collect_company_revenue will use. The bootstrap endpoint exposes these
-- values so the UI never has to reconstruct server-side event/rounding rules.
create or replace function nexora.company_collectable_amount(p_company_id text)
returns jsonb
language plpgsql stable security definer set search_path = ''
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
  if not found then
    return jsonb_build_object('net_hourly', 0, 'collectable', 0);
  end if;
  v_net := nexora.company_net_hourly(p_company_id);
  v_vault_level := greatest(1, least(5, v_company.vault_level));
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

do $repair$
declare
  v_charge record;
  v_target integer;
  v_expected bigint;
  v_refund bigint;
  v_tx text;
begin
  for v_charge in
    select t.id, t.from_uid, t.amount, t.reference_id, t.description, c.sector
    from nexora.transactions t
    join nexora.companies c on c.id = t.reference_id
    where t.type = 'company_upgrade'
      and t.status = 'completed'
      and t.description ~ 'Lv\.[0-9]+'
      and t.amount = (substring(t.description from 'Lv\.([0-9]+)')::integer - 1) * 550
      and not exists (
        select 1 from nexora.transactions r
        where r.type = 'company_upgrade_refund'
          and r.reference_id = t.id
      )
  loop
    v_target := substring(v_charge.description from 'Lv\.([0-9]+)')::integer;
    if v_target between 2 and 100 then
      v_expected := nexora.company_upgrade_cost(v_charge.sector, v_target - 1);
      v_refund := v_charge.amount - v_expected;
      if v_refund > 0 then
        v_tx := 'tx_' || gen_random_uuid()::text;
        update nexora.wallets
        set balance = balance + v_refund,
            total_earned = total_earned + v_refund,
            last_tx_id = v_tx,
            updated_at = now()
        where user_id = v_charge.from_uid;
        if found then
          insert into nexora.transactions(
            id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status
          ) values (
            v_tx, 'SYSTEM', v_charge.from_uid, v_refund, 0, v_refund,
            'company_upgrade_refund', v_charge.id,
            'Refund for company upgrade cost mismatch', 'completed'
          );
        end if;
      end if;
    end if;
  end loop;
end
$repair$;
