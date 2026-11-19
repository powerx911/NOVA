-- Per-slot server-authoritative cooldowns. A terminal contract status starts
-- an independent 15-minute cooldown for only that scope/owner/slot.
create table if not exists nexora.contract_slot_cooldowns (
  scope text not null check (scope in ('personal','organization')),
  owner_id text not null,
  slot_no integer not null check (slot_no > 0),
  board_date date not null,
  cooldown_until timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (scope, owner_id, slot_no, board_date)
);

-- The personal board has five independent offers. Organization capacity scales
-- by ten slots per level, capped at one hundred.
update nexora.contract_config
set config_value = jsonb_set(config_value, '{personal_slots}', '5'::jsonb, true),
    updated_at = now()
where config_key = 'progression';

do $do$
declare
  v_definition text;
  v_generator_definition text;
  v_old text := 'v_slots:=v_org_slots_base+floor(v_org.level/v_org_slots_divisor)::integer;';
begin
  select pg_get_functiondef('nexora.get_dynamic_contract_board(text)'::regprocedure)
    into v_definition;
  if position(v_old in v_definition) = 0 then
    raise exception 'CONTRACT_BOARD_SLOT_FORMULA_NOT_FOUND';
  end if;
  v_definition := replace(v_definition, v_old,
    'v_slots:=least(100,greatest(10,v_org.level*10));');
  v_definition := replace(v_definition,
    $old$'organization',coalesce(v_org_board,'[]'::jsonb),'active_personal',v_active,$old$,
    $new$'organization',coalesce(v_org_board,'[]'::jsonb),'organization_slots',coalesce(v_slots,0),'organization_max_slots',100,'active_personal',v_active,$new$);
  if position('organization_max_slots' in v_definition)=0 then
    raise exception 'CONTRACT_BOARD_ORG_SLOT_METADATA_PATCH_FAILED';
  end if;
  execute v_definition;

  select pg_get_functiondef('nexora.generate_dynamic_contract(text,text,text,integer,date,text,text,text)'::regprocedure)
    into v_generator_definition;
  v_generator_definition:=replace(v_generator_definition,
    'if v_item is null then raise exception ''CONTRACT_CATALOG_EMPTY''; end if;',
    'if v_item is null then return null; end if;');
  -- Reuse catalog items across different organization slots so level 10 can
  -- actually fill a 100-slot board even when the catalog has fewer than 100 items.
  v_generator_definition:=replace(v_generator_definition,
    'and o.item_id=item_id and o.tier=v_tier',
    'and o.item_id=item_id and o.tier=v_tier and o.slot_no=p_slot');
  v_generator_definition:=replace(v_generator_definition,
    'and o.item_id=c.item_id and o.tier=c.item_cfg->>''tier''',
    'and o.item_id=c.item_id and o.tier=c.item_cfg->>''tier'' and o.slot_no=p_slot');
  if position('and o.item_id=item_id and o.tier=v_tier and o.slot_no=p_slot' in v_generator_definition)=0
    or position('and o.item_id=c.item_id and o.tier=c.item_cfg->>''tier'' and o.slot_no=p_slot' in v_generator_definition)=0 then
    raise exception 'CONTRACT_BOARD_SLOT_REUSE_PATCH_FAILED';
  end if;
  if position('if v_item is null then return null; end if;' in v_generator_definition)=0 then
    raise exception 'CONTRACT_CATALOG_EMPTY_GUARD_PATCH_FAILED';
  end if;
  execute v_generator_definition;
end;
$do$;

alter table nexora.contract_slot_cooldowns enable row level security;
revoke all on table nexora.contract_slot_cooldowns from public,anon,authenticated;

create table if not exists nexora.contract_slot_refresh_usage (
  scope text not null check (scope in ('personal','organization')),
  owner_id text not null,
  date_key date not null,
  used_count integer not null default 0 check (used_count >= 0),
  updated_at timestamptz not null default now(),
  primary key(scope,owner_id,date_key)
);

create index if not exists contract_slot_cooldowns_until_idx
  on nexora.contract_slot_cooldowns (cooldown_until);

create or replace function nexora.start_contract_slot_cooldown()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_id text;
begin
  if old.status is distinct from new.status
    and new.status in ('completed','abandoned','expired')
    and new.slot_no > 0
  then
    v_owner_id := case when new.scope = 'personal' then new.user_id else new.org_id end;
    if v_owner_id is not null then
      insert into nexora.contract_slot_cooldowns
        (scope, owner_id, slot_no, board_date, cooldown_until, updated_at)
      values
        (new.scope, v_owner_id, new.slot_no, new.board_date, now() + interval '15 minutes', now())
      on conflict (scope, owner_id, slot_no, board_date)
      do update set cooldown_until = greatest(
        nexora.contract_slot_cooldowns.cooldown_until,
        excluded.cooldown_until
      ), updated_at = now();
    end if;
    -- A personal offer is generated immediately after acceptance. When the
    -- accepted contract later ends, expire any still-offered replacement in
    -- the same slot so the full cooldown is visible and enforceable.
    if pg_trigger_depth()=1 then
      update nexora.contract_offers
      set status='expired',updated_at=now()
      where scope=new.scope and slot_no=new.slot_no and board_date=new.board_date
        and id<>new.id and status='offered'
        and ((new.scope='personal' and user_id=v_owner_id)
          or (new.scope='organization' and org_id=v_owner_id));
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists nova_contract_slot_cooldown on nexora.contract_offers;
create trigger nova_contract_slot_cooldown
after update of status on nexora.contract_offers
for each row execute function nexora.start_contract_slot_cooldown();

-- Suppress immediate replacement attempts made by existing lifecycle RPCs.
-- Expired cooldown rows are cleared lazily on the next board refresh, allowing
-- the normal generator to fill that exact slot without affecting other slots.
create or replace function nexora.guard_contract_slot_cooldown_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_id text;
  v_until timestamptz;
begin
  v_owner_id := case when new.scope = 'personal' then new.user_id else new.org_id end;
  if v_owner_id is null then return new; end if;

  select c.cooldown_until into v_until
  from nexora.contract_slot_cooldowns c
  where c.scope = new.scope and c.owner_id = v_owner_id
    and c.slot_no = new.slot_no and c.cooldown_until > now()
  order by c.cooldown_until desc limit 1
  for update;

  if v_until is not null and v_until > now() then
    return null;
  end if;

  if v_until is not null then
    delete from nexora.contract_slot_cooldowns c
    where c.scope = new.scope and c.owner_id = v_owner_id
      and c.slot_no = new.slot_no and c.cooldown_until <= now();
  end if;
  return new;
end;
$$;

drop trigger if exists nova_contract_slot_cooldown_guard on nexora.contract_offers;
create trigger nova_contract_slot_cooldown_guard
before insert on nexora.contract_offers
for each row execute function nexora.guard_contract_slot_cooldown_insert();

create or replace function nexora.get_contract_slot_cooldowns(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id text;
  v_can_refresh_org boolean := false;
  v_personal_refresh_used integer := 0;
  v_org_refresh_used integer := 0;
begin
  select org_id into v_org_id
  from nexora.player_profiles where user_id = p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select exists(select 1 from nexora.organization_members where org_id=v_org_id and user_id=p_uid and role in ('leader','deputy')) into v_can_refresh_org;
  select coalesce(used_count,0) into v_personal_refresh_used from nexora.contract_slot_refresh_usage
    where scope='personal' and owner_id=p_uid and date_key=(now() at time zone 'UTC')::date;
  select coalesce(used_count,0) into v_org_refresh_used from nexora.contract_slot_refresh_usage
    where scope='organization' and owner_id=v_org_id and date_key=(now() at time zone 'UTC')::date;

  return jsonb_build_object(
    'server_now', now(),
    'can_refresh_org', v_can_refresh_org,
    'personal_refresh_used', v_personal_refresh_used,
    'personal_refresh_limit', 3,
    'org_refresh_used', v_org_refresh_used,
    'org_refresh_limit', 5,
    'personal', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no', c.slot_no, 'board_date', c.board_date,
        'cooldown_until', c.cooldown_until
      ) order by c.slot_no)
      from (
        select slot_no,max(board_date) as board_date,max(cooldown_until) as cooldown_until
        from nexora.contract_slot_cooldowns
        where scope='personal' and owner_id=p_uid and cooldown_until>now()
        group by slot_no
      ) c
    ), '[]'::jsonb),
    'organization', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no', c.slot_no, 'board_date', c.board_date,
        'cooldown_until', c.cooldown_until
      ) order by c.slot_no)
      from (
        select slot_no,max(board_date) as board_date,max(cooldown_until) as cooldown_until
        from nexora.contract_slot_cooldowns
        where scope='organization' and owner_id=v_org_id and cooldown_until>now()
        group by slot_no
      ) c
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function nexora.start_contract_slot_cooldown() from public, anon, authenticated;
revoke all on function nexora.guard_contract_slot_cooldown_insert() from public, anon, authenticated;
revoke all on function nexora.get_contract_slot_cooldowns(text) from public, anon, authenticated;
grant execute on function nexora.get_contract_slot_cooldowns(text) to service_role;
