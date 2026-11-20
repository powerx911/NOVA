-- Run with: supabase test db
-- This suite is intentionally transactional and leaves no fixture rows behind.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(31);

select extensions.ok(
  not exists (select 1 from nexora.wallets where balance < 0),
  'no player wallet has a negative balance'
);

select extensions.is(
  (
    select count(*)::bigint
    from nexora.wallets w
    where w.balance <> 2500 + coalesce((
      select sum(case
        when t.to_uid = w.user_id then t.net_amount
        when t.from_uid = w.user_id then -t.amount
        else 0
      end)
      from nexora.transactions t
      where t.to_uid = w.user_id or t.from_uid = w.user_id
    ), 0)
  ),
  0::bigint,
  'wallet balances reconcile to the immutable transaction ledger'
);

select extensions.throws_ok(
  $$insert into nexora.wallets(user_id, balance) values ('pgtap_negative_wallet', -1)$$,
  '23514',
  null,
  'the database rejects a negative wallet balance'
);

insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values ('pgtap_pause_owner', 2500, 2500, 0);

insert into nexora.factories(
  id, owner_uid, owner_name, name, resource_id, level, skill_level,
  is_active, warehouse_qty, production_remainder, operating_cost_remainder,
  last_produced_at
)
values (
  'pgtap_pause_factory', 'pgtap_pause_owner', 'pgTAP', 'Pause regression factory',
  'copper_wire', 1, 0, true, 0, 0, 0, now() - interval '2 hours'
);

select extensions.throws_ok(
  $$select nexora.set_factory_active('pgtap_pause_owner', 'pgtap_pause_factory', false)$$,
  'P0001',
  'FACTORY_ALWAYS_AUTOMATIC',
  'manual factory shutdown is rejected because operations are automatic'
);

select extensions.lives_ok(
  $$select nexora.sync_factory_production('pgtap_pause_owner', 'pgtap_pause_factory')$$,
  'automatic factory sync processes elapsed production and operating costs'
);

select extensions.is(
  (select is_active from nexora.factories where id = 'pgtap_pause_factory'),
  true,
  'factory remains active while operating funds are available'
);

select extensions.is(
  (select balance from nexora.wallets where user_id = 'pgtap_pause_owner'),
  1500::bigint,
  'two elapsed hours of copper-wire operating costs are charged automatically'
);

select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid = 'pgtap_pause_owner' and type = 'factory_operating'),
  1::bigint,
  'automatic production creates exactly one operating-cost ledger row'
);

select extensions.lives_ok(
  $$select nexora.sync_factory_production('pgtap_pause_owner', 'pgtap_pause_factory')$$,
  'a later automatic sync succeeds without double charging'
);

select extensions.is(
  (select balance from nexora.wallets where user_id = 'pgtap_pause_owner'),
  1500::bigint,
  'syncing again does not charge a second operating cost'
);

select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid = 'pgtap_pause_owner' and type = 'factory_operating'),
  1::bigint,
  'syncing again does not append another operating-cost ledger row'
);


select extensions.ok(
  position('reputation=reputation+round(2*v_leadership)' in lower(pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)))>0
  and position('influence=influence+round(1*v_leadership)' in lower(pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)))>0,
  'company revenue collection grants minimum reputation and influence with leadership scaling'
);

select extensions.ok(
  position('v_xp_gain:=least(80,greatest(10,floor(v_payout/15)::integer))' in lower(pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)))>0
  and position('v_company.total_revenue+v_payout' in lower(pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)))=0,
  'company collection XP has a ten-point minimum and an eighty-point cap based on payout'
);

select extensions.ok(
  position('transfer_level_required' in lower(pg_get_functiondef('nexora.transfer_credits(text,text,bigint,text)'::regprocedure)))>0
  and position('transfer_daily_limit' in lower(pg_get_functiondef('nexora.transfer_credits(text,text,bigint,text)'::regprocedure)))>0,
  'credit transfers enforce level and daily limits'
);

select extensions.ok(
  position('round(p_amount*0.03)' in lower(pg_get_functiondef('nexora.transfer_credits(text,text,bigint,text)'::regprocedure)))>0,
  'credit transfers charge a 3 percent fee'
);

select extensions.ok(
  exists(select 1 from pg_trigger where tgname='company_auction_sale_fee' and not tgisinternal)
  and position('last_tx_id=v_tx' in lower(pg_get_functiondef('nexora.apply_company_auction_sale_fee()'::regprocedure)))>0,
  'company and factory auction sales charge a seller fee'
);

select extensions.ok(
  exists(select 1 from pg_trigger where tgname='company_auction_late_bid_extension' and not tgisinternal),
  'late auction bids extend the auction close'
);


select extensions.ok(
  exists(select 1 from information_schema.columns
    where table_schema='nexora' and table_name='player_missions' and column_name='period_key'),
  'mission claims store a period key'
);

select extensions.ok(
  position('daily_market_buys' in lower(pg_get_functiondef('nexora.claim_mission_reward(text,text)'::regprocedure)))>0
  and position('market_buy' in lower(pg_get_functiondef('nexora.claim_mission_reward(text,text)'::regprocedure)))>0,
  'daily trader progress counts completed market buys in the current period'
);

select extensions.ok(
  position('order by user_id' in lower(pg_get_functiondef('nexora.buy_market_listing(text,text,integer)'::regprocedure)))>0
  and position('xp=' in lower(pg_get_functiondef('nexora.buy_market_listing(text,text,integer)'::regprocedure)))=0
  and position('reputation=reputation+' in lower(pg_get_functiondef('nexora.buy_market_listing(text,text,integer)'::regprocedure)))=0
  and position('influence=influence+' in lower(pg_get_functiondef('nexora.buy_market_listing(text,text,integer)'::regprocedure)))=0,
  'market purchases lock wallets deterministically and grant no XP, reputation, or influence'
);


-- Exercise the auction triggers with isolated fixtures (the surrounding transaction rolls back).
insert into nexora.wallets(user_id,balance,total_earned,total_spent)
values ('pgtap_auction_seller',1000,1000,0);

insert into nexora.company_auctions(
  id,company_name,company_sector,company_level,seller_uid,seller_name,
  starting_price,current_price,highest_bidder_uid,highest_bidder_name,starts_at,ends_at,status
) values (
  'pgtap_sale_fee','pgTAP sale fee','test',50,'pgtap_auction_seller','Seller',
  1000,1000,'pgtap_auction_bidder','Bidder',now()-interval '2 minutes',now()-interval '1 minute','active'
);

update nexora.company_auctions set status='sold',winning_bid=1000
where id='pgtap_sale_fee';

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_auction_seller'),
  960::bigint,
  'auction sale trigger deducts exactly four percent from the seller proceeds'
);

select extensions.ok(
  (select last_tx_id like 'tx_%' from nexora.wallets where user_id='pgtap_auction_seller'),
  'auction seller fee updates the wallet transaction pointer'
);

select extensions.is(
  (select amount from nexora.transactions where reference_id='pgtap_sale_fee' and type='auction_fee'),
  40::bigint,
  'auction seller fee is recorded in the immutable transaction ledger'
);

insert into nexora.company_auctions(
  id,company_name,company_sector,company_level,seller_uid,seller_name,
  starting_price,current_price,ends_at,status
) values (
  'pgtap_anti_sniping','pgTAP anti-sniping','test',50,'pgtap_auction_seller','Seller',
  100,100,now()+interval '2 minutes','active'
);

update nexora.company_auctions
set current_price=101,highest_bidder_uid='pgtap_auction_bidder',highest_bidder_name='Bidder'
where id='pgtap_anti_sniping';

select extensions.ok(
  (select ends_at>now()+interval '4 minutes' and ends_at<=now()+interval '5 minutes'
   from nexora.company_auctions where id='pgtap_anti_sniping'),
  'a bid in the final five minutes extends the auction close to five minutes from now'
);


-- Tiered medal rewards are granted once, atomically with the medal record.
insert into nexora.player_profiles(user_id, username, username_lower, stats)
values ('pgtap_medal_owner', 'pgTAP_Medal', 'pgtap_medal',
  '{"tradesCount":250,"companiesOwned":0,"totalProduced":0}'::jsonb);
insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values ('pgtap_medal_owner', 2500, 2500, 50000);

select nexora.unlock_eligible_achievements('pgtap_medal_owner');

select extensions.ok(
  exists(select 1 from nexora.player_achievements where user_id='pgtap_medal_owner' and achievement_id='nova_whale_i')
  and exists(select 1 from nexora.player_achievements where user_id='pgtap_medal_owner' and achievement_id='nova_market_i')
  and not exists(select 1 from nexora.player_achievements where user_id='pgtap_medal_owner' and achievement_id='nova_whale_ii'),
  'achievement sync awards eligible first-rank medals without skipping unearned higher ranks'
);

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_medal_owner'),
  2500::bigint,
  'unlocking whale and market medals does not pay their rewards before collection'
);

select nexora.claim_achievement_reward('pgtap_medal_owner','nova_whale_i');
select nexora.claim_achievement_reward('pgtap_medal_owner','nova_market_i');

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_medal_owner'),
  6000::bigint,
  'claiming whale and market medals grants their combined 3,500 credit reward'
);

select nexora.unlock_eligible_achievements('pgtap_medal_owner');

select extensions.ok(
  (select balance=6000 from nexora.wallets where user_id='pgtap_medal_owner')
  and (select count(*)=2 from nexora.transactions where to_uid='pgtap_medal_owner' and reference_id in ('nova_whale_i','nova_market_i')),
  'rechecking achievements never duplicates claimed medal rewards or ledger entries'
);


-- Weekly market mission progress is measured from completed purchases in the current ISO week.
insert into nexora.player_profiles(user_id, username, username_lower, stats)
values ('pgtap_weekly_owner', 'pgTAP_Weekly', 'pgtap_weekly',
  '{"tradesCount":0,"companiesOwned":0,"totalProduced":0}'::jsonb);
insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values ('pgtap_weekly_owner', 1000, 1000, 0);
insert into nexora.transactions(
  id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status, created_at
)
select
  'pgtap_weekly_trade_' || trade_no::text,
  'pgtap_weekly_owner',
  'SYSTEM',
  1, 0, 1, 'market_buy',
  'pgtap_weekly_ref_' || trade_no::text,
  'weekly mission fixture',
  'completed',
  date_trunc('week', now() at time zone 'UTC') at time zone 'UTC' + interval '1 hour'
from generate_series(1, 20) as trade_no;

select nexora.claim_mission_reward('pgtap_weekly_owner', 'weekly_market_mogul');

select extensions.ok(
  exists(
    select 1 from nexora.player_missions
    where user_id='pgtap_weekly_owner'
      and mission_id='weekly_market_mogul'
      and category='weekly'
      and period_key=to_char(now() at time zone 'UTC','IYYY-"W"IW')
  ),
  'weekly market mogul records a claim for the current ISO week after 20 completed market buys'
);

select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_weekly_owner'),
  2500::bigint,
  'weekly market mission grants its one-time 1,500 credit reward'
);

select extensions.throws_ok(
  'select nexora.claim_mission_reward(''pgtap_weekly_owner'', ''weekly_market_mogul'')',
  'P0001',
  'MISSION_ALREADY_CLAIMED',
  'weekly market mission cannot be claimed twice in the same week'
);

select * from extensions.finish();
rollback;
