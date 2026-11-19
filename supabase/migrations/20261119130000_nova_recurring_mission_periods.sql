
-- Recurring mission claim periods. Existing one-time claims remain lifetime claims.
alter table nexora.player_missions
  add column if not exists period_key text not null default 'lifetime';

alter table nexora.player_missions
  drop constraint if exists player_missions_pkey;
alter table nexora.player_missions
  add constraint player_missions_pkey primary key (user_id,mission_id,period_key);

create or replace function nexora.claim_mission_reward(p_uid text,p_mission_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_category text;
  v_metric text;
  v_target integer;
  v_credits bigint;
  v_xp_gain integer;
  v_rep integer;
  v_title text;
  v_period_key text:='lifetime';
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_progress integer;
  v_claim text;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_xp bigint;
  v_level integer:=1;
  v_remaining bigint;
  v_step bigint;
  v_gained integer;
  v_leadership numeric;
  v_stats jsonb;
  v_day_start timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
begin
  case p_mission_id
    when 'tut_first_trade' then v_category:='tutorial';v_metric:='trades';v_target:=1;v_credits:=450;v_xp_gain:=90;v_rep:=10;v_title:='Enter the Open Market';
    when 'tut_first_production' then v_category:='tutorial';v_metric:='produced';v_target:=1;v_credits:=550;v_xp_gain:=110;v_rep:=15;v_title:='Start Production Line';
    when 'tut_first_company' then v_category:='tutorial';v_metric:='companies';v_target:=1;v_credits:=850;v_xp_gain:=160;v_rep:=25;v_title:='Found Your First Company';
    when 'daily_active_trader' then
      v_category:='daily';v_metric:='daily_trades';v_target:=3;v_credits:=600;v_xp_gain:=120;v_rep:=14;v_title:='Active Market Trader';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'weekly_real_estate' then
      v_category:='weekly';v_metric:='properties';v_target:=1;v_credits:=950;v_xp_gain:=210;v_rep:=28;v_title:='Real Estate Expansion';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'seasonal_syndicate' then
      v_category:='seasonal';v_metric:='org';v_target:=1;v_credits:=1200;v_xp_gain:=260;v_rep:=35;v_title:='Economic Syndicate Alliance';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    else raise exception 'INVALID_MISSION';
  end case;

  v_claim:=p_uid||'_'||p_mission_id||'_'||v_period_key;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;

  if exists(select 1 from nexora.player_missions
    where user_id=p_uid and mission_id=p_mission_id and period_key=v_period_key) then
    raise exception 'MISSION_ALREADY_CLAIMED';
  end if;

  v_progress:=case v_metric
    when 'daily_trades' then (
      select count(*)::integer from nexora.transactions
      where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_day_start
    )
    when 'trades' then coalesce((v_profile.stats->>'tradesCount')::integer,0)
    when 'produced' then coalesce((v_profile.stats->>'totalProduced')::integer,0)
    when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::integer,0)
    when 'properties' then coalesce((v_profile.stats->>'propertiesOwned')::integer,0)
    when 'org' then case when v_profile.org_id is null then 0 else 1 end
    else v_profile.level
  end;
  if v_progress<v_target then raise exception 'MISSION_NOT_COMPLETE';end if;

  insert into nexora.player_missions(user_id,mission_id,category,reward_credits,reward_xp,period_key)
    values(p_uid,p_mission_id,v_category,v_credits,v_xp_gain,v_period_key);

  update nexora.wallets set balance=balance+v_credits,total_earned=total_earned+v_credits,last_tx_id=v_tx,updated_at=now()
    where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,'SYSTEM',p_uid,v_credits,0,v_credits,'mission_reward',v_claim,'Mission reward: '||v_title,'completed');

  v_xp:=v_profile.xp+v_xp_gain;
  v_remaining:=v_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120;
    exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level:=v_level+1;
  end loop;
  v_gained:=greatest(0,v_level-v_profile.level);
  v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{missionsCompleted}',
    to_jsonb(coalesce((v_profile.stats->>'missionsCompleted')::integer,0)+1),true);

  -- Skill points are derived by enforce_skill_point_progression; do not write them here.
  update nexora.player_profiles set xp=v_xp,level=v_level,
    reputation=reputation+round(v_rep*v_leadership)::bigint,
    influence=influence+round(5*v_leadership)::bigint,stats=v_stats,updated_at=now()
    where user_id=p_uid;
  return jsonb_build_object('ok',true,'reward_credits',v_credits,'reward_xp',v_xp_gain,
    'period_key',v_period_key,'levels_gained',v_gained);
end;
$$;

revoke all on function nexora.claim_mission_reward(text,text) from public,anon,authenticated;
grant execute on function nexora.claim_mission_reward(text,text) to service_role;

-- The progression trigger is the single source of truth for skill points.
-- Strip legacy no-op assignments without changing the surrounding RPC behavior.
do $cleanup$
declare
  v_proc record;
  v_definition text;
  v_updated text;
begin
  for v_proc in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='nexora' and p.prokind='f'
      and p.proname in (
        'claim_daily_stipend',
        'complete_company_upgrade',
        'create_organization',
        'found_company',
        'fulfill_trade_contract',
        'manufacture_recipe'
      )
  loop
    v_definition:=pg_get_functiondef(v_proc.oid);
    v_updated:=regexp_replace(
      v_definition,
      'skill_points[[:space:]]*=[[:space:]]*skill_points[[:space:]]*\+[[:space:]]*[^,;]+,[[:space:]]*',
      '',
      'gi'
    );
    if v_updated<>v_definition then execute v_updated; end if;
  end loop;
end;
$cleanup$;
