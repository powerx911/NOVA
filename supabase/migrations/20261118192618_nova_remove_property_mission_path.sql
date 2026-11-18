CREATE OR REPLACE FUNCTION nexora.claim_mission_reward(p_uid text, p_mission_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_category text;
  v_metric text;
  v_target integer;
  v_credits bigint;
  v_xp_gain integer;
  v_rep integer;
  v_title text;
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_progress integer;
  v_claim text := p_uid || '_' || p_mission_id;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_xp bigint;
  v_level integer := 1;
  v_remaining bigint;
  v_step bigint;
  v_gained integer;
  v_leadership numeric;
  v_stats jsonb;
BEGIN
  CASE p_mission_id
    WHEN 'tut_first_trade' THEN v_category:='tutorial';v_metric:='trades';v_target:=1;v_credits:=450;v_xp_gain:=90;v_rep:=10;v_title:='Enter the Open Market';
    WHEN 'tut_first_production' THEN v_category:='tutorial';v_metric:='produced';v_target:=1;v_credits:=550;v_xp_gain:=110;v_rep:=15;v_title:='Start Production Line';
    WHEN 'tut_first_company' THEN v_category:='tutorial';v_metric:='companies';v_target:=1;v_credits:=850;v_xp_gain:=160;v_rep:=25;v_title:='Found Your First Company';
    WHEN 'daily_active_trader' THEN v_category:='daily';v_metric:='trades';v_target:=3;v_credits:=600;v_xp_gain:=120;v_rep:=14;v_title:='Active Market Trader';
    WHEN 'seasonal_syndicate' THEN v_category:='seasonal';v_metric:='org';v_target:=1;v_credits:=1200;v_xp_gain:=260;v_rep:=35;v_title:='Economic Syndicate Alliance';
    ELSE RAISE EXCEPTION 'INVALID_MISSION';
  END CASE;

  SELECT * INTO v_profile FROM nexora.player_profiles WHERE user_id=p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;
  SELECT * INTO v_wallet FROM nexora.wallets WHERE user_id=p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;
  IF EXISTS(SELECT 1 FROM nexora.player_missions WHERE user_id=p_uid AND mission_id=p_mission_id) THEN
    RAISE EXCEPTION 'MISSION_ALREADY_CLAIMED';
  END IF;

  v_progress := CASE v_metric
    WHEN 'trades' THEN coalesce((v_profile.stats->>'tradesCount')::integer,0)
    WHEN 'produced' THEN coalesce((v_profile.stats->>'totalProduced')::integer,0)
    WHEN 'companies' THEN coalesce((v_profile.stats->>'companiesOwned')::integer,0)
    WHEN 'org' THEN CASE WHEN v_profile.org_id IS NULL THEN 0 ELSE 1 END
    ELSE v_profile.level
  END;
  IF v_progress < v_target THEN RAISE EXCEPTION 'MISSION_NOT_COMPLETE'; END IF;

  INSERT INTO nexora.player_missions(user_id,mission_id,category,reward_credits,reward_xp)
  VALUES(p_uid,p_mission_id,v_category,v_credits,v_xp_gain);
  UPDATE nexora.wallets
  SET balance=balance+v_credits,total_earned=total_earned+v_credits,last_tx_id=v_tx,updated_at=now()
  WHERE user_id=p_uid;
  INSERT INTO nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  VALUES(v_tx,'SYSTEM',p_uid,v_credits,0,v_credits,'mission_reward',v_claim,'Mission reward: '||v_title,'completed');

  v_xp:=v_profile.xp+v_xp_gain;
  v_remaining:=v_xp;
  WHILE v_level<200 LOOP
    v_step:=200+(v_level-1)*120;
    EXIT WHEN v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level:=v_level+1;
  END LOOP;
  v_gained:=greatest(0,v_level-v_profile.level);
  v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{missionsCompleted}',
    to_jsonb(coalesce((v_profile.stats->>'missionsCompleted')::integer,0)+1),true);
  UPDATE nexora.player_profiles
  SET xp=v_xp,level=v_level,skill_points=skill_points+v_gained,
      reputation=reputation+round(v_rep*v_leadership)::bigint,
      influence=influence+round(5*v_leadership)::bigint,stats=v_stats,updated_at=now()
  WHERE user_id=p_uid;

  RETURN jsonb_build_object('ok',true,'reward_credits',v_credits,'reward_xp',v_xp_gain);
END;
$function$;
