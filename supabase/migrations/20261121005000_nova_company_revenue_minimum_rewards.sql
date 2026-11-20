-- Restore the minimum company-revenue collection rewards that were lost
-- during the production parity replacement. Keep the leadership multiplier,
-- level-up skill points, and the existing 80-XP per-collection cap.
do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)
    into v_definition;

  if v_definition is null then
    raise exception 'COLLECT_COMPANY_REVENUE_FUNCTION_MISSING';
  end if;

  if position(
    'v_xp_gain:=floor((v_company.total_revenue+v_payout)::numeric/15)::bigint-floor(v_company.total_revenue::numeric/15)::bigint;'
    in v_definition
  ) > 0 then
    v_definition := replace(
      v_definition,
      'v_xp_gain:=floor((v_company.total_revenue+v_payout)::numeric/15)::bigint-floor(v_company.total_revenue::numeric/15)::bigint;',
      'v_xp_gain:=least(80,greatest(10,floor(v_payout/15)::integer));'
    );

    if position('v_gained integer;' in v_definition) = 0 then
      v_definition := replace(v_definition, 'v_step bigint;', 'v_step bigint; v_gained integer; v_leadership numeric;');
    end if;

    v_definition := replace(
      v_definition,
      'update nexora.player_profiles set xp=v_xp,level=v_level_after,updated_at=now() where user_id=p_uid;',
      'v_gained:=greatest(0,v_level_after-v_profile.level); v_leadership:=1+coalesce((v_profile.skills->>''leadership'')::numeric,0)*0.1; update nexora.player_profiles set xp=v_xp,level=v_level_after,skill_points=skill_points+v_gained*2,reputation=reputation+round(2*v_leadership)::bigint,influence=influence+round(1*v_leadership)::bigint,updated_at=now() where user_id=p_uid;'
    );

    if position('least(80,greatest(10,floor(v_payout/15)::integer))' in v_definition) = 0
      or position('reputation=reputation+round(2*v_leadership)::bigint' in v_definition) = 0
      or position('influence=influence+round(1*v_leadership)::bigint' in v_definition) = 0
      or position('skill_points=skill_points+v_gained*2' in v_definition) = 0 then
      raise exception 'COMPANY_REVENUE_REWARD_PATCH_INCOMPLETE';
    end if;

    execute v_definition;
  elsif position('least(80,greatest(10,floor(v_payout/15)::integer))' in v_definition) > 0
    and position('reputation=reputation+round(2*v_leadership)::bigint' in v_definition) > 0
    and position('influence=influence+round(1*v_leadership)::bigint' in v_definition) > 0
    and position('skill_points=skill_points+v_gained*2' in v_definition) > 0 then
    raise notice 'Company revenue minimum rewards are already present';
  else
    raise exception 'UNEXPECTED_COLLECT_COMPANY_REVENUE_DEFINITION';
  end if;
end
$patch$;
