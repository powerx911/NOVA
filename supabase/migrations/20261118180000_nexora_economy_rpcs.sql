create or replace function nexora.claim_daily_stipend(p_uid text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_date text := to_char(now() at time zone 'UTC','YYYY-MM-DD');
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_amount bigint;
  v_xp bigint;
  v_level integer := 1;
  v_remaining bigint;
  v_step bigint;
  v_levels_gained integer;
  v_leadership numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_notification text := 'ntf_' || gen_random_uuid()::text;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_amount := least(1500, greatest(450, 450 + (v_profile.level - 1) * 35 + coalesce((v_profile.skills->>'finance')::integer,0) * 25));
  if exists(select 1 from nexora.daily_claims where user_id=p_uid and date_key=v_date) then raise exception 'ALREADY_CLAIMED_TODAY'; end if;
  insert into nexora.daily_claims(user_id,date_key,amount) values(p_uid,v_date,v_amount);
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_amount,0,v_amount,'daily_stipend',p_uid || '_' || v_date,'Daily operational stipend (' || v_date || ')','completed');
  update nexora.wallets set balance=balance+v_amount,total_earned=total_earned+v_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  v_xp := v_profile.xp + 40;
  v_remaining := v_xp;
  while v_level < 200 loop
    v_step := 200 + (v_level - 1) * 120;
    exit when v_remaining < v_step;
    v_remaining := v_remaining - v_step;
    v_level := v_level + 1;
  end loop;
  v_levels_gained := greatest(0,v_level-v_profile.level);
  v_leadership := 1 + coalesce((v_profile.skills->>'leadership')::numeric,0) * 0.1;
  update nexora.player_profiles
  set xp=v_xp,level=v_level,skill_points=skill_points + v_levels_gained * 2,
      reputation=reputation + round(2 * v_leadership)::bigint,
      influence=influence + round(1 * v_leadership)::bigint,updated_at=now()
  where user_id=p_uid;
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  values(v_notification,p_uid,'Daily Stipend Credited','+$' || v_amount::text || ' & +40 XP','economy',false);
  return jsonb_build_object('ok',true,'amount',v_amount,'xp_gain',40,'date_key',v_date);
end;
$$;

create or replace function nexora.upgrade_player_skill(p_uid text,p_skill text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_current integer;
begin
  if p_skill not in ('trade','management','industry','negotiation','finance','leadership') then raise exception 'INVALID_SKILL'; end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_profile.skill_points < 1 then raise exception 'NO_SKILL_POINTS'; end if;
  v_current := coalesce((v_profile.skills->>p_skill)::integer,0);
  if v_current >= 10 then raise exception 'SKILL_MAXED'; end if;
  update nexora.player_profiles set skill_points=skill_points-1,
    skills=jsonb_set(coalesce(skills,'{}'::jsonb),array[p_skill],to_jsonb(v_current+1),true),updated_at=now()
  where user_id=p_uid;
  return jsonb_build_object('ok',true,'skill',p_skill,'level',v_current+1);
end;
$$;

create or replace function nexora.transfer_credits(p_uid text,p_recipient_username text,p_amount bigint,p_note text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_to_uid text;
  v_from nexora.wallets%rowtype;
  v_to nexora.wallets%rowtype;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_notification text := 'ntf_' || gen_random_uuid()::text;
  v_note text := left(coalesce(btrim(p_note),''),180);
  v_recipient_name text;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  select uid,username into v_to_uid,v_recipient_name from nexora.usernames where username_lower=lower(btrim(p_recipient_username));
  if v_to_uid is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
  if v_to_uid=p_uid then raise exception 'SELF_OR_MISSING_RECIPIENT'; end if;
  perform 1 from nexora.wallets where user_id in (p_uid,v_to_uid) order by user_id for update;
  select * into v_from from nexora.wallets where user_id=p_uid;
  select * into v_to from nexora.wallets where user_id=v_to_uid;
  if v_from.user_id is null or v_to.user_id is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
  if p_amount > v_from.balance then raise exception 'INSUFFICIENT_FUNDS'; end if;
  update nexora.wallets set balance=balance-p_amount,total_spent=total_spent+p_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  update nexora.wallets set balance=balance+p_amount,total_earned=total_earned+p_amount,last_tx_id=v_tx,updated_at=now() where user_id=v_to_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,v_to_uid,p_amount,0,p_amount,'transfer',v_to_uid,coalesce(nullif(v_note,''),'Transfer to ' || v_recipient_name),'completed');
  insert into nexora.audit_logs(id,user_id,action,entity_type,entity_id,details)
  values('aud_' || gen_random_uuid()::text,p_uid,'wallet_transfer','transaction',v_tx,jsonb_build_object('recipient_uid',v_to_uid,'amount',p_amount));
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  values(v_notification,p_uid,'Transfer Sent','-$' || p_amount::text || ' -> ' || v_recipient_name,'economy',false);
  return jsonb_build_object('ok',true,'transaction_id',v_tx,'amount',p_amount);
end;
$$;

revoke all on function nexora.claim_daily_stipend(text) from public,anon,authenticated;
revoke all on function nexora.upgrade_player_skill(text,text) from public,anon,authenticated;
revoke all on function nexora.transfer_credits(text,text,bigint,text) from public,anon,authenticated;
grant execute on function nexora.claim_daily_stipend(text) to service_role;
grant execute on function nexora.upgrade_player_skill(text,text) to service_role;
grant execute on function nexora.transfer_credits(text,text,bigint,text) to service_role;
