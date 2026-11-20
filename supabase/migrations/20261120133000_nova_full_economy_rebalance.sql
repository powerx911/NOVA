-- Full business and factory economy rebalance.
-- All client formulas mirror these server-side curves.

create or replace function nexora.company_level_multiplier(p_level integer)
returns numeric language sql immutable set search_path = '' as $function$
  select 1 + 0.12 * power(greatest(0, least(99, coalesce(p_level, 1) - 1))::numeric, 0.9)
$function$;

create or replace function nexora.company_upgrade_cost(p_sector text, p_level integer)
returns bigint language sql immutable set search_path = '' as $function$
  select ceil((case p_sector
    when 'trade' then 1200 when 'services' then 2200 when 'logistics' then 3800
    when 'manufacturing' then 6000 when 'tech' then 9000 else 1200 end)::numeric
    * 0.30 * power(greatest(1, least(99, coalesce(p_level, 1)))::numeric, 1.18))::bigint
$function$;

create or replace function nexora.company_upgrade_duration_seconds(p_target integer)
returns bigint language sql immutable set search_path = '' as $function$
  select greatest(60, round(8 * 60 * power(greatest(2, least(100, coalesce(p_target, 2)))::numeric, 1.3)))::bigint
$function$;

create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
language sql immutable set search_path = '' as $function$
  select cfg.founding_cost, cfg.production_rate, cfg.operating_cost, cfg.rarity_factor from (values
    ('copper_wire',1800::bigint,20.000::numeric,500.00::numeric,1.00::numeric),
    ('silicon_ore',2800::bigint,18.000::numeric,520.00::numeric,1.20::numeric),
    ('energy_cells',4200::bigint,16.000::numeric,630.00::numeric,1.40::numeric),
    ('crude_alloy',6200::bigint,14.000::numeric,500.00::numeric,1.65::numeric),
    ('carbon_fiber',8500::bigint,11.000::numeric,520.00::numeric,2.10::numeric),
    ('rare_minerals',12000::bigint,8.000::numeric,500.00::numeric,3.60::numeric),
    ('titanium_ore',16000::bigint,7.000::numeric,530.00::numeric,4.00::numeric),
    ('polymer_resin',21000::bigint,6.000::numeric,500.00::numeric,4.50::numeric),
    ('biotech_gel',28000::bigint,4.000::numeric,430.00::numeric,5.00::numeric),
    ('quantum_dust',36000::bigint,3.000::numeric,390.00::numeric,6.00::numeric)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id = p_resource_id;
$function$;

-- Existing companies inherit the new sector baseline while keeping their current level.
update nexora.companies set
  base_revenue_per_hour = case sector when 'trade' then 160 when 'services' then 220 when 'logistics' then 300 when 'manufacturing' then 410 when 'tech' then 550 else base_revenue_per_hour end,
  expense_per_hour = case sector when 'trade' then 30 when 'services' then 60 when 'logistics' then 85 when 'manufacturing' then 120 when 'tech' then 160 else expense_per_hour end,
  updated_at = now()
where sector in ('trade','services','logistics','manufacturing','tech');

create or replace function nexora.found_company(p_uid text,p_name text,p_sector text)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_username text; v_cost bigint; v_revenue bigint; v_expense bigint; v_wallet nexora.wallets%rowtype;
  v_profile nexora.player_profiles%rowtype; v_id text:='cmp_'||gen_random_uuid()::text; v_tx text:='tx_'||gen_random_uuid()::text;
  v_log text:='clog_'||gen_random_uuid()::text; v_xp bigint; v_level integer:=1; v_remaining bigint; v_step bigint;
  v_gained integer; v_leadership numeric; v_stats jsonb;
begin
  if p_name is null or length(btrim(p_name))<2 or length(btrim(p_name))>48 then raise exception 'INVALID_NAME'; end if;
  case p_sector
    when 'trade' then v_cost:=1200; v_revenue:=160; v_expense:=30;
    when 'services' then v_cost:=2200; v_revenue:=220; v_expense:=60;
    when 'logistics' then v_cost:=3800; v_revenue:=300; v_expense:=85;
    when 'manufacturing' then v_cost:=6000; v_revenue:=410; v_expense:=120;
    when 'tech' then v_cost:=9000; v_revenue:=550; v_expense:=160;
    else raise exception 'INVALID_SECTOR';
  end case;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_username:=v_profile.username;
  insert into nexora.companies(id,owner_uid,owner_name,name,sector,level,capital,base_revenue_per_hour,expense_per_hour,total_revenue,vault_level,vault_balance,last_collected_at)
  values(v_id,p_uid,v_username,btrim(p_name),p_sector,1,v_cost,v_revenue,v_expense,0,1,0,now());
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_create',v_id,'Founded company: '||btrim(p_name),'completed');
  v_xp:=v_profile.xp+100; v_remaining:=v_xp;
  while v_level<200 loop v_step:=200+(v_level-1)*120; exit when v_remaining<v_step; v_remaining:=v_remaining-v_step; v_level:=v_level+1; end loop;
  v_gained:=greatest(0,v_level-v_profile.level); v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{companiesOwned}',to_jsonb(coalesce((v_profile.stats->>'companiesOwned')::integer,0)+1),true);
  update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,reputation=reputation+round(10*v_leadership)::bigint,influence=influence+round(8*v_leadership)::bigint,stats=v_stats,updated_at=now() where user_id=p_uid;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details) values(v_log,v_id,p_uid,'founded',-v_cost,'Company established in '||p_sector||' sector');
  return jsonb_build_object('ok',true,'company_id',v_id,'cost',v_cost);
end;
$function$;

-- Replace the income body while preserving reputation, skill and world-event modifiers.
create or replace function nexora.company_net_hourly(p_company_id text)
returns bigint language plpgsql stable security definer set search_path = '' as $function$
declare
  v_company nexora.companies%rowtype; v_profile nexora.player_profiles%rowtype;
  v_management numeric; v_finance numeric; v_tier numeric:=0; v_event_mult numeric:=1;
  v_seen text[]:='{}'; v_event record; v_income_bonus numeric:=0; v_gross numeric; v_expense numeric;
begin
  select * into v_company from nexora.companies where id=p_company_id; if not found then return 0; end if;
  select * into v_profile from nexora.player_profiles where user_id=v_company.owner_uid; if not found then return 0; end if;
  v_management:=greatest(0,coalesce((v_profile.skills->>'management')::numeric,0));
  v_finance:=greatest(0,coalesce((v_profile.skills->>'finance')::numeric,0));
  v_tier:=case when v_profile.reputation>=700 then .08 when v_profile.reputation>=350 then .06 when v_profile.reputation>=160 then .04 when v_profile.reputation>=60 then .02 else 0 end;
  if v_profile.org_id is not null then select greatest(0,least(10,coalesce((research->>'commerce')::numeric,0))) into v_income_bonus from nexora.organizations where id=v_profile.org_id; end if;
  for v_event in select group_key,revenue_multiplier,affected_sectors from (select distinct on (coalesce(nullif(stack_group,''),effect_type,id)) coalesce(nullif(stack_group,''),effect_type,id) group_key,revenue_multiplier,affected_sectors,starts_at from nexora.world_events where active=true and starts_at<=now() and ends_at>now() order by coalesce(nullif(stack_group,''),effect_type,id),starts_at desc) e order by group_key limit 3 loop
    if not (v_event.group_key=any(v_seen)) then v_seen:=array_append(v_seen,v_event.group_key); if coalesce(v_event.affected_sectors,'[]'::jsonb) @> jsonb_build_array(v_company.sector) then v_event_mult:=v_event_mult*coalesce(v_event.revenue_multiplier,1); end if; end if;
  end loop;
  v_event_mult:=greatest(.75,least(1.4,round(v_event_mult,3)));
  v_gross:=round(v_company.base_revenue_per_hour*nexora.company_level_multiplier(v_company.level)*(1+v_management*.08)*v_event_mult*(1+v_tier)*(1+least(.05,v_income_bonus*.005)));
  v_expense:=round(v_company.expense_per_hour*(1+greatest(0,v_company.level-1)*.08)*(1-least(.45,v_finance*.05)));
  return greatest(15,v_gross-v_expense)::bigint;
end;
$function$;

-- Patch existing guarded upgrade RPCs to the same cost and duration curves.
do $patch$
declare v_definition text;
begin
  select pg_get_functiondef('nexora.start_company_upgrade(text,text)'::regprocedure) into v_definition;
  v_definition:=replace(v_definition,'v_cost := nexora.company_upgrade_cost(v_company.sector, v_company.level);','v_cost := nexora.company_upgrade_cost(v_company.sector, v_company.level);');
  v_definition:=regexp_replace(v_definition,'v_duration_ms[[:space:]]*:=.*?;','v_duration_ms := nexora.company_upgrade_duration_seconds(v_target) * 1000;','');
  v_definition:=regexp_replace(v_definition,'v_duration[[:space:]]*:=.*?;','v_duration := nexora.company_upgrade_duration_seconds(v_target) * 1000;','');
  execute v_definition;
end $patch$;

do $patch$
declare v_definition text;
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure) into v_definition;
  v_definition:=regexp_replace(v_definition,'1[[:space:]]*\+[[:space:]]*0\.025[[:space:]]*\*[[:space:]]*greatest\(0, v_factory\.level - 1\)[[:space:]]*\+[[:space:]]*0\.00015[[:space:]]*\*[[:space:]]*power\(greatest\(0, v_factory\.level - 1\)::numeric, 2\)','1 + 0.04 * greatest(0, v_factory.level - 1) + 0.0003 * power(greatest(0, v_factory.level - 1)::numeric, 2)','g');
  v_definition:=regexp_replace(v_definition,'greatest\(0, v_factory\.level - 1\) \* 0\.06','greatest(0, v_factory.level - 1) * 0.018','g');
  v_definition:=replace(v_definition,'v_factory.skill_level * 0.03','v_factory.skill_level * 0.005');
  execute v_definition;
end $patch$;

do $patch$
declare v_definition text;
begin
  select pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure) into v_definition;
  v_definition:=regexp_replace(v_definition,'v_cost :=.*?;','v_cost := ceil(v_cfg.founding_cost * 0.22 * power(v_factory.level::numeric, 1.22))::bigint;');
  v_definition:=regexp_replace(v_definition,'v_duration_seconds :=.*?;','v_duration_seconds := 10 * 60 * power(v_target::numeric, 1.35);');
  execute v_definition;
end $patch$;

create or replace function nexora.upgrade_factory_warehouse(p_uid text,p_factory_id text)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare v_factory nexora.factories%rowtype; v_wallet nexora.wallets%rowtype; v_cost bigint; v_target integer; v_ends timestamptz; v_tx text:='tx_'||gen_random_uuid()::text; v_costs bigint[]:=array[2500,7000,18000,45000];
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update; if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.warehouse_level>=5 then raise exception 'WAREHOUSE_MAX_LEVEL'; end if;
  if v_factory.warehouse_upgrade_ends_at is not null or v_factory.upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  v_target:=greatest(1,v_factory.warehouse_level)+1; v_cost:=v_costs[v_factory.warehouse_level];
  select * into v_wallet from nexora.wallets where user_id=p_uid for update; if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_ends:=now()+make_interval(mins=>case v_target when 2 then 30 when 3 then 90 when 4 then 240 else 720 end);
  update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.factories set warehouse_upgrade_started_at=now(),warehouse_upgrade_ends_at=v_ends,warehouse_upgrade_target_level=v_target,warehouse_upgrade_cost=v_cost,updated_at=now() where id=p_factory_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status) values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'factory_warehouse_upgrade',p_factory_id,'Factory warehouse expansion: '||v_factory.name,'completed');
  return jsonb_build_object('target_level',v_target,'ends_at',v_ends,'cost',v_cost,'capacity',nexora.factory_warehouse_capacity(v_factory.resource_id,v_target));
end;
$function$;

-- Keep vault costs and durations aligned with the shared 5-level curve.
do $patch$
declare v_definition text;
begin
  select pg_get_functiondef('nexora.upgrade_company_vault(text,text)'::regprocedure) into v_definition;
  v_definition:=regexp_replace(v_definition,'when 1 then v_cost := 1500;','when 1 then v_cost := 2500;');
  v_definition:=regexp_replace(v_definition,'when 2 then v_cost := 4000;','when 2 then v_cost := 7000;');
  v_definition:=regexp_replace(v_definition,'when 3 then v_cost := 10000;','when 3 then v_cost := 18000;');
  v_definition:=regexp_replace(v_definition,'when 4 then v_cost := 25000;','when 4 then v_cost := 45000;');
  v_definition:=regexp_replace(v_definition,'v_duration := round\(2000 \* power\(43200::numeric, \(v_target - 2\)::numeric / 48\)\);','v_duration := round(case v_target when 2 then 20*60*1000 when 3 then 75*60*1000 when 4 then 240*60*1000 else 720*60*1000 end);');
  execute v_definition;
end $patch$;

revoke all on function nexora.company_level_multiplier(integer) from public,anon,authenticated;
revoke all on function nexora.company_upgrade_duration_seconds(integer) from public,anon,authenticated;
grant execute on function nexora.company_level_multiplier(integer) to service_role;
grant execute on function nexora.company_upgrade_duration_seconds(integer) to service_role;
