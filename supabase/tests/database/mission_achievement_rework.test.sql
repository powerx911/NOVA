-- Regression coverage for the redesigned recurring missions and long-term medal tracks.
create extension if not exists pgtap with schema extensions;
begin;
select extensions.plan(14);

insert into nexora.player_profiles(user_id,username,username_lower,stats)
values('pgtap_rework_owner','pgTAP_Rework','pgtap_rework',
  '{"tradesCount":250,"companiesOwned":0,"totalProduced":500}'::jsonb);
insert into nexora.wallets(user_id,balance,total_earned,total_spent)
values('pgtap_rework_owner',102070,102500,50000);

-- Ledger fixtures: 250 market purchases, 180 manufacturing batches, and 100 company collections.
insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status,created_at)
select 'pgtap_rework_market_'||n::text,'pgtap_rework_owner','SYSTEM',1,0,1,'market_buy',
  'pgtap_rework_market_ref_'||n::text,'mission fixture','completed',
  date_trunc('day',now() at time zone 'UTC') at time zone 'UTC'+interval '1 hour'
from generate_series(1,250) n;

insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status,created_at)
select 'pgtap_rework_manufacturing_'||n::text,'pgtap_rework_owner','SYSTEM',1,0,1,'manufacturing',
  'pgtap_rework_recipe_'||n::text,'mission fixture','completed',
  date_trunc('day',now() at time zone 'UTC') at time zone 'UTC'+interval '1 hour'
from generate_series(1,180) n;

insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status,created_at)
select 'pgtap_rework_company_'||n::text,'SYSTEM','pgtap_rework_owner',1000,0,1000,'company_collect',
  'pgtap_rework_company_ref_'||n::text,'mission fixture','completed',
  date_trunc('day',now() at time zone 'UTC') at time zone 'UTC'+interval '1 hour'
from generate_series(1,100) n;

select extensions.is(
  (nexora.get_mission_progress('pgtap_rework_owner')->>'dailyTradesCount')::bigint,
  250::bigint,
  'bootstrap progress RPC returns exact daily purchase count without client-side caps'
);
select extensions.is(
  (nexora.get_mission_progress('pgtap_rework_owner')->>'weeklyManufacturingCount')::bigint,
  180::bigint,
  'bootstrap progress RPC returns exact weekly manufacturing count'
);
select extensions.is(
  (nexora.get_mission_progress('pgtap_rework_owner')->>'seasonalCompanyCollectionsCount')::bigint,
  100::bigint,
  'bootstrap progress RPC returns exact seasonal company collection count'
);
select extensions.is(
  (nexora.get_mission_progress('pgtap_rework_owner')->>'companyRevenueTotal')::bigint,
  100000::bigint,
  'achievement revenue progress aggregates the complete company collection ledger'
);

select nexora.claim_mission_reward('pgtap_rework_owner','daily_market_orders');
select extensions.ok(
  exists(select 1 from nexora.player_missions where user_id='pgtap_rework_owner' and mission_id='daily_market_orders'
    and category='daily' and period_key=to_char(now() at time zone 'UTC','YYYY-MM-DD')),
  'daily market objective records a claim in the current UTC day'
);
select extensions.is((select balance from nexora.wallets where user_id='pgtap_rework_owner'),102770::bigint,
  'daily objective pays the configured 700 credits');
select extensions.throws_ok(
  'select nexora.claim_mission_reward(''pgtap_rework_owner'',''daily_market_orders'')',
  'P0001','MISSION_ALREADY_CLAIMED','daily reward cannot be claimed twice in one day'
);

select nexora.claim_mission_reward('pgtap_rework_owner','weekly_market_network');
select extensions.ok(
  exists(select 1 from nexora.player_missions where user_id='pgtap_rework_owner' and mission_id='weekly_market_network'
    and category='weekly' and period_key=to_char(now() at time zone 'UTC','IYYY-"W"IW')),
  'weekly objective uses the current ISO week'
);

select nexora.claim_mission_reward('pgtap_rework_owner','seasonal_market_leadership');
select extensions.ok(
  exists(select 1 from nexora.player_missions where user_id='pgtap_rework_owner' and mission_id='seasonal_market_leadership'
    and category='seasonal' and period_key=to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text),
  'seasonal objective uses the current UTC quarter'
);

select nexora.claim_mission_reward('pgtap_rework_owner','seasonal_industry_scale');
select extensions.ok(
  exists(select 1 from nexora.player_missions where user_id='pgtap_rework_owner' and mission_id='seasonal_industry_scale'),
  'seasonal manufacturing objective validates completed manufacturing batches'
);

select nexora.unlock_eligible_achievements('pgtap_rework_owner');
select extensions.is(
  (select count(*)::integer from nexora.player_achievements where user_id='pgtap_rework_owner'
    and achievement_id in ('nova_whale_i','nova_market_i','nova_industry_i','nova_enterprise_i')),
  4,
  'new achievement tracks unlock from verified lifetime spending, trades, production and company revenue'
);
select extensions.is((select balance from nexora.wallets where user_id='pgtap_rework_owner'),167470::bigint,
  'achievement rewards are credited exactly with the four eligible first-tier medals');
select extensions.is(
  (nexora.unlock_eligible_achievements('pgtap_rework_owner')->>'new_rewards')::bigint,
  0::bigint,
  'refreshing achievements does not pay previously granted medals again'
);
select extensions.is(
  (select count(*)::integer from nexora.player_achievements where user_id='pgtap_rework_owner'
    and achievement_id like 'medal_%'),
  0,
  'retired bronze/silver/gold/platinum achievement identifiers are not reissued'
);

select * from extensions.finish();
rollback;
