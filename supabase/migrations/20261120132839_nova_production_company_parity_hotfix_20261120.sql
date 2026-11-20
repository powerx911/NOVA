-- Production hotfix: make company upgrade charges, durations, income and refunds authoritative.

create or replace function nexora.company_sector_level_gain(p_sector text)
returns numeric
language sql immutable
set search_path = ''
as $function$
  select case coalesce(p_sector, 'trade')
    when 'trade' then 37.8::numeric
    when 'services' then 47::numeric
    when 'logistics' then 60::numeric
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
    * (8 + 2.411 * greatest(1, least(99, coalesce(p_level, 1))))
  )::bigint
$function$;

create or replace function nexora.company_upgrade_duration_seconds(p_target integer)
returns bigint
language sql immutable
set search_path = ''
as $function$
  select round(
    11 * power(greatest(2, least(100, coalesce(p_target, 2)))::numeric / 13, 0.85) * 60
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

create or replace function nexora.start_company_upgrade(p_uid text, p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_company nexora.companies%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_cost bigint;
  v_target integer;
  v_duration_ms numeric;
  v_ends timestamptz;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_log text := 'clog_' || gen_random_uuid()::text;
begin
  select * into v_company from nexora.companies where id = p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid <> p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.level >= 100 then raise exception 'MAX_LEVEL'; end if;
  if v_company.level_upgrade_started_at is not null
     or v_company.level_upgrade_ends_at is not null
     or v_company.level_upgrade_target_level is not null then
    raise exception 'UPGRADE_IN_PROGRESS';
  end if;
  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_target := v_company.level + 1;
  v_cost := nexora.company_upgrade_cost(v_company.sector, v_company.level);
  v_duration_ms := nexora.company_upgrade_duration_seconds(v_target) * 1000;
  if v_wallet.balance < v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_ends := now() + make_interval(secs => greatest(1, v_duration_ms / 1000));
  update nexora.wallets
  set balance = balance - v_cost, total_spent = total_spent + v_cost, last_tx_id = v_tx, updated_at = now()
  where user_id = p_uid;
  update nexora.companies
  set level_upgrade_started_at = now(), level_upgrade_ends_at = v_ends,
      level_upgrade_target_level = v_target, level_upgrade_cost = v_cost, updated_at = now()
  where id = p_company_id;
  insert into nexora.transactions(id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status)
  values(v_tx, p_uid, 'SYSTEM', v_cost, 0, v_cost, 'company_upgrade', p_company_id,
    'Started upgrade of ' || v_company.name || ' to Lv.' || v_target::text, 'completed');
  insert into nexora.company_logs(id, company_id, owner_uid, action, amount, details)
  values(v_log, p_company_id, p_uid, 'upgrade_started', -v_cost, 'Started upgrade to Level ' || v_target::text);
  return jsonb_build_object('ok', true, 'target_level', v_target, 'ends_at', v_ends, 'duration_ms', v_duration_ms, 'cost', v_cost);
end;
$function$;

revoke all on function nexora.company_sector_level_gain(text) from public, anon, authenticated;
revoke all on function nexora.company_upgrade_cost(text, integer) from public, anon, authenticated;
revoke all on function nexora.company_upgrade_duration_seconds(integer) from public, anon, authenticated;
revoke all on function nexora.company_net_hourly(text) from public, anon, authenticated;
grant execute on function nexora.company_sector_level_gain(text) to service_role;
grant execute on function nexora.company_upgrade_cost(text, integer) to service_role;
grant execute on function nexora.company_upgrade_duration_seconds(integer) to service_role;
grant execute on function nexora.company_net_hourly(text) to service_role;

-- Idempotent reconciliation for legacy company upgrade charges (level * 550).
do $repair$
declare
  v_charge record;
  v_target integer;
  v_expected bigint;
  v_refund bigint;
  v_tx text;
begin
  for v_charge in
    select t.id, t.from_uid, t.amount, t.description, c.sector
    from nexora.transactions t
    join nexora.companies c on c.id = t.reference_id
    where t.type = 'company_upgrade'
      and t.status = 'completed'
      and t.description ~ 'Lv\.[0-9]+'
      and t.amount = (substring(t.description from 'Lv\.([0-9]+)')::integer - 1) * 550
      and not exists (
        select 1 from nexora.transactions r
        where r.type = 'company_upgrade_refund' and r.reference_id = t.id
      )
  loop
    v_target := substring(v_charge.description from 'Lv\.([0-9]+)')::integer;
    if v_target between 2 and 100 then
      v_expected := nexora.company_upgrade_cost(v_charge.sector, v_target - 1);
      v_refund := v_charge.amount - v_expected;
      if v_refund > 0 then
        v_tx := 'tx_' || gen_random_uuid()::text;
        update nexora.wallets
        set balance = balance + v_refund, total_earned = total_earned + v_refund,
            last_tx_id = v_tx, updated_at = now()
        where user_id = v_charge.from_uid;
        if found then
          insert into nexora.transactions(id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status)
          values(v_tx, 'SYSTEM', v_charge.from_uid, v_refund, 0, v_refund,
            'company_upgrade_refund', v_charge.id,
            'Refund for legacy company upgrade charge; corrected to shared cost curve', 'completed');
        end if;
      end if;
    end if;
  end loop;
end
$repair$;