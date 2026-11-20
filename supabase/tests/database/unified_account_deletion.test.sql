-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(15);

insert into nexora.player_profiles(
  user_id,username,username_lower,avatar_id,title,level,xp,reputation,influence,skill_points,skills,stats
) values (
  'pgtap-delete-account','DeleteTester','deletetester','strategist','newcomer',1,0,0,0,0,'{}'::jsonb,'{}'::jsonb
);
insert into nexora.player_private(user_id,email,language,notifications_enabled)
values ('pgtap-delete-account','delete-test@example.invalid','ar',true);
insert into nexora.wallets(user_id,balance,total_earned,total_spent)
values ('pgtap-delete-account',500,1200,700);
insert into nexora.usernames(username_lower,uid,username)
values ('deletetester','pgtap-delete-account','DeleteTester');

insert into nexora.transactions(
  id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status
) values (
  'pgtap-delete-account-tx','pgtap-delete-account','SYSTEM',50,0,50,'transfer','pgtap-ref',
  'Private transfer note that must be redacted','completed'
);
insert into nexora.audit_logs(id,user_id,action,entity_type,entity_id,details)
values ('pgtap-delete-account-audit','pgtap-delete-account','test','player','pgtap-delete-account','{"email":"delete-test@example.invalid"}'::jsonb);

insert into nexora.player_achievements(user_id,achievement_id)
values ('pgtap-delete-account','nova_whale_i');
insert into nexora.player_missions(user_id,mission_id,category,reward_credits,reward_xp,period_key)
values ('pgtap-delete-account','pgtap-mission','daily',0,0,'pgtap-period');
insert into nexora.daily_claims(user_id,date_key,amount)
values ('pgtap-delete-account','2099-01-01',100);
insert into nexora.contract_claims(user_id,contract_id,amount)
values ('pgtap-delete-account','pgtap-contract',50);

insert into nexora.company_auctions(
  id,company_id,company_name,company_sector,company_level,seller_uid,seller_name,
  starting_price,current_price,highest_bidder_uid,highest_bidder_name,ends_at,status,asset_type
) values (
  'pgtap-delete-active-bid',null,'Other Seller Company','tech',1,'pgtap-other-seller','Other Seller',
  100,150,'pgtap-delete-account','DeleteTester',now()+interval '10 minutes','active','company'
);
insert into nexora.company_auction_escrows(auction_id,bidder_uid,amount,status)
values ('pgtap-delete-active-bid','pgtap-delete-account',50,'reserved');

select extensions.throws_ok(
  'select nexora.delete_player_account(''pgtap-delete-account'')',
  'P0001',
  'ACCOUNT_HAS_ACTIVE_AUCTION_BID',
  'account deletion waits for an active winning bid on another player auction'
);
select extensions.is(
  (select count(*)::integer from nexora.player_profiles where user_id='pgtap-delete-account'),
  1,'a blocked account deletion leaves player data intact'
);
update nexora.company_auctions set status='cancelled',settled_at=now() where id='pgtap-delete-active-bid';

select extensions.ok(
  (nexora.delete_player_account('pgtap-delete-account')->>'ok')::boolean,
  'account deletion RPC completes successfully'
);
select extensions.is(
  (select count(*)::integer from nexora.player_profiles where user_id='pgtap-delete-account'),
  0,'player profile is deleted'
);
select extensions.is(
  (select count(*)::integer from nexora.wallets where user_id='pgtap-delete-account'),
  0,'personal wallet is deleted'
);
select extensions.is(
  (select count(*)::integer from nexora.player_private where user_id='pgtap-delete-account'),
  0,'private profile and email are deleted'
);
select extensions.is(
  (select count(*)::integer from nexora.usernames where uid='pgtap-delete-account'),
  0,'username claim is released'
);
select extensions.is(
  (select count(*)::integer from nexora.player_achievements where user_id='pgtap-delete-account')
  + (select count(*)::integer from nexora.player_missions where user_id='pgtap-delete-account')
  + (select count(*)::integer from nexora.daily_claims where user_id='pgtap-delete-account')
  + (select count(*)::integer from nexora.contract_claims where user_id='pgtap-delete-account'),
  0,'personal progression and claim rows are removed'
);
select extensions.is(
  (select count(*)::integer from nexora.transactions where id='pgtap-delete-account-tx'),
  1,'financial transaction history is retained'
);
select extensions.is(
  (select from_uid from nexora.transactions where id='pgtap-delete-account-tx'),
  null::text,'retained transaction is detached from the deleted account'
);
select extensions.is(
  (select description from nexora.transactions where id='pgtap-delete-account-tx'),
  'Historical transaction (anonymized)','retained transaction description is anonymized'
);
select extensions.is(
  (select count(*)::integer from nexora.audit_logs where id='pgtap-delete-account-audit'),
  1,'audit history is retained'
);
select extensions.is(
  (select user_id from nexora.audit_logs where id='pgtap-delete-account-audit'),
  null::text,'audit history no longer identifies the deleted account'
);
select extensions.is(
  (select details from nexora.audit_logs where id='pgtap-delete-account-audit'),
  '{"redacted":"account_deleted"}'::jsonb,'audit details are redacted'
);
select extensions.ok(
  (nexora.delete_player_account('pgtap-delete-account')->>'already_deleted')::boolean,
  'account deletion is safe to retry after a completed database cleanup'
);

select * from extensions.finish();
rollback;
