-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(14);

select extensions.ok(
  exists(select 1 from information_schema.columns where table_schema='nexora' and table_name='notifications' and column_name='event_key'),
  'notifications retain their originating event key for hierarchical badges'
);

select extensions.ok(
  exists(select 1 from information_schema.columns where table_schema='nexora' and table_name='player_achievements' and column_name='claimed_at'),
  'achievement reward claims have a persisted claimed timestamp'
);

select extensions.ok(
  position('achievement-ready:' in pg_get_functiondef('nexora.unlock_eligible_achievements(text)'::regprocedure)) > 0
  and position('wallets set balance=balance+' in pg_get_functiondef('nexora.unlock_eligible_achievements(text)'::regprocedure)) = 0,
  'newly unlocked achievements notify the player without auto-crediting the reward'
);

select extensions.ok(
  to_regprocedure('nexora.claim_achievement_reward(text,text)') is not null
  and has_function_privilege('service_role','nexora.claim_achievement_reward(text,text)','EXECUTE'),
  'achievement rewards can only be claimed through the trusted server role'
);

select extensions.ok(
  position('claimed_at is not null' in pg_get_functiondef('nexora.claim_achievement_reward(text,text)'::regprocedure)) > 0,
  'achievement claims reject duplicate reward collection'
);

select extensions.ok(
  to_regprocedure('nexora.notify_daily_stipend_ready_for_user(text)') is not null
  and to_regprocedure('nexora.notify_daily_stipend_ready()') is not null,
  'daily operating reward readiness can be checked for one player or all players'
);

select extensions.ok(
  exists(select 1 from pg_trigger where tgrelid='nexora.daily_claims'::regclass
    and tgname='nova_mark_daily_stipend_notification_claimed' and not tgisinternal),
  'claiming the daily stipend clears its readiness notification'
);

select extensions.ok(
  exists(select 1 from pg_class where oid='nexora.organization_chat_messages'::regclass and relrowsecurity),
  'organization chat messages are protected by row-level security'
);

select extensions.ok(
  to_regprocedure('nexora.list_organization_chat_messages(text,text)') is not null
  and to_regprocedure('nexora.send_organization_chat_message(text,text,text,uuid)') is not null,
  'organization chat has server-side read and send operations'
);

select extensions.ok(
  position('organization_members' in pg_get_functiondef('nexora.list_organization_chat_messages(text,text)'::regprocedure)) > 0
  and position('player_profiles' in pg_get_functiondef('nexora.send_organization_chat_message(text,text,text,uuid)'::regprocedure)) > 0,
  'organization chat checks both membership and current profile organization'
);

select extensions.ok(
  has_function_privilege('service_role','nexora.list_organization_chat_messages(text,text)','EXECUTE')
  and has_function_privilege('service_role','nexora.send_organization_chat_message(text,text,text,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','nexora.send_organization_chat_message(text,text,text,uuid)','EXECUTE'),
  'organization chat RPCs are not directly executable by game clients'
);

select extensions.ok(
  to_regprocedure('nexora.emit_notification_once(text,text,text,text,text,text,text)') is not null
  and position('event_key' in pg_get_functiondef('nexora.emit_notification_once(text,text,text,text,text,text,text)'::regprocedure)) > 0,
  'deduplicated notification creation stores the event key on the notification'
);


select extensions.ok(
  position('contract-ready:' in pg_get_functiondef('nexora.claim_dynamic_contract(text,text)'::regprocedure)) > 0
  and position('event_key=' in pg_get_functiondef('nexora.claim_dynamic_contract(text,text)'::regprocedure)) > 0,
  'contract settlement creates and clears the same event-key notification'
);

select extensions.ok(
  exists(select 1 from pg_trigger where tgrelid='nexora.player_missions'::regclass and tgname='nova_mark_mission_reward_notification_claimed' and not tgisinternal)
  and exists(select 1 from pg_trigger where tgrelid='nexora.companies'::regclass and tgname='nova_mark_company_vault_notification_claimed' and not tgisinternal)
  and exists(select 1 from pg_trigger where tgrelid='nexora.factories'::regclass and tgname='nova_mark_factory_warehouse_notification_claimed' and not tgisinternal),
  'mission, company vault and factory warehouse alerts clear when their reward or capacity is handled'
);

select * from extensions.finish();
rollback;
