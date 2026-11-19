-- NOVA mission and achievement progression redesign.
-- All recurring progress is calculated from completed ledger transactions in UTC.
create or replace function nexora.claim_mission_reward(p_uid text,p_mission_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category text;
  v_metric text;
  v_target bigint;
  v_credits bigint;
  v_xp_gain integer;
  v_rep integer;
  v_title text;
  v_period_key text:='lifetime';
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_progress bigint;
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
  v_week_start timestamptz:=date_trunc('week',now() at time zone 'UTC') at time zone 'UTC';
  v_quarter_start timestamptz:=date_trunc('quarter',now() at time zone 'UTC') at time zone 'UTC';
begin
  case p_mission_id
    when 'tut_first_trade' then v_category:='tutorial';v_metric:='trades';v_target:=1;v_credits:=450;v_xp_gain:=90;v_rep:=10;v_title:='Enter the Market';
    when 'tut_first_production' then v_category:='tutorial';v_metric:='produced';v_target:=1;v_credits:=550;v_xp_gain:=110;v_rep:=15;v_title:='First Production';
    when 'tut_first_company' then v_category:='tutorial';v_metric:='companies';v_target:=1;v_credits:=850;v_xp_gain:=160;v_rep:=25;v_title:='Found Your Company';

    when 'daily_active_trader' then v_category:='daily';v_metric:='daily_market_buys';v_target:=3;v_credits:=600;v_xp_gain:=120;v_rep:=14;v_title:='Active Market Trader';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'daily_market_orders' then v_category:='daily';v_metric:='daily_market_buys';v_target:=5;v_credits:=700;v_xp_gain:=110;v_rep:=12;v_title:='Market Activity';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'daily_factory_shift' then v_category:='daily';v_metric:='daily_manufacturing';v_target:=3;v_credits:=950;v_xp_gain:=145;v_rep:=16;v_title:='Production Shift';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'daily_market_volume' then v_category:='daily';v_metric:='daily_market_spend';v_target:=2500;v_credits:=1100;v_xp_gain:=155;v_rep:=18;v_title:='Capital in Motion';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
    when 'daily_company_cycle' then v_category:='daily';v_metric:='daily_company_collections';v_target:=2;v_credits:=1300;v_xp_gain:=175;v_rep:=20;v_title:='Operating Cycle';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY-MM-DD');

    when 'weekly_market_mogul' then v_category:='weekly';v_metric:='weekly_market_buys';v_target:=20;v_credits:=1500;v_xp_gain:=300;v_rep:=35;v_title:='Weekly Market Mogul';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'weekly_market_network' then v_category:='weekly';v_metric:='weekly_market_buys';v_target:=35;v_credits:=4200;v_xp_gain:=520;v_rep:=48;v_title:='Supply Network';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'weekly_industrial_output' then v_category:='weekly';v_metric:='weekly_manufacturing';v_target:=25;v_credits:=5200;v_xp_gain:=650;v_rep:=58;v_title:='Sustained Output';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'weekly_capital_flow' then v_category:='weekly';v_metric:='weekly_market_spend';v_target:=30000;v_credits:=6500;v_xp_gain:=760;v_rep:=68;v_title:='Investment Flow';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
    when 'weekly_corporate_returns' then v_category:='weekly';v_metric:='weekly_company_collections';v_target:=12;v_credits:=7800;v_xp_gain:=900;v_rep:=80;v_title:='Corporate Returns';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');

    when 'seasonal_syndicate' then v_category:='seasonal';v_metric:='org';v_target:=1;v_credits:=1200;v_xp_gain:=260;v_rep:=35;v_title:='Economic Syndicate Alliance';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    when 'seasonal_market_leadership' then v_category:='seasonal';v_metric:='seasonal_market_buys';v_target:=250;v_credits:=22000;v_xp_gain:=1900;v_rep:=190;v_title:='Market Leadership';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    when 'seasonal_industry_scale' then v_category:='seasonal';v_metric:='seasonal_manufacturing';v_target:=180;v_credits:=28000;v_xp_gain:=2400;v_rep:=230;v_title:='Industrial Scale';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    when 'seasonal_capital_commitment' then v_category:='seasonal';v_metric:='seasonal_market_spend';v_target:=500000;v_credits:=38000;v_xp_gain:=3200;v_rep:=300;v_title:='Capital Commitment';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;
    when 'seasonal_corporate_scale' then v_category:='seasonal';v_metric:='seasonal_company_collections';v_target:=75;v_credits:=50000;v_xp_gain:=4000;v_rep:=360;v_title:='Portfolio Management';
      v_period_key:=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text;

    -- Backward compatibility for clients that were open before the update.
    when 'weekly_real_estate' then v_category:='weekly';v_metric:='properties';v_target:=1;v_credits:=950;v_xp_gain:=210;v_rep:=28;v_title:='Real Estate Expansion';
      v_period_key:=to_char(now() at time zone 'UTC','IYYY-"W"IW');
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
    when 'daily_market_buys' then (select count(*) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_day_start)
    when 'daily_manufacturing' then (select count(*) from nexora.transactions where from_uid=p_uid and type='manufacturing' and status='completed' and created_at>=v_day_start)
    when 'daily_company_collections' then (select count(*) from nexora.transactions where to_uid=p_uid and type='company_collect' and status='completed' and created_at>=v_day_start)
    when 'daily_market_spend' then (select coalesce(sum(amount),0) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_day_start)
    when 'weekly_market_buys' then (select count(*) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_week_start)
    when 'weekly_manufacturing' then (select count(*) from nexora.transactions where from_uid=p_uid and type='manufacturing' and status='completed' and created_at>=v_week_start)
    when 'weekly_market_spend' then (select coalesce(sum(amount),0) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_week_start)
    when 'weekly_company_collections' then (select count(*) from nexora.transactions where to_uid=p_uid and type='company_collect' and status='completed' and created_at>=v_week_start)
    when 'seasonal_market_buys' then (select count(*) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_quarter_start)
    when 'seasonal_manufacturing' then (select count(*) from nexora.transactions where from_uid=p_uid and type='manufacturing' and status='completed' and created_at>=v_quarter_start)
    when 'seasonal_market_spend' then (select coalesce(sum(amount),0) from nexora.transactions where from_uid=p_uid and type='market_buy' and status='completed' and created_at>=v_quarter_start)
    when 'seasonal_company_collections' then (select count(*) from nexora.transactions where to_uid=p_uid and type='company_collect' and status='completed' and created_at>=v_quarter_start)
    when 'trades' then coalesce((v_profile.stats->>'tradesCount')::bigint,0)
    when 'produced' then coalesce((v_profile.stats->>'totalProduced')::bigint,0)
    when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::bigint,0)
    when 'properties' then coalesce((v_profile.stats->>'propertiesOwned')::bigint,0)
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

create or replace function nexora.unlock_eligible_achievements(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_new_ids text[] := '{}'::text[];
  v_all_ids text[] := '{}'::text[];
  v_achievement_id text;
  v_reward bigint;
  v_tx text;
  v_revenue bigint;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select coalesce(sum(amount),0) into v_revenue
  from nexora.transactions
  where to_uid=p_uid and type='company_collect' and status='completed';

  with eligible as (
    select a.id
    from (values
      ('nova_whale_i','spent',50000,2000),
      ('nova_whale_ii','spent',250000,8000),
      ('nova_whale_iii','spent',1000000,25000),
      ('nova_whale_iv','spent',5000000,75000),
      ('nova_market_i','trades',250,1500),
      ('nova_market_ii','trades',1000,6000),
      ('nova_market_iii','trades',5000,25000),
      ('nova_market_iv','trades',20000,75000),
      ('nova_industry_i','produced',500,2000),
      ('nova_industry_ii','produced',2500,8000),
      ('nova_industry_iii','produced',10000,30000),
      ('nova_industry_iv','produced',50000,90000),
      ('nova_enterprise_i','revenue',100000,5000),
      ('nova_enterprise_ii','revenue',500000,15000),
      ('nova_enterprise_iii','revenue',2000000,50000),
      ('nova_enterprise_iv','revenue',10000000,150000)
    ) as a(id,metric,threshold,reward)
    where case a.metric
      when 'spent' then v_wallet.total_spent
      when 'trades' then coalesce((v_profile.stats->>'tradesCount')::bigint,0)
      when 'produced' then coalesce((v_profile.stats->>'totalProduced')::bigint,0)
      when 'revenue' then v_revenue
      else 0
    end >= a.threshold
  ), inserted as (
    insert into nexora.player_achievements(user_id,achievement_id)
    select p_uid,eligible.id from eligible
    on conflict(user_id,achievement_id) do nothing
    returning achievement_id
  )
  select coalesce(array_agg(achievement_id),'{}'::text[]) into v_new_ids from inserted;

  foreach v_achievement_id in array v_new_ids loop
    select reward into v_reward from (values
      ('nova_whale_i',2000::bigint),('nova_whale_ii',8000::bigint),('nova_whale_iii',25000::bigint),('nova_whale_iv',75000::bigint),
      ('nova_market_i',1500::bigint),('nova_market_ii',6000::bigint),('nova_market_iii',25000::bigint),('nova_market_iv',75000::bigint),
      ('nova_industry_i',2000::bigint),('nova_industry_ii',8000::bigint),('nova_industry_iii',30000::bigint),('nova_industry_iv',90000::bigint),
      ('nova_enterprise_i',5000::bigint),('nova_enterprise_ii',15000::bigint),('nova_enterprise_iii',50000::bigint),('nova_enterprise_iv',150000::bigint)
    ) as rewards(id,reward) where id=v_achievement_id;
    if coalesce(v_reward,0)>0 then
      v_tx:='tx_'||gen_random_uuid()::text;
      update nexora.wallets set balance=balance+v_reward,total_earned=total_earned+v_reward,last_tx_id=v_tx,updated_at=now()
      where user_id=p_uid;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,'SYSTEM',p_uid,v_reward,0,v_reward,'mission_reward',v_achievement_id,'NOVA achievement reward: '||v_achievement_id,'completed');
    end if;
  end loop;

  select coalesce(array_agg(achievement_id),'{}'::text[]) into v_all_ids
  from nexora.player_achievements where user_id=p_uid;
  return jsonb_build_object(
    'unlocked_ids',v_all_ids,
    'newly_unlocked_ids',v_new_ids,
    'new_rewards',coalesce((
      select sum(reward) from (values
        ('nova_whale_i',2000::bigint),('nova_whale_ii',8000::bigint),('nova_whale_iii',25000::bigint),('nova_whale_iv',75000::bigint),
        ('nova_market_i',1500::bigint),('nova_market_ii',6000::bigint),('nova_market_iii',25000::bigint),('nova_market_iv',75000::bigint),
        ('nova_industry_i',2000::bigint),('nova_industry_ii',8000::bigint),('nova_industry_iii',30000::bigint),('nova_industry_iv',90000::bigint),
        ('nova_enterprise_i',5000::bigint),('nova_enterprise_ii',15000::bigint),('nova_enterprise_iii',50000::bigint),('nova_enterprise_iv',150000::bigint)
      ) as rewards(id,reward) where id=any(v_new_ids)
    ),0)
  );
end;
$$;
revoke all on function nexora.unlock_eligible_achievements(text) from public,anon,authenticated;
grant execute on function nexora.unlock_eligible_achievements(text) to service_role;
