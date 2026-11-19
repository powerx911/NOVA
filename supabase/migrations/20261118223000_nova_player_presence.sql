-- Presence heartbeat for NOVA social surfaces.
create table if not exists nexora.player_presence (
  user_id text primary key,
  online_since timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index if not exists player_presence_last_seen_idx on nexora.player_presence(last_seen_at desc);
alter table nexora.player_presence enable row level security;
revoke all on nexora.player_presence from public, anon, authenticated;

create or replace function nexora.touch_player_presence(p_user_id text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare v_presence player_presence%rowtype;
begin
  if p_user_id is null or length(p_user_id)<1 or length(p_user_id)>128 then raise exception 'INVALID_USER'; end if;
  insert into player_presence(user_id,online_since,last_seen_at) values(p_user_id,now(),now())
  on conflict(user_id) do update set
    online_since=case when player_presence.last_seen_at<now()-interval '2 minutes' then now() else player_presence.online_since end,
    last_seen_at=now()
  returning * into v_presence;
  return jsonb_build_object('uid',v_presence.user_id,'onlineSince',v_presence.online_since,'lastSeenAt',v_presence.last_seen_at);
end; $$;

create or replace function nexora.get_players_presence(p_user_ids text[])
returns jsonb language sql security definer set search_path=nexora,pg_temp as $$
  select jsonb_build_object('players',coalesce(jsonb_agg(jsonb_build_object(
    'uid',ids.uid,
    'isOnline',coalesce(p.last_seen_at>=now()-interval '2 minutes',false),
    'onlineSince',case when p.last_seen_at>=now()-interval '2 minutes' then p.online_since else null end,
    'lastSeenAt',p.last_seen_at
  )),'[]'::jsonb))
  from (select distinct unnest(coalesce(p_user_ids,'{}'::text[])) as uid limit 60) ids
  left join player_presence p on p.user_id=ids.uid;
$$;
revoke all on function nexora.touch_player_presence(text) from public,anon,authenticated;
revoke all on function nexora.get_players_presence(text[]) from public,anon,authenticated;
grant execute on function nexora.touch_player_presence(text) to service_role;
grant execute on function nexora.get_players_presence(text[]) to service_role;
