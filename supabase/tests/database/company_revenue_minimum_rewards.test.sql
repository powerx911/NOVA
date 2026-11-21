-- Verify collection rewards are proportional to the actual company payout.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(20);

create temporary table company_reward_results (
  result_id text primary key,
  payload jsonb not null
);

insert into nexora.player_profiles(user_id, username, username_lower, xp, level, skills, stats)
values
  ('pgtap_company_reward_base', 'pgtap_reward_base', 'pgtap_reward_base', 0, 1, '{"leadership":0}'::jsonb, '{}'::jsonb),
  ('pgtap_company_reward_leader', 'pgtap_reward_leader', 'pgtap_reward_leader', 0, 1, '{"leadership":5}'::jsonb, '{}'::jsonb),
  ('pgtap_company_reward_cap', 'pgtap_reward_cap', 'pgtap_reward_cap', 190, 1, '{"leadership":0}'::jsonb, '{}'::jsonb);

insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values
  ('pgtap_company_reward_base', 0, 0, 0),
  ('pgtap_company_reward_leader', 0, 0, 0),
  ('pgtap_company_reward_cap', 0, 0, 0);

insert into nexora.companies(id, owner_uid, owner_name, name, sector, base_revenue_per_hour, expense_per_hour, total_revenue, vault_level, vault_balance)
values
  ('pgtap_company_reward_base', 'pgtap_company_reward_base', 'pgTAP Company Reward Base', 'pgTAP Reward Base', 'trade', 100, 0, 0, 1, 1),
  ('pgtap_company_reward_leader', 'pgtap_company_reward_leader', 'pgTAP Company Reward Leader', 'pgTAP Reward Leader', 'trade', 100, 0, 0, 1, 15),
  ('pgtap_company_reward_cap', 'pgtap_company_reward_cap', 'pgTAP Company Reward Cap', 'pgTAP Reward Cap', 'trade', 100, 0, 0, 1, 3500);

select extensions.lives_ok(
  $$insert into company_reward_results values ('base', nexora.collect_company_revenue('pgtap_company_reward_base', 'pgtap_company_reward_base'))$$,
  'a small company payout can be collected'
);

select extensions.is((select (payload->>'payout')::bigint from company_reward_results where result_id='base'), 1::bigint, 'the base test collects one credit');
select extensions.is((select xp from nexora.player_profiles where user_id='pgtap_company_reward_base'), 0::bigint, 'a one-credit collection below fifteen credits grants no XP');
select extensions.is((select reputation from nexora.player_profiles where user_id='pgtap_company_reward_base'), 0::bigint, 'company collection does not grant reputation per request');
select extensions.is((select influence from nexora.player_profiles where user_id='pgtap_company_reward_base'), 0::bigint, 'company collection does not grant influence per request');
select extensions.is((select balance from nexora.wallets where user_id='pgtap_company_reward_base'), 1::bigint, 'the collected payout reaches the wallet');
select extensions.is((select total_revenue from nexora.companies where id='pgtap_company_reward_base'), 1::bigint, 'collected revenue is recorded on the company');
select extensions.is((select vault_balance from nexora.companies where id='pgtap_company_reward_base'), 0::bigint, 'the company vault is cleared after collection');

select extensions.lives_ok(
  $lead$insert into company_reward_results values ('leader', nexora.collect_company_revenue('pgtap_company_reward_leader', 'pgtap_company_reward_leader'))$lead$,
  'a player with leadership skill can collect company revenue'
);
select extensions.is((select xp from nexora.player_profiles where user_id='pgtap_company_reward_leader'), 1::bigint, 'a fifteen-credit payout grants exactly one XP');

select extensions.is((select reputation from nexora.player_profiles where user_id='pgtap_company_reward_leader'), 0::bigint, 'leadership does not multiply a per-collection reputation reward');
select extensions.is((select influence from nexora.player_profiles where user_id='pgtap_company_reward_leader'), 0::bigint, 'leadership does not multiply a per-collection influence reward');

select extensions.lives_ok(
  $$insert into company_reward_results values ('cap', nexora.collect_company_revenue('pgtap_company_reward_cap', 'pgtap_company_reward_cap'))$$,
  'a full company vault can be collected'
);
select extensions.is((select xp from nexora.player_profiles where user_id='pgtap_company_reward_cap'), 270::bigint, 'capped XP is added to the existing XP total');
select extensions.is((select level from nexora.player_profiles where user_id='pgtap_company_reward_cap'), 2, 'collection XP can advance the player level');
select extensions.is((select skill_points from nexora.player_profiles where user_id='pgtap_company_reward_cap'), 1, 'the profile trigger grants one skill point for the level gained');
select extensions.is((select reputation from nexora.player_profiles where user_id='pgtap_company_reward_cap'), 0::bigint, 'a large collection still grants no per-call reputation');
select extensions.is((select influence from nexora.player_profiles where user_id='pgtap_company_reward_cap'), 0::bigint, 'a large collection still grants no per-call influence');
select extensions.is((select balance from nexora.wallets where user_id='pgtap_company_reward_cap'), 3500::bigint, 'the full vault payout reaches the wallet');
select extensions.is((select count(*) from nexora.transactions where to_uid='pgtap_company_reward_base' and type='company_collect'), 1::bigint, 'the base collection creates one financial transaction');

select * from extensions.finish();
rollback;
