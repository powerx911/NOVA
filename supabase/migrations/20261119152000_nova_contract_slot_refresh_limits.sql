create table if not exists nexora.contract_slot_refresh_usage (
  scope text not null check (scope in ('personal','organization')),
  owner_id text not null,
  date_key date not null,
  used_count integer not null default 0 check (used_count >= 0),
  updated_at timestamptz not null default now(),
  primary key(scope,owner_id,date_key)
);

create or replace function nexora.refresh_dynamic_contract(p_uid text,p_contract_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_owner text;
  v_today date := (now() at time zone 'UTC')::date;
  v_limit integer;
  v_used integer;
  v_until timestamptz := now() + interval '15 minutes';
begin
  select * into v_profile from nexora.player_profiles
  where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select * into v_contract from nexora.contract_offers
  where id=p_contract_id for update;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  if v_contract.status <> 'offered' then raise exception 'CONTRACT_NOT_REFRESHABLE'; end if;
  if v_contract.board_date <> v_today then raise exception 'CONTRACT_NOT_REFRESHABLE'; end if;

  if v_contract.scope='personal' then
    if v_contract.user_id is distinct from p_uid then raise exception 'UNAUTHORIZED'; end if;
    v_owner := p_uid;
    v_limit := 3;
  else
    if v_profile.org_id is distinct from v_contract.org_id then raise exception 'UNAUTHORIZED'; end if;
    if not exists (
      select 1 from nexora.organization_members
      where org_id=v_contract.org_id and user_id=p_uid and role in ('leader','deputy')
    ) then raise exception 'ORG_REFRESH_PERMISSION_REQUIRED'; end if;
    v_owner := v_contract.org_id;
    v_limit := 5;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    'contract-refresh:'||v_contract.scope||':'||v_owner||':'||v_today::text,0
  ));
  insert into nexora.contract_slot_refresh_usage(scope,owner_id,date_key,used_count)
  values(v_contract.scope,v_owner,v_today,0)
  on conflict(scope,owner_id,date_key) do nothing;

  select used_count into v_used
  from nexora.contract_slot_refresh_usage
  where scope=v_contract.scope and owner_id=v_owner and date_key=v_today
  for update;
  if v_used >= v_limit then raise exception 'CONTRACT_REFRESH_LIMIT_REACHED'; end if;

  update nexora.contract_slot_refresh_usage
  set used_count=used_count+1,updated_at=now()
  where scope=v_contract.scope and owner_id=v_owner and date_key=v_today;

  update nexora.contract_offers
  set status='abandoned',completed_at=now(),updated_at=now()
  where id=p_contract_id;

  return jsonb_build_object(
    'ok',true,'scope',v_contract.scope,'slot_no',v_contract.slot_no,
    'cooldown_until',v_until,'refreshes_used',v_used+1,'refreshes_limit',v_limit
  );
end;
$$;

revoke all on function nexora.refresh_dynamic_contract(text,text) from public,anon,authenticated;
grant execute on function nexora.refresh_dynamic_contract(text,text) to service_role;
