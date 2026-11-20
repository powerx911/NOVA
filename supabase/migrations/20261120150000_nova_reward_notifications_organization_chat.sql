-- NOVA reward notification hierarchy, claimable achievements, daily stipend alerts and organization chat.
alter table nexora.notifications
  add column if not exists event_key text;

-- Achievement rewards were historically paid immediately on unlock. Preserve that
-- history as claimed so the new claim flow never pays legacy achievements twice.
alter table nexora.player_achievements
  add column if not exists claimed_at timestamptz;

-- Achievement identity/progress remains immutable; only the claim timestamp may
-- transition once from NULL to a timestamp.
drop trigger if exists player_achievements_immutable on nexora.player_achievements;
drop trigger if exists player_achievements_delete_immutable on nexora.player_achievements;
create trigger player_achievements_delete_immutable
before delete on nexora.player_achievements
for each row execute function nexora.reject_immutable_mutation();

create or replace function nexora.guard_player_achievement_claim_update()
returns trigger
language plpgsql
set search_path = 'pg_catalog','nexora'
as $function$
begin
  if (to_jsonb(new) - 'claimed_at') is distinct from (to_jsonb(old) - 'claimed_at') then
    raise exception 'NEXORA immutable achievement records cannot be modified';
  end if;
  if old.claimed_at is not null and new.claimed_at is distinct from old.claimed_at then
    raise exception 'NEXORA achievement reward claim is immutable';
  end if;
  return new;
end;
$function$;
drop trigger if exists player_achievements_claim_guard on nexora.player_achievements;
create trigger player_achievements_claim_guard
before update on nexora.player_achievements
for each row execute function nexora.guard_player_achievement_claim_update();
revoke all on function nexora.guard_player_achievement_claim_update() from public,anon,authenticated;

update nexora.player_achievements
set claimed_at = coalesce(claimed_at, unlocked_at, now())
where claimed_at is null;

-- Keep the idempotency event key on the notification row so clients can attach
-- badges to the exact item (contract, achievement, or daily reward).
create or replace function nexora.emit_notification_once(
  p_uid text,
  p_event_key text,
  p_title_ar text,
  p_title_en text,
  p_body_ar text,
  p_body_en text,
  p_type text default 'economy'
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_language text;
  v_enabled boolean;
  v_inserted text;
begin
  select language,notifications_enabled into v_language,v_enabled
  from nexora.player_private where user_id=p_uid;
  if not found or not coalesce(v_enabled,false) then return; end if;

  insert into nexora.notification_events(user_id,event_key)
  values(p_uid,p_event_key)
  on conflict(user_id,event_key) do nothing
  returning event_key into v_inserted;
  if v_inserted is null then return; end if;

  insert into nexora.notifications(id,user_id,title,body,type,is_read,event_key)
  values(
    'ntf_'||gen_random_uuid()::text,p_uid,
    case when v_language='ar' then p_title_ar else p_title_en end,
    case when v_language='ar' then p_body_ar else p_body_en end,
    p_type,false,p_event_key
  );
end;
$function$;
revoke all on function nexora.emit_notification_once(text,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function nexora.emit_notification_once(text,text,text,text,text,text,text) to service_role;

-- Unlocking an achievement now creates a claimable reward instead of crediting
-- the wallet automatically. Existing rows were marked claimed above.
create or replace function nexora.unlock_eligible_achievements(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_new_ids text[] := '{}'::text[];
  v_all_ids text[] := '{}'::text[];
  v_achievement_id text;
  v_revenue bigint;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select coalesce(sum(amount),0) into v_revenue
  from nexora.transactions
  where to_uid=p_uid and type='company_collect' and status='completed';

  with eligible as (
    select a.id
    from (values
      ('nova_whale_i','spent',50000,2000),
      ('nova_whale_ii','spent',250000,8000),
      ('nova_whale_iii','spent',1000000,25000),
      ('nova_whale_iv','spent',5000000,75000),
      ('nova_market_i','trades',250,1500),
      ('nova_market_ii','trades',1000,6000),
      ('nova_market_iii','trades',5000,25000),
      ('nova_market_iv','trades',20000,75000),
      ('nova_industry_i','produced',500,2000),
      ('nova_industry_ii','produced',2500,8000),
      ('nova_industry_iii','produced',10000,30000),
      ('nova_industry_iv','produced',50000,90000),
      ('nova_enterprise_i','revenue',100000,5000),
      ('nova_enterprise_ii','revenue',500000,15000),
      ('nova_enterprise_iii','revenue',2000000,50000),
      ('nova_enterprise_iv','revenue',10000000,150000)
    ) as a(id,metric,threshold,reward)
    where case a.metric
      when 'spent' then v_wallet.total_spent
      when 'trades' then coalesce((v_profile.stats->>'tradesCount')::bigint,0)
      when 'produced' then coalesce((v_profile.stats->>'totalProduced')::bigint,0)
      when 'revenue' then v_revenue
      else 0
    end >= a.threshold
  ), inserted as (
    insert into nexora.player_achievements(user_id,achievement_id)
    select p_uid,eligible.id from eligible
    on conflict(user_id,achievement_id) do nothing
    returning achievement_id
  )
  select coalesce(array_agg(achievement_id),'{}'::text[]) into v_new_ids from inserted;

  foreach v_achievement_id in array v_new_ids loop
    perform nexora.emit_notification_once(
      p_uid,'achievement-ready:'||v_achievement_id,
      'مكافأة الإنجاز جاهزة','Achievement reward ready',
      'اكتمل إنجازك وأصبحت مكافأته جاهزة للاستلام ('||v_achievement_id||').',
      'You completed an achievement. Its reward is ready to claim ('||v_achievement_id||').',
      'mission'
    );
  end loop;

  select coalesce(array_agg(achievement_id),'{}'::text[]) into v_all_ids
  from nexora.player_achievements where user_id=p_uid;

  return jsonb_build_object(
    'unlocked_ids',v_all_ids,
    'newly_unlocked_ids',v_new_ids,
    'new_rewards',coalesce((
      select sum(reward) from (values
        ('nova_whale_i',2000::bigint),('nova_whale_ii',8000::bigint),('nova_whale_iii',25000::bigint),('nova_whale_iv',75000::bigint),
        ('nova_market_i',1500::bigint),('nova_market_ii',6000::bigint),('nova_market_iii',25000::bigint),('nova_market_iv',75000::bigint),
        ('nova_industry_i',2000::bigint),('nova_industry_ii',8000::bigint),('nova_industry_iii',30000::bigint),('nova_industry_iv',90000::bigint),
        ('nova_enterprise_i',5000::bigint),('nova_enterprise_ii',15000::bigint),('nova_enterprise_iii',50000::bigint),('nova_enterprise_iv',150000::bigint)
      ) as rewards(id,reward) where id=any(v_new_ids)
    ),0)
  );
end;
$function$;
revoke all on function nexora.unlock_eligible_achievements(text) from public,anon,authenticated;
grant execute on function nexora.unlock_eligible_achievements(text) to service_role;

create or replace function nexora.claim_achievement_reward(p_uid text,p_achievement_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_achievement nexora.player_achievements%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_reward bigint;
  v_tx text:='tx_'||gen_random_uuid()::text;
begin
  if p_achievement_id not in (
    'nova_whale_i','nova_whale_ii','nova_whale_iii','nova_whale_iv',
    'nova_market_i','nova_market_ii','nova_market_iii','nova_market_iv',
    'nova_industry_i','nova_industry_ii','nova_industry_iii','nova_industry_iv',
    'nova_enterprise_i','nova_enterprise_ii','nova_enterprise_iii','nova_enterprise_iv'
  ) then raise exception 'INVALID_ACHIEVEMENT'; end if;

  select * into v_achievement
  from nexora.player_achievements
  where user_id=p_uid and achievement_id=p_achievement_id
  for update;
  if not found then raise exception 'ACHIEVEMENT_NOT_UNLOCKED'; end if;
  if v_achievement.claimed_at is not null then raise exception 'ACHIEVEMENT_ALREADY_CLAIMED'; end if;

  select reward into v_reward from (values
    ('nova_whale_i',2000::bigint),('nova_whale_ii',8000::bigint),('nova_whale_iii',25000::bigint),('nova_whale_iv',75000::bigint),
    ('nova_market_i',1500::bigint),('nova_market_ii',6000::bigint),('nova_market_iii',25000::bigint),('nova_market_iv',75000::bigint),
    ('nova_industry_i',2000::bigint),('nova_industry_ii',8000::bigint),('nova_industry_iii',30000::bigint),('nova_industry_iv',90000::bigint),
    ('nova_enterprise_i',5000::bigint),('nova_enterprise_ii',15000::bigint),('nova_enterprise_iii',50000::bigint),('nova_enterprise_iv',150000::bigint)
  ) as rewards(id,reward) where id=p_achievement_id;

  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  update nexora.wallets
  set balance=balance+v_reward,total_earned=total_earned+v_reward,last_tx_id=v_tx,updated_at=now()
  where user_id=p_uid;

  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_reward,0,v_reward,'mission_reward',p_achievement_id,
    'NOVA achievement reward: '||p_achievement_id,'completed');

  update nexora.player_achievements set claimed_at=now()
  where user_id=p_uid and achievement_id=p_achievement_id;

  update nexora.notifications set is_read=true
  where user_id=p_uid and event_key='achievement-ready:'||p_achievement_id;

  return jsonb_build_object('ok',true,'achievement_id',p_achievement_id,'reward',v_reward);
end;
$function$;
revoke all on function nexora.claim_achievement_reward(text,text) from public,anon,authenticated;
grant execute on function nexora.claim_achievement_reward(text,text) to service_role;

-- A daily operating reward is claimable until the player claims today's stipend.
create or replace function nexora.notify_daily_stipend_ready_for_user(p_uid text)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_date text:=to_char(now() at time zone 'UTC','YYYY-MM-DD');
begin
  if exists(select 1 from nexora.daily_claims where user_id=p_uid and date_key=v_date) then
    return 0;
  end if;
  perform nexora.emit_notification_once(
    p_uid,'daily-stipend-ready:'||v_date,
    'التشغيل اليومي جاهز','Daily stipend ready',
    'مكافأة التشغيل اليومية جاهزة للاستلام.',
    'Your daily operating stipend is ready to claim.',
    'economy'
  );
  return 1;
end;
$function$;

create or replace function nexora.notify_daily_stipend_ready()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_player record;
  v_count integer:=0;
begin
  for v_player in select user_id from nexora.player_profiles order by user_id loop
    v_count:=v_count+nexora.notify_daily_stipend_ready_for_user(v_player.user_id);
  end loop;
  return v_count;
end;
$function$;

create or replace function nexora.mark_daily_stipend_notification_claimed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update nexora.notifications set is_read=true
  where user_id=new.user_id
    and event_key like 'daily-stipend-ready:%'
    and is_read=false;
  return new;
end;
$function$;
drop trigger if exists nova_mark_daily_stipend_notification_claimed on nexora.daily_claims;
create trigger nova_mark_daily_stipend_notification_claimed
after insert on nexora.daily_claims
for each row execute function nexora.mark_daily_stipend_notification_claimed();

revoke all on function nexora.notify_daily_stipend_ready_for_user(text) from public,anon,authenticated;
revoke all on function nexora.notify_daily_stipend_ready() from public,anon,authenticated;
revoke all on function nexora.mark_daily_stipend_notification_claimed() from public,anon,authenticated;
grant execute on function nexora.notify_daily_stipend_ready_for_user(text) to service_role;
grant execute on function nexora.notify_daily_stipend_ready() to service_role;

-- Organization chat is private to current organization members and server-authoritative.
create table if not exists nexora.organization_chat_messages (
  id text primary key,
  org_id text not null references nexora.organizations(id) on delete cascade,
  sender_uid text not null,
  sender_name text not null,
  message_text text not null check(length(message_text) between 1 and 280),
  created_at timestamptz not null default now()
);
create index if not exists organization_chat_messages_order_idx
  on nexora.organization_chat_messages(org_id,created_at desc);
alter table nexora.organization_chat_messages enable row level security;
revoke all on nexora.organization_chat_messages from public,anon,authenticated;

create or replace function nexora.list_organization_chat_messages(p_user_id text,p_org_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_messages jsonb;
begin
  if p_org_id is null or not exists(
    select 1 from nexora.organization_members
    where org_id=p_org_id and user_id=p_user_id
  ) or not exists(
    select 1 from nexora.player_profiles
    where user_id=p_user_id and org_id=p_org_id
  ) then
    raise exception 'ORG_CHAT_ACCESS_DENIED';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',m.id,'senderUid',m.sender_uid,'senderName',m.sender_name,
    'text',m.message_text,'createdAt',m.created_at
  ) order by m.created_at),'[]'::jsonb)
  into v_messages
  from (
    select id,sender_uid,sender_name,message_text,created_at
    from nexora.organization_chat_messages
    where org_id=p_org_id
    order by created_at desc
    limit 80
  ) m;
  return jsonb_build_object('messages',v_messages);
end;
$function$;

create or replace function nexora.send_organization_chat_message(
  p_user_id text,p_org_id text,p_text text,p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_message text;
  v_message_id text;
  v_rate_id text;
begin
  if p_request_id is null or p_org_id is null then raise exception 'INVALID_REQUEST'; end if;
  select * into v_profile from nexora.player_profiles
  where user_id=p_user_id and org_id=p_org_id;
  if not found or not exists(
    select 1 from nexora.organization_members
    where org_id=p_org_id and user_id=p_user_id
  ) then
    raise exception 'ORG_CHAT_ACCESS_DENIED';
  end if;

  v_message:=left(trim(regexp_replace(regexp_replace(coalesce(p_text,''),'[<>]','','g'),'[[:space:]]+',' ','g')),280);
  if v_message='' then raise exception 'EMPTY_MESSAGE'; end if;

  v_message_id:='orgmsg_'||p_user_id||'_'||p_request_id::text;
  if exists(select 1 from nexora.organization_chat_messages where id=v_message_id and sender_uid=p_user_id and org_id=p_org_id) then
    return jsonb_build_object('ok',true,'replayed',true);
  end if;

  insert into nexora.chat_rate_limits(id,last_sent_at)
  values('orgchat_'||p_user_id,now())
  on conflict(id) do update set last_sent_at=excluded.last_sent_at
  where nexora.chat_rate_limits.last_sent_at<=now()-interval '3 seconds'
  returning id into v_rate_id;
  if v_rate_id is null then raise exception 'CHAT_RATE_LIMIT'; end if;

  insert into nexora.organization_chat_messages(id,org_id,sender_uid,sender_name,message_text)
  values(v_message_id,p_org_id,p_user_id,v_profile.username,v_message);
  return jsonb_build_object('ok',true);
end;
$function$;

revoke all on function nexora.list_organization_chat_messages(text,text) from public,anon,authenticated;
revoke all on function nexora.send_organization_chat_message(text,text,text,uuid) from public,anon,authenticated;
grant execute on function nexora.list_organization_chat_messages(text,text) to service_role;
grant execute on function nexora.send_organization_chat_message(text,text,text,uuid) to service_role;

-- Clear readiness notifications when their underlying reward/action is claimed.
create or replace function nexora.mark_mission_reward_notification_claimed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update nexora.notifications set is_read=true
  where user_id=new.user_id
    and event_key='mission-ready:'||new.mission_id||':'||new.period_key;
  return new;
end;
$function$;
drop trigger if exists nova_mark_mission_reward_notification_claimed on nexora.player_missions;
create trigger nova_mark_mission_reward_notification_claimed
after insert on nexora.player_missions
for each row execute function nexora.mark_mission_reward_notification_claimed();

create or replace function nexora.mark_company_vault_notification_claimed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.vault_balance<old.vault_balance
    or new.last_collected_at is distinct from old.last_collected_at
    or new.vault_level>old.vault_level then
    update nexora.notifications set is_read=true
    where user_id=new.owner_uid
      and (event_key like 'company-vault-full:'||new.id||':%'
        or (event_key is null and title in ('خزنة الشركة ممتلئة','Company vault is full')
          and body like '%'||new.name||'%'));
  end if;
  return new;
end;
$function$;
drop trigger if exists nova_mark_company_vault_notification_claimed on nexora.companies;
create trigger nova_mark_company_vault_notification_claimed
after update of vault_balance,last_collected_at,vault_level on nexora.companies
for each row execute function nexora.mark_company_vault_notification_claimed();

create or replace function nexora.mark_factory_warehouse_notification_claimed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.warehouse_qty<old.warehouse_qty or new.warehouse_level>old.warehouse_level then
    update nexora.notifications set is_read=true
    where user_id=new.owner_uid
      and (event_key like 'factory-warehouse-full:'||new.id||':%'
        or (event_key is null and title in ('مستودع المصنع ممتلئ','Factory warehouse is full')
          and body like '%'||new.name||'%'));
  end if;
  return new;
end;
$function$;
drop trigger if exists nova_mark_factory_warehouse_notification_claimed on nexora.factories;
create trigger nova_mark_factory_warehouse_notification_claimed
after update of warehouse_qty,warehouse_level on nexora.factories
for each row execute function nexora.mark_factory_warehouse_notification_claimed();

-- The legacy claim path could insert a title-only notification while settling a
-- processing contract. Route it through the same idempotent event key as the
-- background notifier, and clear it immediately when the reward is claimed.
do $patch$
declare
  v_definition text;
  v_old_notification text := $old$
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'ntf_'||gen_random_uuid()::text,p_uid,'CONTRACT_READY','Your contract is ready to claim','economy',false
    where exists(select 1 from nexora.player_private pp where pp.user_id=p_uid and pp.notifications_enabled=true);$old$;
  v_new_notification text := $new$
    perform nexora.emit_notification_once(
      p_uid,'contract-ready:'||p_contract_id,
      'العقد جاهز للاستلام','Contract ready to claim',
      'أصبحت مكافأة أحد عقودك جاهزة للاستلام.','A contract reward is ready to claim.','economy'
    );$new$;
  v_old_completion text := $completion$
  update nexora.contract_offers set status='completed',completed_at=now(),updated_at=now() where id=p_contract_id;$completion$;
  v_new_completion text := $completion$
  update nexora.contract_offers set status='completed',completed_at=now(),updated_at=now() where id=p_contract_id;
  update nexora.notifications set is_read=true
  where user_id=p_uid and event_key='contract-ready:'||p_contract_id;$completion$;
begin
  select pg_get_functiondef('nexora.claim_dynamic_contract(text,text)'::regprocedure)
    into v_definition;
  if position(v_old_notification in v_definition)=0
    or position(v_old_completion in v_definition)=0 then
    raise exception 'CONTRACT_NOTIFICATION_PATCH_FAILED';
  end if;
  v_definition:=replace(v_definition,v_old_notification,v_new_notification);
  v_definition:=replace(v_definition,v_old_completion,v_new_completion);
  execute v_definition;
end;
$patch$;

revoke all on function nexora.mark_mission_reward_notification_claimed() from public,anon,authenticated;
revoke all on function nexora.mark_company_vault_notification_claimed() from public,anon,authenticated;
revoke all on function nexora.mark_factory_warehouse_notification_claimed() from public,anon,authenticated;

-- Run the daily notification sweep on the server; bootstrap also checks immediately
-- for a player returning to the game after the UTC reset.
do $do$
declare
  v_job record;
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    for v_job in select jobid from cron.job where jobname='nova-daily-stipend-ready'
    loop perform cron.unschedule(v_job.jobid); end loop;
    perform cron.schedule('nova-daily-stipend-ready','*/5 * * * *',
      'select nexora.notify_daily_stipend_ready();');
  end if;
end;
$do$;
