create or replace function nexora.claim_mission_reward(p_uid text,p_mission_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_category text;v_metric text;v_target integer;v_credits bigint;v_xp_gain integer;v_rep integer;v_title text;
 v_profile nexora.player_profiles%rowtype;v_wallet nexora.wallets%rowtype;v_progress integer;v_claim text:=p_uid||'_'||p_mission_id;
 v_tx text:='tx_'||gen_random_uuid()::text;v_xp bigint;v_level integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_leadership numeric;v_stats jsonb;
begin
 case p_mission_id
  when 'tut_first_trade' then v_category:='tutorial';v_metric:='trades';v_target:=1;v_credits:=450;v_xp_gain:=90;v_rep:=10;v_title:='Enter the Open Market';
  when 'tut_first_production' then v_category:='tutorial';v_metric:='produced';v_target:=1;v_credits:=550;v_xp_gain:=110;v_rep:=15;v_title:='Start Production Line';
  when 'tut_first_company' then v_category:='tutorial';v_metric:='companies';v_target:=1;v_credits:=850;v_xp_gain:=160;v_rep:=25;v_title:='Found Your First Company';
  when 'daily_active_trader' then v_category:='daily';v_metric:='trades';v_target:=3;v_credits:=600;v_xp_gain:=120;v_rep:=14;v_title:='Active Market Trader';
  when 'weekly_real_estate' then v_category:='weekly';v_metric:='properties';v_target:=1;v_credits:=950;v_xp_gain:=210;v_rep:=28;v_title:='Real Estate Expansion';
  when 'seasonal_syndicate' then v_category:='seasonal';v_metric:='org';v_target:=1;v_credits:=1200;v_xp_gain:=260;v_rep:=35;v_title:='Economic Syndicate Alliance';
  else raise exception 'INVALID_MISSION';
 end case;
 select * into v_profile from nexora.player_profiles where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if exists(select 1 from nexora.player_missions where user_id=p_uid and mission_id=p_mission_id) then raise exception 'MISSION_ALREADY_CLAIMED';end if;
 v_progress:=case v_metric when 'trades' then coalesce((v_profile.stats->>'tradesCount')::integer,0)
  when 'produced' then coalesce((v_profile.stats->>'totalProduced')::integer,0)
  when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::integer,0)
  when 'properties' then coalesce((v_profile.stats->>'propertiesOwned')::integer,0)
  when 'org' then case when v_profile.org_id is null then 0 else 1 end else v_profile.level end;
 if v_progress<v_target then raise exception 'MISSION_NOT_COMPLETE';end if;
 insert into nexora.player_missions(user_id,mission_id,category,reward_credits,reward_xp) values(p_uid,p_mission_id,v_category,v_credits,v_xp_gain);
 update nexora.wallets set balance=balance+v_credits,total_earned=total_earned+v_credits,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
 values(v_tx,'SYSTEM',p_uid,v_credits,0,v_credits,'mission_reward',v_claim,'Mission reward: '||v_title,'completed');
 v_xp:=v_profile.xp+v_xp_gain;v_remaining:=v_xp;
 while v_level<200 loop v_step:=200+(v_level-1)*120;exit when v_remaining<v_step;v_remaining:=v_remaining-v_step;v_level:=v_level+1;end loop;
 v_gained:=greatest(0,v_level-v_profile.level);v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*.1;
 v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{missionsCompleted}',to_jsonb(coalesce((v_profile.stats->>'missionsCompleted')::integer,0)+1),true);
 update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,
  reputation=reputation+round(v_rep*v_leadership)::bigint,influence=influence+round(5*v_leadership)::bigint,stats=v_stats,updated_at=now() where user_id=p_uid;
 return jsonb_build_object('ok',true,'reward_credits',v_credits,'reward_xp',v_xp_gain);
end;$$;

create or replace function nexora.unlock_eligible_achievements(p_uid text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_profile nexora.player_profiles%rowtype;v_unlocked text[]:='{}';
begin
 select * into v_profile from nexora.player_profiles where user_id=p_uid;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 insert into nexora.player_achievements(user_id,achievement_id)
 select p_uid,a.id from (values
  ('ach_merchant','trades',5),('ach_industrial_pioneer','produced',5),('ach_tycoon','companies',2),
  ('ach_landlord','properties',2),('ach_level_5','level',5),('ach_reputation_100','reputation',100)
 ) as a(id,metric,threshold)
 where case a.metric when 'trades' then coalesce((v_profile.stats->>'tradesCount')::integer,0)
  when 'produced' then coalesce((v_profile.stats->>'totalProduced')::integer,0)
  when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::integer,0)
  when 'properties' then coalesce((v_profile.stats->>'propertiesOwned')::integer,0)
  when 'level' then v_profile.level else v_profile.reputation end>=a.threshold
 on conflict(user_id,achievement_id) do nothing;
 select coalesce(array_agg(achievement_id),'{}'::text[]) into v_unlocked from nexora.player_achievements where user_id=p_uid;
 return jsonb_build_object('unlocked_ids',v_unlocked);
end;$$;

revoke all on function nexora.claim_mission_reward(text,text) from public,anon,authenticated;
revoke all on function nexora.unlock_eligible_achievements(text) from public,anon,authenticated;
grant execute on function nexora.claim_mission_reward(text,text) to service_role;
grant execute on function nexora.unlock_eligible_achievements(text) to service_role;
