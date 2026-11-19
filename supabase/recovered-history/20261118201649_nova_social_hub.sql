-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118201649
-- Remote migration name: nova_social_hub
-- Source: Supabase postgres_logs at 2026-11-18 20:16:49 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

-- NOVA social hub: private/global chat, player discovery, invites, blocks and reports.
create table if not exists nexora.user_blocks (
 id text primary key, owner_uid text not null, target_uid text not null, created_at timestamptz not null default now(),
 check (owner_uid <> target_uid), unique(owner_uid,target_uid)
);
create table if not exists nexora.chat_rate_limits (id text primary key, last_sent_at timestamptz);
create table if not exists nexora.conversations (
 id text primary key, participants text[] not null, participant_names jsonb not null default '{}'::jsonb,
 participant_avatars jsonb not null default '{}'::jsonb, last_message text not null default '',
 last_message_at timestamptz not null default now(), last_sender_uid text not null default '',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(cardinality(participants)=2)
);
create index if not exists conversations_participants_gin_idx on nexora.conversations using gin(participants);
create index if not exists conversations_last_message_at_idx on nexora.conversations(last_message_at desc);
create table if not exists nexora.conversation_messages (
 id text primary key, conversation_id text not null references nexora.conversations(id) on delete cascade,
 sender_uid text not null, sender_name text not null, message_text text not null check(length(message_text) between 1 and 1000),
 created_at timestamptz not null default now()
);
create index if not exists conversation_messages_order_idx on nexora.conversation_messages(conversation_id,created_at desc);
create table if not exists nexora.global_chat_messages (
 id text primary key, sender_uid text not null, sender_name text not null, avatar_id text not null default 'strategist',
 message_text text not null check(length(message_text) between 1 and 280), created_at timestamptz not null default now()
);
create index if not exists global_chat_created_idx on nexora.global_chat_messages(created_at desc);
create table if not exists nexora.organization_invites (
 id text primary key, org_id text not null, org_name text not null, org_tag text not null,
 target_uid text not null, inviter_uid text not null, inviter_name text not null,
 status text not null check(status in ('pending','accepted','rejected','cancelled')),
 created_at timestamptz not null default now(), responded_at timestamptz
);
create index if not exists org_invites_target_status_idx on nexora.organization_invites(target_uid,status);
create table if not exists nexora.player_reports (
 id text primary key, reporter_uid text not null, target_uid text not null,
 reason text not null check(reason in ('harassment','spam','inappropriate','impersonation','other')),
 status text not null default 'open' check(status in ('open','reviewing','closed')),
 created_at timestamptz not null default now(), check(reporter_uid <> target_uid)
);
create index if not exists player_reports_status_created_idx on nexora.player_reports(status,created_at desc);
alter table nexora.user_blocks enable row level security;
alter table nexora.chat_rate_limits enable row level security;
alter table nexora.conversations enable row level security;
alter table nexora.conversation_messages enable row level security;
alter table nexora.global_chat_messages enable row level security;
alter table nexora.organization_invites enable row level security;
alter table nexora.player_reports enable row level security;
revoke all on nexora.user_blocks,nexora.chat_rate_limits,nexora.conversations,nexora.conversation_messages,
 nexora.global_chat_messages,nexora.organization_invites,nexora.player_reports from public,anon,authenticated;

create or replace function nexora.get_public_player_profile(p_target_uid text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare p player_profiles%rowtype;
begin
 if p_target_uid is null or length(p_target_uid)>128 then raise exception 'INVALID_TARGET'; end if;
 select * into p from player_profiles where user_id=p_target_uid;
 if not found then raise exception 'PLAYER_NOT_FOUND'; end if;
 return jsonb_build_object('uid',p.user_id,'username',p.username,'avatarId',p.avatar_id,'title',p.title,
  'level',p.level,'reputation',p.reputation,'influence',p.influence,'orgId',p.org_id);
end $$;

create or replace function nexora.search_players(p_user_id text,p_prefix text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare v_prefix text; v_players jsonb;
begin
 v_prefix:=lower(trim(coalesce(p_prefix,'')));
 if p_user_id is null then raise exception 'UNAUTHENTICATED'; end if;
 if length(v_prefix)<2 or length(v_prefix)>24 or v_prefix !~ '^[a-z0-9_]+$' then return jsonb_build_object('players','[]'::jsonb); end if;
 select coalesce(jsonb_agg(jsonb_build_object('uid',q.user_id,'username',q.username,'avatarId',q.avatar_id,
  'title',q.title,'level',q.level,'reputation',q.reputation,'influence',q.influence,'orgId',q.org_id)
  order by q.username_lower),'[]'::jsonb) into v_players
 from (select user_id,username,username_lower,avatar_id,title,level,reputation,influence,org_id
  from player_profiles where username_lower like v_prefix||'%' and user_id<>p_user_id
  order by username_lower limit 15) q;
 return jsonb_build_object('players',v_players);
end $$;

create or replace function nexora.list_blocked_players(p_user_id text)
returns jsonb language sql security definer set search_path=nexora,pg_temp as $$
 select jsonb_build_object('blockedUids',coalesce(jsonb_agg(target_uid),'[]'::jsonb))
 from user_blocks where owner_uid=p_user_id
$$;

create or replace function nexora.block_player(p_user_id text,p_target_uid text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
begin
 if p_target_uid is null or p_target_uid=p_user_id or length(p_target_uid)>128 then raise exception 'INVALID_TARGET'; end if;
 if not exists(select 1 from player_profiles where user_id=p_user_id) or not exists(select 1 from player_profiles where user_id=p_target_uid) then raise exception 'PLAYER_NOT_FOUND'; end if;
 insert into user_blocks(id,owner_uid,target_uid) values(p_user_id||'__'||p_target_uid,p_user_id,p_target_uid) on conflict(owner_uid,target_uid) do nothing;
 return jsonb_build_object('ok',true);
end $$;
create or replace function nexora.unblock_player(p_user_id text,p_target_uid text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
begin delete from user_blocks where owner_uid=p_user_id and target_uid=p_target_uid; return jsonb_build_object('ok',true); end $$;

create or replace function nexora.submit_player_report(p_user_id text,p_target_uid text,p_reason text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare rid text; rate_id text;
begin
 if p_request_id is null or p_target_uid is null or p_target_uid=p_user_id or p_reason not in ('harassment','spam','inappropriate','impersonation','other') then raise exception 'INVALID_REPORT'; end if;
 rid:='report_'||p_user_id||'_'||p_request_id::text;
 if exists(select 1 from player_reports where id=rid and reporter_uid=p_user_id) then return jsonb_build_object('ok',true,'replayed',true); end if;
 if not exists(select 1 from player_profiles where user_id=p_target_uid) then raise exception 'PLAYER_NOT_FOUND'; end if;
 insert into chat_rate_limits(id,last_sent_at) values('report_'||p_user_id,now())
 on conflict(id) do update set last_sent_at=excluded.last_sent_at where chat_rate_limits.last_sent_at<=now()-interval '30 seconds' returning id into rate_id;
 if rate_id is null then raise exception 'REPORT_RATE_LIMIT'; end if;
 insert into player_reports(id,reporter_uid,target_uid,reason) values(rid,p_user_id,p_target_uid,p_reason);
 return jsonb_build_object('ok',true);
end $$;

create or replace function nexora.open_direct_conversation(p_user_id text,p_target_uid text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare a player_profiles%rowtype; b player_profiles%rowtype; pair text[]; cid text;
begin
 if p_target_uid is null or p_target_uid=p_user_id then raise exception 'INVALID_TARGET'; end if;
 select * into a from player_profiles where user_id=p_user_id; select * into b from player_profiles where user_id=p_target_uid;
 if a.user_id is null or b.user_id is null then raise exception 'PLAYER_NOT_FOUND'; end if;
 if exists(select 1 from user_blocks where (owner_uid=p_user_id and target_uid=p_target_uid) or (owner_uid=p_target_uid and target_uid=p_user_id)) then raise exception 'PLAYER_BLOCKED'; end if;
 select array_agg(x order by x) into pair from unnest(array[p_user_id,p_target_uid]) x;
 cid:='dm_'||array_to_string(pair,'_');
 insert into conversations(id,participants,participant_names,participant_avatars,last_sender_uid)
 values(cid,pair,jsonb_build_object(p_user_id,a.username,p_target_uid,b.username),jsonb_build_object(p_user_id,a.avatar_id,p_target_uid,b.avatar_id),'')
 on conflict(id) do nothing;
 if not exists(select 1 from conversations where id=cid and participants=pair) then raise exception 'CONVERSATION_ACCESS_DENIED'; end if;
 return jsonb_build_object('conversationId',cid);
end $$;

create or replace function nexora.send_direct_message(p_user_id text,p_target_uid text,p_text text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare a player_profiles%rowtype; b player_profiles%rowtype; pair text[]; cid text; mid text; msg text; rate_id text;
begin
 if p_request_id is null or p_target_uid is null or p_target_uid=p_user_id then raise exception 'INVALID_REQUEST'; end if;
 msg:=left(trim(regexp_replace(regexp_replace(coalesce(p_text,''),'[<>]','','g'),'[[:space:]]+',' ','g')),1000);
 if msg='' then raise exception 'INVALID_MESSAGE'; end if;
 select * into a from player_profiles where user_id=p_user_id; select * into b from player_profiles where user_id=p_target_uid;
 if a.user_id is null or b.user_id is null then raise exception 'PLAYER_NOT_FOUND'; end if;
 if exists(select 1 from user_blocks where (owner_uid=p_user_id and target_uid=p_target_uid) or (owner_uid=p_target_uid and target_uid=p_user_id)) then raise exception 'PLAYER_BLOCKED'; end if;
 select array_agg(x order by x) into pair from unnest(array[p_user_id,p_target_uid]) x;
 cid:='dm_'||array_to_string(pair,'_'); mid:='msg_'||p_user_id||'_'||p_request_id::text;
 if exists(select 1 from conversation_messages where id=mid and sender_uid=p_user_id and conversation_id=cid) then return jsonb_build_object('ok',true,'replayed',true); end if;
 insert into conversations(id,participants,participant_names,participant_avatars,last_sender_uid)
 values(cid,pair,jsonb_build_object(p_user_id,a.username,p_target_uid,b.username),jsonb_build_object(p_user_id,a.avatar_id,p_target_uid,b.avatar_id),'')
 on conflict(id) do nothing;
 if not exists(select 1 from conversations where id=cid and participants=pair) then raise exception 'CONVERSATION_ACCESS_DENIED'; end if;
 insert into chat_rate_limits(id,last_sent_at) values('dm_'||p_user_id,now())
 on conflict(id) do update set last_sent_at=excluded.last_sent_at where chat_rate_limits.last_sent_at<=now()-interval '1 second' returning id into rate_id;
 if rate_id is null then raise exception 'CHAT_RATE_LIMIT'; end if;
 insert into conversation_messages(id,conversation_id,sender_uid,sender_name,message_text) values(mid,cid,p_user_id,a.username,msg);
 update conversations set last_message=left(msg,120),last_message_at=now(),last_sender_uid=p_user_id,updated_at=now() where id=cid;
 return jsonb_build_object('ok',true);
end $$;

create or replace function nexora.send_global_chat_message(p_user_id text,p_text text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare p player_profiles%rowtype; msg text; mid text; rate_id text;
begin
 msg:=left(trim(regexp_replace(regexp_replace(coalesce(p_text,''),'[<>]','','g'),'[[:space:]]+',' ','g')),280);
 if msg='' or p_request_id is null then raise exception 'EMPTY_MESSAGE'; end if;
 select * into p from player_profiles where user_id=p_user_id; if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
 mid:='gmsg_'||p_user_id||'_'||p_request_id::text;
 if exists(select 1 from global_chat_messages where id=mid and sender_uid=p_user_id) then return jsonb_build_object('ok',true,'replayed',true); end if;
 insert into chat_rate_limits(id,last_sent_at) values('global_'||p_user_id,now())
 on conflict(id) do update set last_sent_at=excluded.last_sent_at where chat_rate_limits.last_sent_at<=now()-interval '3 seconds' returning id into rate_id;
 if rate_id is null then raise exception 'CHAT_RATE_LIMIT'; end if;
 insert into global_chat_messages(id,sender_uid,sender_name,avatar_id,message_text) values(mid,p_user_id,p.username,p.avatar_id,msg);
 return jsonb_build_object('ok',true);
end $$;

create or replace function nexora.list_direct_conversations(p_user_id text)
returns jsonb language sql security definer set search_path=nexora,pg_temp as $$
 select jsonb_build_object('conversations',coalesce(jsonb_agg(to_jsonb(c) order by c.last_message_at desc),'[]'::jsonb))
 from (select * from conversations where p_user_id=any(participants) order by last_message_at desc limit 50) c
$$;
create or replace function nexora.list_direct_messages(p_user_id text,p_conversation_id text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare msgs jsonb;
begin
 if not exists(select 1 from conversations where id=p_conversation_id and p_user_id=any(participants)) then raise exception 'CONVERSATION_ACCESS_DENIED'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'senderUid',m.sender_uid,'senderName',m.sender_name,'text',m.message_text,'createdAt',m.created_at) order by m.created_at),'[]'::jsonb)
 into msgs from (select * from conversation_messages where conversation_id=p_conversation_id order by created_at desc limit 80) m;
 return jsonb_build_object('messages',msgs);
end $$;
create or replace function nexora.list_global_chat_messages(p_user_id text)
returns jsonb language sql security definer set search_path=nexora,pg_temp as $$
 select jsonb_build_object('messages',coalesce(jsonb_agg(jsonb_build_object('id',m.id,'senderUid',m.sender_uid,'senderName',m.sender_name,'avatarId',m.avatar_id,'text',m.message_text,'createdAt',m.created_at) order by m.created_at),'[]'::jsonb))
 from (select * from global_chat_messages order by created_at desc limit 60) m
$$;
create or replace function nexora.list_organization_invites(p_user_id text)
returns jsonb language sql security definer set search_path=nexora,pg_temp as $$
 select jsonb_build_object('invites',coalesce(jsonb_agg(jsonb_build_object('id',i.id,'orgId',i.org_id,'orgName',i.org_name,'orgTag',i.org_tag,'inviterName',i.inviter_name,'status',i.status,'targetUid',i.target_uid) order by i.created_at desc),'[]'::jsonb))
 from organization_invites i where i.target_uid=p_user_id and i.status='pending'
$$;

create or replace function nexora.invite_player_to_organization(p_user_id text,p_target_uid text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare a player_profiles%rowtype; b player_profiles%rowtype; o organizations%rowtype; m organization_members%rowtype; iid text;
begin
 select * into a from player_profiles where user_id=p_user_id for update;
 if a.user_id is null or a.org_id is null then raise exception 'NOT_IN_ORG'; end if;
 select * into o from organizations where id=a.org_id for update;
 select * into m from organization_members where org_id=o.id and user_id=p_user_id;
 if m.user_id is null or (m.role not in ('leader','deputy') and not (m.permissions @> '["manage_members"]'::jsonb)) then raise exception 'INVITE_PERMISSION_REQUIRED'; end if;
 select * into b from player_profiles where user_id=p_target_uid for update;
 if b.user_id is null then raise exception 'PLAYER_NOT_FOUND'; end if;
 if b.org_id is not null then raise exception 'TARGET_ALREADY_IN_ORG'; end if;
 iid:=o.id||'_'||p_target_uid;
 insert into organization_invites(id,org_id,org_name,org_tag,target_uid,inviter_uid,inviter_name,status)
 values(iid,o.id,o.name,o.tag,p_target_uid,p_user_id,a.username,'pending')
 on conflict(id) do update set status='pending',inviter_uid=excluded.inviter_uid,inviter_name=excluded.inviter_name,created_at=now(),responded_at=null
 where organization_invites.status<>'pending';
 if not found then raise exception 'INVITE_ALREADY_PENDING'; end if;
 return jsonb_build_object('ok',true);
end $$;
create or replace function nexora.respond_organization_invite(p_user_id text,p_invite_id text,p_response text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare i organization_invites%rowtype; o organizations%rowtype; p player_profiles%rowtype; cap integer;
begin
 select * into i from organization_invites where id=p_invite_id for update;
 if i.id is null or i.target_uid<>p_user_id or i.status<>'pending' then raise exception 'INVITE_NOT_AVAILABLE'; end if;
 if p_response='decline' then update organization_invites set status='rejected',responded_at=now() where id=i.id; return jsonb_build_object('ok',true,'status','rejected'); end if;
 if p_response<>'accept' then raise exception 'INVALID_RESPONSE'; end if;
 select * into o from organizations where id=i.org_id for update;
 select * into p from player_profiles where user_id=p_user_id for update;
 if o.id is null or p.user_id is null or p.org_id is not null then raise exception 'ALREADY_IN_ORG'; end if;
 cap:=coalesce(o.member_capacity,least(70,20+(greatest(1,o.level)-1)*5));
 if o.member_count>=cap then raise exception 'ORG_FULL'; end if;
 insert into organization_members(org_id,user_id,username,role,permissions,joined_at) values(o.id,p_user_id,p.username,'member','[]'::jsonb,now());
 update player_profiles set org_id=o.id,updated_at=now() where user_id=p_user_id;
 update organizations set member_count=member_count+1,updated_at=now() where id=o.id;
 update organization_invites set status='accepted',responded_at=now() where id=i.id;
 return jsonb_build_object('ok',true,'status','accepted');
end $$;

do $$
declare f record;
begin
 for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='nexora' and p.proname in ('get_public_player_profile','search_players','list_blocked_players','block_player','unblock_player','submit_player_report','open_direct_conversation','send_direct_message','send_global_chat_message','list_direct_conversations','list_direct_messages','list_global_chat_messages','list_organization_invites','invite_player_to_organization','respond_organization_invite')
 loop execute format('revoke all on function %s from public, anon, authenticated',f.sig); execute format('grant execute on function %s to service_role',f.sig); end loop;
end $$;
;
