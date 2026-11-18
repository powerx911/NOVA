-- Asynchronous player-vs-player challenges. All outcomes and rewards are server-calculated.
alter table public.nova_competitive_commands
  drop constraint if exists nova_competitive_commands_command_type_check;
alter table public.nova_competitive_commands
  add constraint nova_competitive_commands_command_type_check
  check (command_type in ('operation','asset_upgrade','market_list','market_buy','market_cancel','challenge_create','challenge_accept','challenge_decline'));

alter table public.nova_competitive_activities
  drop constraint if exists nova_competitive_activities_activity_type_check;
alter table public.nova_competitive_activities
  add constraint nova_competitive_activities_activity_type_check
  check (activity_type in ('joined','operation','asset_upgrade','market_listing','market_sale','challenge_invite','challenge_result','challenge_decline'));


alter table public.nova_competitive_wallets
  add column if not exists energy_updated_at timestamptz not null default now();

create or replace function private.nova_track_energy_spend()
returns trigger language plpgsql set search_path = pg_catalog, public
as $
begin
  if new.energy < old.energy then new.energy_updated_at := clock_timestamp(); end if;
  return new;
end;
$;
revoke all on function private.nova_track_energy_spend() from public, anon, authenticated;
drop trigger if exists nova_track_energy_spend on public.nova_competitive_wallets;
create trigger nova_track_energy_spend before update of energy on public.nova_competitive_wallets
for each row execute function private.nova_track_energy_spend();

create or replace function private.nova_regenerate_energy(p_user_id uuid)
returns public.nova_competitive_wallets
language plpgsql security definer
set search_path = pg_catalog, public
as $
declare
  v_wallet public.nova_competitive_wallets%rowtype;
  v_ticks integer;
  v_added integer;
begin
  select * into v_wallet from public.nova_competitive_wallets where user_id=p_user_id for update;
  if not found or v_wallet.energy >= 100 then return v_wallet; end if;
  v_ticks:=floor(extract(epoch from (clock_timestamp()-v_wallet.energy_updated_at))/300)::integer;
  if v_ticks <= 0 then return v_wallet; end if;
  v_added:=least(100-v_wallet.energy,v_ticks);
  update public.nova_competitive_wallets
    set energy=energy+v_added,
        energy_updated_at=case when energy+v_added >= 100 then clock_timestamp() else energy_updated_at+(v_added*interval '5 minutes') end,
        updated_at=now()
    where user_id=p_user_id returning * into v_wallet;
  return v_wallet;
end;
$;
revoke all on function private.nova_regenerate_energy(uuid) from public, anon, authenticated;

create or replace function private.nova_competitive_refresh_energy()
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $
declare v_user_id uuid:=auth.uid(); v_wallet public.nova_competitive_wallets%rowtype;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode='28000'; end if;
  v_wallet:=private.nova_regenerate_energy(v_user_id);
  return jsonb_build_object('wallet',to_jsonb(v_wallet));
end;
$;
revoke all on function private.nova_competitive_refresh_energy() from public, anon, authenticated;
grant execute on function private.nova_competitive_refresh_energy() to authenticated;

create or replace function public.nova_competitive_refresh_energy()
returns jsonb language sql security invoker
set search_path = pg_catalog, public, private
as $ select private.nova_competitive_refresh_energy(); $;
revoke all on function public.nova_competitive_refresh_energy() from public, anon;
grant execute on function public.nova_competitive_refresh_energy() to authenticated;
\ncreate table if not exists public.nova_competitive_battles (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references auth.users(id) on delete cascade,
  defender_id uuid not null references auth.users(id) on delete cascade,
  challenger_name text not null,
  defender_name text not null,
  challenger_power bigint not null check (challenger_power >= 0),
  defender_power bigint not null check (defender_power >= 0),
  status text not null default 'pending' check (status in ('pending','resolved','declined','expired')),
  challenger_score bigint,
  defender_score bigint,
  winner_id uuid references auth.users(id) on delete set null,
  winner_name text,
  result_text text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (challenger_id <> defender_id)
);
create index if not exists nova_competitive_battles_challenger_idx
  on public.nova_competitive_battles (challenger_id, created_at desc);
create index if not exists nova_competitive_battles_defender_idx
  on public.nova_competitive_battles (defender_id, created_at desc);
create index if not exists nova_competitive_battles_winner_idx
  on public.nova_competitive_battles (winner_id);
create unique index if not exists nova_competitive_battles_pending_pair_idx
  on public.nova_competitive_battles (challenger_id, defender_id)
  where status = 'pending';

alter table public.nova_competitive_battles enable row level security;
create policy "Players read battles they participate in"
  on public.nova_competitive_battles for select to authenticated
  using ((select auth.uid()) = challenger_id or (select auth.uid()) = defender_id);
revoke all on public.nova_competitive_battles from public, anon, authenticated;
grant select on public.nova_competitive_battles to authenticated;

create or replace function private.nova_competitive_simulate(p_command_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_wallet public.nova_competitive_wallets%rowtype;
  v_reward bigint;
  v_result jsonb;
  v_name text;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_command_id is null then raise exception 'Command id is required' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text, 0));
  select result into v_existing from public.nova_competitive_commands where user_id=v_user_id and command_id=p_command_id;
  if found then return v_existing || jsonb_build_object('replayed',true); end if;
  perform private.nova_regenerate_energy(v_user_id);
  select * into v_wallet from public.nova_competitive_wallets where user_id=v_user_id for update;
  if not found then raise exception 'Player is not initialized' using errcode = 'P0002'; end if;
  if v_wallet.energy < 10 then raise exception 'Insufficient energy' using errcode = '22023'; end if;
  v_reward:=250+floor(v_wallet.power::numeric/25)::bigint;
  update public.nova_competitive_wallets set energy=energy-10,credits=credits+v_reward,influence=influence+10,net_worth=net_worth+v_reward,updated_at=now()
    where user_id=v_user_id returning * into v_wallet;
  insert into public.nova_competitive_ledger(user_id,command_id,resource,delta,balance_after)
  values (v_user_id,p_command_id,'energy',-10,v_wallet.energy),(v_user_id,p_command_id,'credits',v_reward,v_wallet.credits),(v_user_id,p_command_id,'influence',10,v_wallet.influence);
  select display_name into v_name from public.nova_competitive_profiles where user_id=v_user_id;
  insert into public.nova_competitive_activities(actor_name,activity_type,headline)
  values (v_name,'operation',v_name || ' أكمل عملية وحقق ' || v_reward::text || ' رصيد');
  v_result:=jsonb_build_object('success',true,'reward',v_reward,'wallet',to_jsonb(v_wallet));
  insert into public.nova_competitive_commands(user_id,command_id,command_type,result)
  values (v_user_id,p_command_id,'operation',v_result);
  return v_result;
end;
$;
revoke all on function private.nova_competitive_simulate(uuid) from public, anon, authenticated;
grant execute on function private.nova_competitive_simulate(uuid) to authenticated;
\ncreate or replace function private.nova_challenge_player(p_command_id uuid, p_target_name text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_target_id uuid;
  v_target_name text;
  v_challenger_name text;
  v_power bigint;
  v_energy integer;
  v_pending integer;
  v_existing jsonb;
  v_battle public.nova_competitive_battles%rowtype;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_command_id is null or char_length(trim(coalesce(p_target_name,''))) not between 3 and 24 then
    raise exception 'Invalid challenge target' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text, 0));
  select result into v_existing from public.nova_competitive_commands where user_id=v_user_id and command_id=p_command_id;
  if found then return v_existing || jsonb_build_object('replayed',true); end if;

  select user_id, display_name into v_target_id, v_target_name
    from public.nova_competitive_profiles where lower(display_name)=lower(trim(p_target_name));
  if not found then raise exception 'Player not found' using errcode = 'P0002'; end if;
  if v_target_id = v_user_id then raise exception 'You cannot challenge yourself' using errcode = '22023'; end if;
  update public.nova_competitive_battles set status='expired',resolved_at=now()
    where challenger_id=v_user_id and status='pending' and created_at < now()-interval '24 hours';
  if exists(select 1 from public.nova_competitive_battles
      where challenger_id=v_user_id and defender_id=v_target_id and status='pending') then
    raise exception 'Challenge already pending' using errcode = '23505';
  end if;
  select p.display_name into v_challenger_name from public.nova_competitive_profiles p where p.user_id=v_user_id;
  perform private.nova_regenerate_energy(v_user_id);\n  select power, energy into v_power, v_energy from public.nova_competitive_wallets where user_id=v_user_id for update;
  if not found then raise exception 'Player wallet is missing' using errcode = 'P0002'; end if;
  select count(*) into v_pending from public.nova_competitive_battles
    where challenger_id=v_user_id and status='pending';
  if v_pending >= 3 then raise exception 'You already have three pending challenges' using errcode = '22023'; end if;
  if v_energy < 15 then raise exception 'Insufficient energy' using errcode = '22023'; end if;
  update public.nova_competitive_wallets set energy=energy-15, updated_at=now()
    where user_id=v_user_id returning energy into v_energy;
  insert into public.nova_competitive_battles
    (challenger_id,defender_id,challenger_name,defender_name,challenger_power,defender_power)
  values (v_user_id,v_target_id,v_challenger_name,v_target_name,v_power,
    coalesce((select power from public.nova_competitive_wallets where user_id=v_target_id),0))
  returning * into v_battle;

  insert into public.nova_competitive_ledger(user_id,command_id,resource,delta,balance_after)
  values (v_user_id,p_command_id,'energy',-15,v_energy);
  insert into public.nova_competitive_activities(actor_name,activity_type,headline)
  values (v_challenger_name,'challenge_invite',v_challenger_name || ' تحدّى ' || v_target_name || ' في الساحة');

  v_result:=jsonb_build_object('success',true,'battle',to_jsonb(v_battle),'energy',v_energy);
  insert into public.nova_competitive_commands(user_id,command_id,command_type,result)
  values (v_user_id,p_command_id,'challenge_create',v_result);
  return v_result;
end;
$$;

create or replace function private.nova_accept_challenge(p_command_id uuid,p_battle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_battle public.nova_competitive_battles%rowtype;
  v_challenger_wallet public.nova_competitive_wallets%rowtype;
  v_defender_wallet public.nova_competitive_wallets%rowtype;
  v_actor_wallet public.nova_competitive_wallets%rowtype;
  v_challenger_score bigint;
  v_defender_score bigint;
  v_winner_id uuid;
  v_loser_id uuid;
  v_winner_name text;
  v_reward bigint;
  v_loser_influence_delta bigint;
  v_result_text text;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_command_id is null or p_battle_id is null then raise exception 'Challenge id is required' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text,0));
  select result into v_existing from public.nova_competitive_commands where user_id=v_user_id and command_id=p_command_id;
  if found then return v_existing || jsonb_build_object('replayed',true); end if;

  select * into v_battle from public.nova_competitive_battles where id=p_battle_id for update;
  if not found or v_battle.status <> 'pending' then raise exception 'Challenge is no longer pending' using errcode = 'P0002'; end if;
  if v_battle.defender_id <> v_user_id then raise exception 'Only the challenged player can accept' using errcode = '42501'; end if;
  if v_battle.created_at < now()-interval '24 hours' then
    update public.nova_competitive_battles set status='expired',resolved_at=now() where id=p_battle_id returning * into v_battle;
    v_result:=jsonb_build_object('success',false,'expired',true,'battle',to_jsonb(v_battle));
    insert into public.nova_competitive_commands(user_id,command_id,command_type,result)
    values (v_user_id,p_command_id,'challenge_accept',v_result);
    return v_result;
  end if;

  perform w.user_id from public.nova_competitive_wallets w
    where w.user_id in (v_battle.challenger_id,v_battle.defender_id)
    order by w.user_id for update;
  select * into v_challenger_wallet from public.nova_competitive_wallets where user_id=v_battle.challenger_id;
  select * into v_defender_wallet from public.nova_competitive_wallets where user_id=v_battle.defender_id;
  if v_defender_wallet.energy < 15 then raise exception 'Insufficient energy' using errcode = '22023'; end if;
  update public.nova_competitive_wallets set energy=energy-15,updated_at=now()
    where user_id=v_battle.defender_id returning * into v_defender_wallet;

  -- The server rolls the battle. Clients cannot submit power, scores, or a winner.
  v_challenger_score:=v_challenger_wallet.power + floor(random()*101)::bigint - 50;
  v_defender_score:=v_defender_wallet.power + floor(random()*101)::bigint - 50;
  if v_challenger_score >= v_defender_score then
    v_winner_id:=v_battle.challenger_id; v_loser_id:=v_battle.defender_id; v_winner_name:=v_battle.challenger_name;
  else
    v_winner_id:=v_battle.defender_id; v_loser_id:=v_battle.challenger_id; v_winner_name:=v_battle.defender_name;
  end if;
  v_reward:=least(2000,500+floor((v_challenger_wallet.power+v_defender_wallet.power)::numeric/200)::bigint);
  if v_loser_id=v_battle.challenger_id then v_loser_influence_delta:=-least(v_challenger_wallet.influence,20);
  else v_loser_influence_delta:=-least(v_defender_wallet.influence,20); end if;

  update public.nova_competitive_wallets
    set credits=credits+v_reward,influence=influence+75,net_worth=net_worth+v_reward,updated_at=now()
    where user_id=v_winner_id;
  update public.nova_competitive_wallets
    set influence=greatest(0,influence-20),updated_at=now()
    where user_id=v_loser_id;
  select * into v_challenger_wallet from public.nova_competitive_wallets where user_id=v_battle.challenger_id;
  select * into v_defender_wallet from public.nova_competitive_wallets where user_id=v_battle.defender_id;
  v_result_text:=v_winner_name || ' فاز بنتيجة ' || v_challenger_score::text || ' مقابل ' || v_defender_score::text;
  update public.nova_competitive_battles
    set status='resolved',challenger_score=v_challenger_score,defender_score=v_defender_score,
        winner_id=v_winner_id,winner_name=v_winner_name,result_text=v_result_text,resolved_at=now()
    where id=p_battle_id returning * into v_battle;

  insert into public.nova_competitive_ledger(user_id,command_id,resource,delta,balance_after)
  values
    (v_battle.defender_id,p_command_id,'energy',-15,v_defender_wallet.energy),
    (v_winner_id,p_command_id,'credits',v_reward,case when v_winner_id=v_battle.challenger_id then v_challenger_wallet.credits else v_defender_wallet.credits end),
    (v_winner_id,p_command_id,'influence',75,case when v_winner_id=v_battle.challenger_id then v_challenger_wallet.influence else v_defender_wallet.influence end),
    (v_loser_id,p_command_id,'influence',v_loser_influence_delta,case when v_loser_id=v_battle.challenger_id then v_challenger_wallet.influence else v_defender_wallet.influence end);

  insert into public.nova_competitive_activities(actor_name,activity_type,headline)
  values (v_winner_name,'challenge_result',v_result_text);
  if v_user_id=v_battle.challenger_id then v_actor_wallet:=v_challenger_wallet; else v_actor_wallet:=v_defender_wallet; end if;
  v_result:=jsonb_build_object('success',true,'battle',to_jsonb(v_battle),'wallet',to_jsonb(v_actor_wallet),'reward',case when v_winner_id=v_user_id then v_reward else 0 end);
  insert into public.nova_competitive_commands(user_id,command_id,command_type,result)
  values (v_user_id,p_command_id,'challenge_accept',v_result);
  return v_result;
end;
$$;

create or replace function private.nova_decline_challenge(p_command_id uuid,p_battle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_battle public.nova_competitive_battles%rowtype;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_command_id is null or p_battle_id is null then raise exception 'Challenge id is required' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_command_id::text,0));
  select result into v_existing from public.nova_competitive_commands where user_id=v_user_id and command_id=p_command_id;
  if found then return v_existing || jsonb_build_object('replayed',true); end if;
  select * into v_battle from public.nova_competitive_battles where id=p_battle_id for update;
  if not found or v_battle.status <> 'pending' then raise exception 'Challenge is no longer pending' using errcode = 'P0002'; end if;
  if v_battle.defender_id <> v_user_id then raise exception 'Only the challenged player can decline' using errcode = '42501'; end if;
  update public.nova_competitive_battles set status='declined',resolved_at=now()
    where id=p_battle_id returning * into v_battle;
  insert into public.nova_competitive_activities(actor_name,activity_type,headline)
  values (v_battle.defender_name,'challenge_decline',v_battle.defender_name || ' رفض تحدي ' || v_battle.challenger_name);
  v_result:=jsonb_build_object('success',true,'battle',to_jsonb(v_battle));
  insert into public.nova_competitive_commands(user_id,command_id,command_type,result)
  values (v_user_id,p_command_id,'challenge_decline',v_result);
  return v_result;
end;
$$;

revoke all on function private.nova_challenge_player(uuid,text) from public,anon,authenticated;
revoke all on function private.nova_accept_challenge(uuid,uuid) from public,anon,authenticated;
revoke all on function private.nova_decline_challenge(uuid,uuid) from public,anon,authenticated;
grant execute on function private.nova_challenge_player(uuid,text) to authenticated;
grant execute on function private.nova_accept_challenge(uuid,uuid) to authenticated;
grant execute on function private.nova_decline_challenge(uuid,uuid) to authenticated;

create or replace function public.nova_challenge_player(p_command_id uuid,p_target_name text)
returns jsonb language sql security invoker
set search_path = pg_catalog,public,private
as $$ select private.nova_challenge_player(p_command_id,p_target_name); $$;
create or replace function public.nova_accept_challenge(p_command_id uuid,p_battle_id uuid)
returns jsonb language sql security invoker
set search_path = pg_catalog,public,private
as $$ select private.nova_accept_challenge(p_command_id,p_battle_id); $$;
create or replace function public.nova_decline_challenge(p_command_id uuid,p_battle_id uuid)
returns jsonb language sql security invoker
set search_path = pg_catalog,public,private
as $$ select private.nova_decline_challenge(p_command_id,p_battle_id); $$;

revoke all on function public.nova_challenge_player(uuid,text) from public,anon;
revoke all on function public.nova_accept_challenge(uuid,uuid) from public,anon;
revoke all on function public.nova_decline_challenge(uuid,uuid) from public,anon;
grant execute on function public.nova_challenge_player(uuid,text) to authenticated;
grant execute on function public.nova_accept_challenge(uuid,uuid) to authenticated;
grant execute on function public.nova_decline_challenge(uuid,uuid) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname='supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='nova_competitive_battles') then
    alter publication supabase_realtime add table public.nova_competitive_battles;
  end if;
end;
$$;
