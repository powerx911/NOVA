-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118171625
-- Remote migration name: nexora_character_creation_rpc
-- Source: Supabase postgres_logs at 2026-11-18 17:16:25 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.create_player_character(
  p_uid text,
  p_email text,
  p_username text,
  p_avatar_id text,
  p_language text default 'ar'
) returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_username text := btrim(p_username);
  v_lower text;
  v_title text;
  v_notification_id text := 'ntf_' || gen_random_uuid()::text;
begin
  if p_uid is null or length(p_uid) < 1 or length(p_uid) > 128 then
    raise exception 'INVALID_USER';
  end if;
  if v_username !~ '^[a-zA-Z0-9_]{3,24}$' then
    raise exception 'INVALID_USERNAME';
  end if;
  if p_language not in ('ar','en') then
    raise exception 'INVALID_LANGUAGE';
  end if;

  v_lower := lower(v_username);
  v_title := case when p_language = 'ar' then 'مؤسس طموح' else 'Executive Founder' end;

  if exists (select 1 from nexora.player_profiles where user_id = p_uid) then
    raise exception 'PROFILE_EXISTS';
  end if;

  insert into nexora.usernames(username_lower,uid,username)
  values (v_lower,p_uid,v_username);

  insert into nexora.player_profiles(
    user_id,username,username_lower,avatar_id,title,level,xp,reputation,influence,
    skill_points,skills,stats,org_id
  ) values (
    p_uid,v_username,v_lower,p_avatar_id,v_title,1,0,10,5,3,
    '{"trade":0,"management":0,"industry":0,"negotiation":0,"finance":0,"leadership":0}'::jsonb,
    '{"missionsCompleted":0,"tradesCount":0,"companiesOwned":0,"propertiesOwned":0,"totalProduced":0}'::jsonb,
    null
  );

  insert into nexora.player_private(user_id,email,language,notifications_enabled)
  values (p_uid,coalesce(p_email,''),p_language,true);

  insert into nexora.wallets(user_id,balance,total_earned,total_spent,last_tx_id)
  values (p_uid,2500,2500,0,'init_' || p_uid);

  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  values (
    v_notification_id,
    p_uid,
    case when p_language='ar' then 'مرحباً بك في NEXORA' else 'Welcome to NEXORA' end,
    case when p_language='ar' then 'تم إيداع $2,500 في محفظتك وتخصيص 3 نقاط مهارة.' else '$2,500 and 3 skill points credited to your account.' end,
    'system',
    false
  );

  return jsonb_build_object('ok',true,'user_id',p_uid,'username',v_username,'starting_credits',2500);
exception
  when unique_violation then
    raise exception 'USERNAME_TAKEN';
end;
$$;

revoke all on function nexora.create_player_character(text,text,text,text,text) from public, anon, authenticated;
grant execute on function nexora.create_player_character(text,text,text,text,text) to service_role;
;
