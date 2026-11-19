alter table nexora.contract_daily_limits
  add column if not exists personal_used_count integer not null default 0,
  add column if not exists org_used_count integer not null default 0;

-- Preserve existing anti-abuse usage for both buckets on the migration day.
update nexora.contract_daily_limits
set personal_used_count=greatest(personal_used_count,used_count),
    org_used_count=greatest(org_used_count,used_count)
where date_key=(now() at time zone 'UTC')::date;

do $$
declare v_def text;
begin
  select pg_get_functiondef('nexora.accept_dynamic_contract(text,text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    $old$select used_count into v_used from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today for update;$old$,
    $new$select case when v_contract.scope='personal' then personal_used_count else org_used_count end
    into v_used from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today for update;$new$);
  v_def:=replace(v_def,
    $old$update nexora.contract_daily_limits set used_count=used_count+1,updated_at=v_now
    where user_id=p_uid and date_key=v_today;$old$,
    $new$update nexora.contract_daily_limits
    set used_count=used_count+1,
      personal_used_count=personal_used_count+case when v_contract.scope='personal' then 1 else 0 end,
      org_used_count=org_used_count+case when v_contract.scope='organization' then 1 else 0 end,
      updated_at=v_now
    where user_id=p_uid and date_key=v_today;$new$);
  if position('personal_used_count' in v_def)=0 or position('org_used_count=org_used_count+' in v_def)=0 then
    raise exception 'CONTRACT_DAILY_SCOPE_PATCH_FAILED';
  end if;
  execute v_def;
end;
$$;

do $$
declare v_def text;
begin
  select pg_get_functiondef('nexora.get_dynamic_contract_board(text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    $old$v_claims integer;$old$,
    $new$v_claims integer;
  v_org_claims integer;$new$);
  v_def:=replace(v_def,
    $old$select coalesce(used_count,0) into v_claims from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today;$old$,
    $new$select coalesce(personal_used_count,0),coalesce(org_used_count,0)
    into v_claims,v_org_claims from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today;$new$);
  v_def:=replace(v_def,
    $old$'daily_used',coalesce(v_claims,0),'daily_limit',v_daily_limit,'offer_expires_at',v_end);$old$,
    $new$'daily_used',coalesce(v_claims,0),'daily_limit',5,
    'org_daily_used',coalesce(v_org_claims,0),'org_daily_limit',5,'offer_expires_at',v_end);$new$);
  if position('org_daily_used' in v_def)=0 then
    raise exception 'CONTRACT_BOARD_DAILY_SCOPE_PATCH_FAILED';
  end if;
  execute v_def;
end;
$$;
