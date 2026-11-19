-- Run with: supabase test db
-- Dynamic contract lifecycle, limits, event rotation, and organization goal invariants.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(34);

select extensions.ok(
  exists(select 1 from nexora.contract_config where config_key='catalog_prices'),
  'contract prices are stored in editable contract_config'
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
  $$do $body$
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
  $body$$,
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
select extensions.lives_ok($$select nexora.get_dynamic_contract_board('pgtap_expiry')$$,'expiry fixture receives offers');
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_expiry',(select id from nexora.contract_offers where user_id='pgtap_expiry' and status='offered' order by slot_no limit 1))$$,
  'expiry fixture accepts a contract'
);
update nexora.contract_offers set deadline_at=now()-interval '1 second'
where id=(select id from nexora.contract_offers where user_id='pgtap_expiry' and status='accepted' limit 1);
select extensions.lives_ok($$select nexora.get_dynamic_contract_board('pgtap_expiry')$$,'board RPC lazily settles expired contracts');
select extensions.ok(
  exists(select 1 from nexora.contract_offers old join nexora.contract_offers fresh
    on fresh.user_id=old.user_id and fresh.scope=old.scope and fresh.slot_no=old.slot_no
      and fresh.board_date=old.board_date and fresh.slot_generation>old.slot_generation
    where old.user_id='pgtap_expiry' and old.status='expired' and fresh.status='offered'
      and (fresh.item_id<>old.item_id or fresh.tier<>old.tier)),
  'lazy expiry rotates the expired slot to a different offer'
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
update nexora.world_events set active=false where id='pgtap_event_market';
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
select extensions.lives_ok($$select nexora.get_dynamic_contract_board('pgtap_org_user')$$,'organization board is generated');
select extensions.throws_ok(
  $$select nexora.accept_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$$,
  'P0001','ORG_MEMBERSHIP_TOO_NEW',
  'organization contracts require eight hours of membership'
);
update nexora.organization_members set joined_at=now()-interval '9 hours'
where org_id='pgtap_org' and user_id='pgtap_org_user';
select extensions.lives_ok(
  $$select nexora.accept_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$$,
  'eligible member can reserve an organization contract'
);
select extensions.throws_ok(
  $$select nexora.accept_dynamic_contract('pgtap_org_user',(select id from nexora.contract_offers where scope='organization' and org_id='pgtap_org' and status='offered' order by slot_no limit 1))$$,
  'P0001','ORG_ACTIVE_CONTRACT_LIMIT',
  'one member cannot reserve two active organization contracts'
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
  3,
  'three distinct goals are generated for the UTC ISO week'
);
select extensions.lives_ok(
  $$do $body$
    declare v_goal nexora.org_weekly_goals%rowtype;
    begin
      select * into v_goal from nexora.org_weekly_goals
        where org_id='pgtap_goal_org' and week_start=date_trunc('week',timezone('UTC',now()))::date
        order by id limit 1;
      perform nexora.record_org_goal_progress('pgtap_goal_user',v_goal.goal_type,v_goal.target_amount+1);
      perform nexora.record_org_goal_progress('pgtap_goal_user',v_goal.goal_type,v_goal.target_amount+1);
    end;
  $body$$,
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

select * from extensions.finish();
rollback;
