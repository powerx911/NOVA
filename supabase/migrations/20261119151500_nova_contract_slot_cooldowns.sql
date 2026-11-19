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
    and new.board_date = (now() at time zone 'UTC')::date
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
    and c.slot_no = new.slot_no and c.board_date = new.board_date
  for update;

  if v_until is not null and v_until > now() then
    return null;
  end if;

  if v_until is not null then
    delete from nexora.contract_slot_cooldowns c
    where c.scope = new.scope and c.owner_id = v_owner_id
      and c.slot_no = new.slot_no and c.board_date = new.board_date
      and c.cooldown_until <= now();
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
begin
  select org_id into v_org_id
  from nexora.player_profiles where user_id = p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  return jsonb_build_object(
    'server_now', now(),
    'personal', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no', c.slot_no, 'board_date', c.board_date,
        'cooldown_until', c.cooldown_until
      ) order by c.slot_no)
      from nexora.contract_slot_cooldowns c
      where c.scope='personal' and c.owner_id=p_uid
        and c.board_date=(now() at time zone 'UTC')::date
        and c.cooldown_until>now()
    ), '[]'::jsonb),
    'organization', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no', c.slot_no, 'board_date', c.board_date,
        'cooldown_until', c.cooldown_until
      ) order by c.slot_no)
      from nexora.contract_slot_cooldowns c
      where c.scope='organization' and c.owner_id=v_org_id
        and c.board_date=(now() at time zone 'UTC')::date
        and c.cooldown_until>now()
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function nexora.start_contract_slot_cooldown() from public, anon, authenticated;
revoke all on function nexora.guard_contract_slot_cooldown_insert() from public, anon, authenticated;
revoke all on function nexora.get_contract_slot_cooldowns(text) from public, anon, authenticated;
grant execute on function nexora.get_contract_slot_cooldowns(text) to service_role;
