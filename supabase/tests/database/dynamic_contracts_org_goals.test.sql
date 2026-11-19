-- Run with: supabase test db
-- Dynamic contract lifecycle, limits, event rotation, and organization goal invariants.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(79);

select extensions.ok(
  exists(select 1 from nexora.contract_config where config_key='catalog_prices'),
  'contract prices are stored in editable contract_config'
);
select extensions.is(
  (select (config_value->'copper_wire'->>'price')::integer from nexora.contract_config where config_key='catalog_prices'),
  28,
  'copper wire base price matches the approved catalog'
);
select extensions.is(
  (select (config_value->>'uncommon_level')::integer from nexora.contract_config where config_key='progression'),
  3,
  'uncommon contracts unlock at level three'
);
select extensions.is(
  (select (config_value->>'rare_level')::integer from nexora.contract_config where config_key='progression'),
  8,
  'rare contracts unlock at level eight'
);
select extensions.is(
  (select (config_value->'common'->>'multiplier')::numeric from nexora.contract_config where config_key='tier_rules'),
  1.12::numeric,
  'common contract multiplier matches the approved economy'
);
select extensions.is(
  (select (config_value->'6-8'->>'epic')::integer from nexora.contract_config where config_key='org_tier_weights'),
  10,
  'organization level six to eight epic weight is ten percent'
);
select extensions.ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='nexora' and c.relname='contract_offers'),
  'contract offers has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='nexora' and c.relname='org_weekly_goals'),
  'organization weekly goals has RLS enabled'
);
select extensions.ok(
  not has_table_privilege('anon','nexora.contract_offers','SELECT')
  and not has_table_privilege('authenticated','nexora.contract_offers','SELECT')
  and not has_table_privilege('anon','nexora.contract_config','UPDATE')
  and not has_table_privilege('authenticated','nexora.contract_config','UPDATE'),
  'anonymous and authenticated roles have no direct contract table access'
);
select extensions.ok(
  (select prosecdef from pg_proc where oid='nexora.accept_dynamic_contract(text,text)'::regprocedure),
  'contract RPCs execute as SECURITY DEFINER'
);
select extensions.ok(
  (select proconfig @> array['search_path=""'] from pg_proc
   where oid='nexora.accept_dynamic_contract(text,text)'::regprocedure),
  'contract RPC search_path is fixed'
);
select extensions.ok(
  not has_function_privilege('anon','nexora.accept_dynamic_contract(text,text)','EXECUTE')
  and not has_function_privilege('authenticated','nexora.accept_dynamic_contract(text,text)','EXECUTE'),
  'contract RPC execute is revoked from anon and authenticated'
);

insert into nexora.player_profiles(user_id,username,username_lower,level)
values ('pgtap_active','Active Test','pgtap_active',8);
insert into nexora.wallets(user_id,balance) values ('pgtap_active',2500);
insert into nexora.player_private(user_id,language,notifications_enabled)
values ('pgtap_active','en',true);
select extensions.lives_ok(
  $$select nexora.get_dynamic_contract_board('pgtap_active')$$,
  'personal contract board is generated'
);
select extensions.is(
  (select count(*)::integer from nexora.contract_offers
   where scope='personal' and user_id='pgtap_active' and board_date=(now() at time zone 'UTC')::date
     and slot_no between 1 and 6 and status in ('offered','accepted','processing','ready')),
  6,
  'personal board contains six standard offers'
);
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_active',(select id from nexora.contract_offers where user_id='pgtap_active' and status='offered' and slot_no=1 order by slot_generation desc limit 1))$$,
  'first personal contract can be accepted'
);
select extensions.ok(
  exists(select 1 from nexora.contract_offers accepted
    join nexora.contract_offers replacement on replacement.user_id=accepted.user_id
      and replacement.scope=accepted.scope and replacement.board_date=accepted.board_date
      and replacement.slot_no=accepted.slot_no and replacement.slot_generation>accepted.slot_generation
    where accepted.user_id='pgtap_active' and accepted.slot_no=1 and accepted.status='accepted'
      and replacement.status='offered'
      and (replacement.item_id<>accepted.item_id or replacement.tier<>accepted.tier)),
  'personal slot is immediately refilled with a different offer after acceptance'
);
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_active',(select id from nexora.contract_offers where user_id='pgtap_active' and status='offered' and slot_no=2 order by slot_generation desc limit 1))$$,
  'second personal contract can be accepted'
);
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_active',(select id from nexora.contract_offers where user_id='pgtap_active' and status='offered' and slot_no=3 order by slot_generation desc limit 1))$$,
  'third personal contract can be accepted'
);
select extensions.throws_ok(
  $$select nexora.accept_dynamic_contract('pgtap_active',(select id from nexora.contract_offers where user_id='pgtap_active' and status='offered' and slot_no=4 order by slot_generation desc limit 1))$$,
  'P0001','ACTIVE_CONTRACT_LIMIT',
  'a fourth active personal contract is rejected'
);

insert into nexora.player_profiles(user_id,username,username_lower,level)
values ('pgtap_daily','Daily Test','pgtap_daily',1);
insert into nexora.wallets(user_id,balance) values ('pgtap_daily',2500);
select extensions.lives_ok(
  $$select nexora.get_dynamic_contract_board('pgtap_daily')$$,
  'daily-limit fixture receives a board'
);
select extensions.lives_ok(
  $query$do $body$
    declare v_id text;
    begin
      for i in 1..5 loop
        select id into v_id from nexora.contract_offers
          where scope='personal' and user_id='pgtap_daily' and status='offered'
            and board_date=(now() at time zone 'UTC')::date
          order by slot_no limit 1;
        perform nexora.accept_dynamic_contract('pgtap_daily',v_id);
        perform nexora.abandon_dynamic_contract('pgtap_daily',v_id);
      end loop;
    end;
  $body$$query$,
  'five daily acceptances remain consumed even after abandonment'
);
select extensions.is(
  (select used_count from nexora.contract_daily_limits
   where user_id='pgtap_daily' and date_key=(now() at time zone 'UTC')::date),
  5,
  'personal and organization contract attempts share a five-per-day counter'
);
select extensions.throws_ok(
  $$select nexora.accept_dynamic_contract('pgtap_daily',(select id from nexora.contract_offers where user_id='pgtap_daily' and status='offered' order by slot_no limit 1))$$,
  'P0001','DAILY_CONTRACT_LIMIT_REACHED',
  'a sixth daily contract acceptance is rejected'
);
select extensions.ok(
  exists(
    select 1 from nexora.contract_offers old
    join nexora.contract_offers replacement
      on replacement.scope=old.scope and replacement.user_id=old.user_id
      and replacement.board_date=old.board_date and replacement.slot_no=old.slot_no
      and replacement.slot_generation>old.slot_generation
    where old.user_id='pgtap_daily' and old.status='abandoned'
      and replacement.status='offered'
      and (replacement.item_id<>old.item_id or replacement.tier<>old.tier)
  ),
  'a replacement offer differs by item or tier'
);

insert into nexora.player_profiles(user_id,username,username_lower,level)
values ('pgtap_deliver','Deliver Test','pgtap_deliver',1);
insert into nexora.wallets(user_id,balance) values ('pgtap_deliver',2500);
insert into nexora.player_private(user_id,language,notifications_enabled)
values ('pgtap_deliver','en',true);
select extensions.lives_ok($$select nexora.get_dynamic_contract_board('pgtap_deliver')$$,'delivery fixture receives offers');
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_deliver',(select id from nexora.contract_offers where user_id='pgtap_deliver' and status='offered' order by slot_no limit 1))$$,
  'delivery contract is accepted'
);
insert into nexora.inventory(user_id,item_id,quantity)
select 'pgtap_deliver',item_id,100 from nexora.contract_offers
where id=(select id from nexora.contract_offers where user_id='pgtap_deliver' and status='accepted' limit 1)
on conflict(user_id,item_id) do update set quantity=100;
select extensions.lives_ok(
  $$select nexora.deliver_dynamic_contract('pgtap_deliver',(select id from nexora.contract_offers where user_id='pgtap_deliver' and status='accepted' limit 1))$$,
  'delivery consumes materials and starts processing'
);
select extensions.ok(
  exists(select 1 from nexora.contract_offers where user_id='pgtap_deliver' and status='processing'
    and deadline_at is null and deadline_remaining_secs>0 and ready_at>now()),
  'delivery freezes the deadline and sets ready_at'
);
select extensions.is(
  (select count(*)::integer from nexora.transactions
   where from_uid='pgtap_deliver' and type='contract_fee'),
  1,
  'delivery fee is written to the immutable transaction ledger'
);
select extensions.throws_ok(
  $$select nexora.claim_dynamic_contract('pgtap_deliver',(select id from nexora.contract_offers where user_id='pgtap_deliver' and status='processing' limit 1))$$,
  'P0001','CONTRACT_NOT_READY',
  'reward cannot be claimed before ready_at'
);
select extensions.throws_ok(
  $$select nexora.abandon_dynamic_contract('pgtap_deliver',(select id from nexora.contract_offers where user_id='pgtap_deliver' and status='processing' limit 1))$$,
  'P0001','CONTRACT_CANNOT_BE_ABANDONED',
  'a delivered contract cannot be abandoned'
);

insert into nexora.player_profiles(user_id,username,username_lower,level)
values ('pgtap_no_funds','No Funds','pgtap_no_funds',1);
insert into nexora.wallets(user_id,balance) values ('pgtap_no_funds',0);
select extensions.lives_ok($$select nexora.get_dynamic_contract_board('pgtap_no_funds')$$,'zero-balance fixture receives offers');
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_no_funds',(select id from nexora.contract_offers where user_id='pgtap_no_funds' and status='offered' order by slot_no limit 1))$$,
  'zero-balance fixture can accept without paying a fee yet'
);
insert into nexora.inventory(user_id,item_id,quantity)
select 'pgtap_no_funds',item_id,100 from nexora.contract_offers
where id=(select id from nexora.contract_offers where user_id='pgtap_no_funds' and status='accepted' limit 1)
on conflict(user_id,item_id) do update set quantity=100;
select extensions.throws_ok(
  $$select nexora.deliver_dynamic_contract('pgtap_no_funds',(select id from nexora.contract_offers where user_id='pgtap_no_funds' and status='accepted' limit 1))$$,
  'P0001','INSUFFICIENT_FUNDS',
  'delivery is rejected when the fee cannot be paid'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_no_funds'),
  0::bigint,
  'contract fees never make a wallet negative'
);

insert into nexora.player_profiles(user_id,username,username_lower,level)
values ('pgtap_expiry','Expiry Test','pgtap_expiry',1);
insert into nexora.wallets(user_id,balance) values ('pgtap_expiry',2500);
insert into nexora.player_private(user_id,language,notifications_enabled)
values ('pgtap_expiry','en',true);
select extensions.lives_ok($select nexora.get_dynamic_contract_board('pgtap_expiry')$,'expiry fixture receives offers');
select extensions.is((select count(*)::integer from nexora.contract_offers where user_id='pgtap_expiry' and scope='personal' and board_date=(now() at time zone 'UTC')::date and status='offered'),5,'personal board exposes five offers');
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_expiry',(select id from nexora.contract_offers where user_id='pgtap_expiry' and status='offered' order by slot_no limit 1))$$,
  'expiry fixture accepts a contract'
);
update nexora.contract_offers set deadline_at=now()-interval '1 second'
where id=(select id from nexora.contract_offers where user_id='pgtap_expiry' and status='accepted' limit 1);
select extensions.lives_ok($$select nexora.get_dynamic_contract_board('pgtap_expiry')$$,'board RPC lazily settles expired contracts');
select extensions.is(
  (select count(*)::integer from nexora.contract_offers old join nexora.contract_offers fresh
    on fresh.user_id=old.user_id and fresh.scope=old.scope and fresh.slot_no=old.slot_no
      and fresh.board_date=old.board_date and fresh.slot_generation>old.slot_generation
    where old.user_id='pgtap_expiry' and old.status='expired' and fresh.status='offered'),
  0,
  'expired contract slot stays empty during its server-side cooldown'
);
select extensions.ok(
  exists(select 1 from nexora.contract_slot_cooldowns
    where scope='personal' and owner_id='pgtap_expiry' and slot_no=(
      select slot_no from nexora.contract_offers where user_id='pgtap_expiry' and status='expired' order by updated_at desc limit 1
    ) and cooldown_until>now()),
  'each expired slot receives its own fifteen-minute cooldown'
);
update nexora.contract_slot_cooldowns set cooldown_until=now()-interval '1 second'
where scope='personal' and owner_id='pgtap_expiry';
select extensions.lives_ok($select nexora.get_dynamic_contract_board('pgtap_expiry')$,
  'expired cooldown is cleared on the next board refresh');
select extensions.ok(
  exists(select 1 from nexora.contract_offers old join nexora.contract_offers fresh
    on fresh.user_id=old.user_id and fresh.scope=old.scope and fresh.slot_no=old.slot_no
      and fresh.board_date=old.board_date and fresh.slot_generation>old.slot_generation
    where old.user_id='pgtap_expiry' and old.status='expired' and fresh.status='offered'),
  'the same slot is refilled after fifteen minutes elapse'
);
select extensions.ok(
  exists(select 1 from nexora.notifications where user_id='pgtap_expiry' and title='Contract expired'),
  'expiration notification respects enabled player notifications'
);

insert into nexora.player_profiles(user_id,username,username_lower,level)
values ('pgtap_event','Event Test','pgtap_event',1);
insert into nexora.wallets(user_id,balance) values ('pgtap_event',2500);
insert into nexora.player_private(user_id,language,notifications_enabled)
values ('pgtap_event','en',true);
insert into nexora.world_events(id,title_ar,title_en,description_ar,description_en,effect_type,target_item_id,price_multiplier,starts_at,ends_at,active)
values ('pgtap_event_market','حدث اختبار','Test Event','وصف','Description','demand_surge','copper_wire',1.5,now()-interval '1 minute',now()+interval '1 hour',true);
select extensions.lives_ok($$select nexora.get_dynamic_contract_board('pgtap_event')$$,'active event is included during board generation');
select extensions.ok(
  exists(select 1 from nexora.contract_offers where user_id='pgtap_event' and event_id='pgtap_event_market'
    and status='offered' and event_premium>0),
  'active targeted event produces a premium offer'
);
select extensions.ok(
  (select count(*) between 1 and 2 from nexora.contract_offers
   where user_id='pgtap_event' and event_id='pgtap_event_market' and status='offered'),
  'each active event creates one or two offers'
);
update nexora.world_events set ends_at=now()-interval '1 second' where id='pgtap_event_market';
select extensions.lives_ok($$select nexora.get_dynamic_contract_board('pgtap_event')$$,'board refresh settles inactive event offers');
select extensions.is(
  (select count(*)::integer from nexora.contract_offers
   where user_id='pgtap_event' and event_id='pgtap_event_market' and status='offered'),
  0,
  'event offers disappear when their world event ends'
);

insert into nexora.organizations(id,name,tag,leader_uid,leader_name,level,member_count,reputation)
values ('pgtap_org','Contract Org','PCO','pgtap_org_user','Org User',1,1,0);
insert into nexora.player_profiles(user_id,username,username_lower,level,org_id)
values ('pgtap_org_user','Org User','pgtap_org_user',1,'pgtap_org');
insert into nexora.wallets(user_id,balance) values ('pgtap_org_user',2500);
insert into nexora.player_private(user_id,language,notifications_enabled)
values ('pgtap_org_user','en',true);
insert into nexora.organization_members(org_id,user_id,username,role,joined_at)
values ('pgtap_org','pgtap_org_user','Org User','leader',now()-interval '7 hours');
select extensions.lives_ok($select nexora.get_dynamic_contract_board('pgtap_org_user')$,'organization board is generated');
select extensions.is((select count(*)::integer from nexora.contract_offers where org_id='pgtap_org' and scope='organization' and board_date=(now() at time zone 'UTC')::date and status='offered'),10,'level one organization board exposes ten offers');
select extensions.throws_ok(
  $$select nexora.accept_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$$,
  'P0001','ORG_MEMBERSHIP_TOO_NEW',
  'organization contracts require eight hours of membership'
);
update nexora.organization_members set joined_at=now()-interval '9 hours'
where org_id='pgtap_org' and user_id='pgtap_org_user';
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='personal' and user_id='pgtap_org_user' and status='offered' and slot_no=1 order by slot_generation desc limit 1))$$,
  'organization member can also accept a personal contract'
);
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$$,
  'eligible member can reserve an organization contract'
);
select extensions.throws_ok(
  $$select nexora.accept_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$$,
  'P0001','ORG_ACTIVE_CONTRACT_LIMIT',
  'one member cannot reserve two active organization contracts'
);
select extensions.is(
  (select used_count from nexora.contract_daily_limits where user_id='pgtap_org_user' and date_key=(now() at time zone 'UTC')::date),
  2,
  'combined contract acceptance count remains available for audit'
);
select extensions.is(
  (select personal_used_count from nexora.contract_daily_limits where user_id='pgtap_org_user' and date_key=(now() at time zone 'UTC')::date),
  1,
  'personal acceptance consumes only the personal daily quota'
);
select extensions.is(
  (select org_used_count from nexora.contract_daily_limits where user_id='pgtap_org_user' and date_key=(now() at time zone 'UTC')::date),
  1,
  'organization acceptance consumes only the organization daily quota'
);
insert into nexora.inventory(user_id,item_id,quantity)
select 'pgtap_org_user',item_id,100 from nexora.contract_offers
where id=(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='accepted' limit 1)
on conflict(user_id,item_id) do update set quantity=100;
select extensions.lives_ok(
  $$select nexora.deliver_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='accepted' limit 1))$$,
  'reserved organization contract can be delivered'
);
update nexora.contract_offers set ready_at=now()-interval '1 second'
where scope='organization' and org_id='pgtap_org' and status='processing';
select extensions.lives_ok(
  $$select nexora.claim_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='processing' limit 1))$$,
  'organization contract reward can be claimed after processing'
);
select extensions.ok(
  exists(select 1 from nexora.notifications where user_id='pgtap_org_user' and title='Contract ready to claim'),
  'ready notification respects enabled player notifications'
);
select extensions.is(
  (select reputation from nexora.organizations where id='pgtap_org'),
  (select org_reputation_reward from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='completed' order by completed_at desc limit 1)::bigint,
  'organization reputation is granted from the contract tier once'
);
select extensions.throws_ok(
  $$select nexora.claim_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='completed' order by completed_at desc limit 1))$$,
  'P0001','CONTRACT_NOT_CLAIMABLE',
  'the same organization contract cannot be claimed twice'
);

insert into nexora.organizations(id,name,tag,leader_uid,leader_name,level,member_count,reputation)
values ('pgtap_goal_org','Goal Org','PGO','pgtap_goal_user','Goal User',2,1,0);
insert into nexora.player_profiles(user_id,username,username_lower,level,org_id)
values ('pgtap_goal_user','Goal User','pgtap_goal_user',1,'pgtap_goal_org');
insert into nexora.organization_members(org_id,user_id,username,role,joined_at)
values ('pgtap_goal_org','pgtap_goal_user','Goal User','leader',now()-interval '30 days');
select extensions.lives_ok($$select nexora.get_org_weekly_goals('pgtap_goal_user')$$,'ISO weekly organization goals are generated lazily');
select extensions.is(
  (select count(*)::integer from nexora.org_weekly_goals
   where org_id='pgtap_goal_org' and week_start=date_trunc('week',timezone('UTC',now()))::date),
  10,
  'ten distinct goals are generated for the UTC ISO week'
);
select extensions.lives_ok(
  $query$do $body$
    declare v_goal nexora.org_weekly_goals%rowtype;
    begin
      select * into v_goal from nexora.org_weekly_goals
        where org_id='pgtap_goal_org' and week_start=date_trunc('week',timezone('UTC',now()))::date
        order by id limit 1;
      perform nexora.record_org_goal_progress('pgtap_goal_user',v_goal.goal_type,v_goal.target_amount+1);
      perform nexora.record_org_goal_progress('pgtap_goal_user',v_goal.goal_type,v_goal.target_amount+1);
    end;
  $body$$query$,
  'goal progress is recorded and repeated completion remains idempotent'
);
select extensions.is(
  (select reputation from nexora.organizations where id='pgtap_goal_org'),
  (select reward_reputation from nexora.org_weekly_goals
   where org_id='pgtap_goal_org' and status='completed' order by completed_at desc limit 1),
  'organization goal reputation is awarded once only'
);
select extensions.ok(
  exists(select 1 from nexora.org_goal_contributions c
    join nexora.org_weekly_goals g on g.id=c.goal_id
    where c.org_id='pgtap_goal_org' and c.user_id='pgtap_goal_user' and g.status='completed'),
  'completed goals retain per-member contribution records'
);


select extensions.lives_ok(
  $select nexora.refresh_dynamic_contract('pgtap_expiry',(select id from nexora.contract_offers where user_id='pgtap_expiry' and scope='personal' and status='offered' order by slot_no limit 1))$,
  'a player can refresh a personal offer'
);
select extensions.lives_ok(
  $select nexora.refresh_dynamic_contract('pgtap_expiry',(select id from nexora.contract_offers where user_id='pgtap_expiry' and scope='personal' and status='offered' order by slot_no limit 1))$,
  'a second independent personal slot can be refreshed'
);
select extensions.lives_ok(
  $select nexora.refresh_dynamic_contract('pgtap_expiry',(select id from nexora.contract_offers where user_id='pgtap_expiry' and scope='personal' and status='offered' order by slot_no limit 1))$,
  'a third personal refresh is allowed in the UTC day'
);
select extensions.throws_ok(
  $select nexora.refresh_dynamic_contract('pgtap_expiry',(select id from nexora.contract_offers where user_id='pgtap_expiry' and scope='personal' and status='offered' order by slot_no limit 1))$,
  'P0001','CONTRACT_REFRESH_LIMIT_REACHED',
  'personal refresh allowance stops at three per UTC day'
);
select extensions.is(
  (select used_count from nexora.contract_slot_refresh_usage where scope='personal' and owner_id='pgtap_expiry' and date_key=(now() at time zone 'UTC')::date),
  3,
  'personal refresh usage is tracked independently'
);

select extensions.lives_ok(
  $select nexora.refresh_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$,
  'organization leader can refresh a shared organization offer'
);
select extensions.lives_ok(
  $select nexora.refresh_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$,
  'organization refresh allowance permits a second refresh'
);
select extensions.lives_ok(
  $select nexora.refresh_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$,
  'organization refresh allowance permits a third refresh'
);
select extensions.lives_ok(
  $select nexora.refresh_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$,
  'organization refresh allowance permits a fourth refresh'
);
select extensions.lives_ok(
  $select nexora.refresh_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$,
  'organization refresh allowance permits five refreshes per UTC day'
);
select extensions.throws_ok(
  $select nexora.refresh_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$,
  'P0001','CONTRACT_REFRESH_LIMIT_REACHED',
  'organization refresh allowance stops at five per UTC day'
);

select * from extensions.finish();
rollback;
