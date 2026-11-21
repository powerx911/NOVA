-- Remove per-request XP/reputation/influence farming from company revenue collection.
-- XP is awarded only for each $15 actually collected, capped at 80 per collection.
do $patch$
declare
  v_definition text;
  v_old_xp text := $old$v_xp_gain:=least(80,greatest(10,floor(v_payout/15)::integer));$old$;
  v_new_xp text := $new$v_xp_gain:=least(80,floor(v_payout/15)::integer);$new$;
  v_old_rewards text := $old$v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1; update nexora.player_profiles set xp=v_xp,level=v_level_after,reputation=reputation+round(2*v_leadership)::bigint,influence=influence+round(1*v_leadership)::bigint,updated_at=now() where user_id=p_uid;$old$;
  v_new_rewards text := $new$update nexora.player_profiles set xp=v_xp,level=v_level_after,updated_at=now() where user_id=p_uid;$new$;
begin
  select pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)
    into v_definition;

  if position(v_new_xp in v_definition) = 0 then
    if position(v_old_xp in v_definition) = 0 then
      raise exception 'COMPANY_REVENUE_XP_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_old_xp, v_new_xp);
  end if;

  if position(v_new_rewards in v_definition) = 0 then
    if position(v_old_rewards in v_definition) = 0 then
      raise exception 'COMPANY_REVENUE_REWARD_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_old_rewards, v_new_rewards);
  end if;

  v_definition := replace(v_definition, 'v_step bigint; v_leadership numeric;', 'v_step bigint;');

  if position('v_leadership' in v_definition) > 0
     or position('reputation=reputation+' in v_definition) > 0
     or position('influence=influence+' in v_definition) > 0 then
    raise exception 'COMPANY_REVENUE_REWARD_PATCH_VALIDATION_FAILED';
  end if;

  execute v_definition;
end
$patch$;
