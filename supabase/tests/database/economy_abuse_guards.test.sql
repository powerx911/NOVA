-- Run with: supabase test db
-- This suite is intentionally transactional and leaves no fixture rows behind.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(23);

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

select extensions.lives_ok(
  $$select nexora.set_factory_active('pgtap_pause_owner', 'pgtap_pause_factory', false)$$,
  'pausing an active factory synchronizes its elapsed production first'
);

select extensions.is(
  (select is_active from nexora.factories where id = 'pgtap_pause_factory'),
  false,
  'factory is inactive after the pause RPC'
);

select extensions.is(
  (select balance from nexora.wallets where user_id = 'pgtap_pause_owner'),
  2450::bigint,
  'two elapsed hours of copper-wire operating costs are charged before pausing'
);

select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid = 'pgtap_pause_owner' and type = 'factory_operating'),
  1::bigint,
  'pause creates exactly one operating-cost ledger row'
);

select extensions.lives_ok(
  $$select nexora.sync_factory_production('pgtap_pause_owner', 'pgtap_pause_factory')$$,
  'a later sync of a paused factory succeeds without production'
);

select extensions.is(
  (select balance from nexora.wallets where user_id = 'pgtap_pause_owner'),
  2450::bigint,
  'syncing after pause does not charge a second operating cost'
);

select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid = 'pgtap_pause_owner' and type = 'factory_operating'),
  1::bigint,
  'syncing after pause does not append another operating-cost ledger row'
);


select extensions.ok(
  position('reputation=reputation+' in lower(pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)))=0
  and position('influence=influence+' in lower(pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)))=0,
  'company revenue collection grants no reputation or influence'
);

select extensions.ok(
  position('v_company.total_revenue+v_payout' in lower(pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)))>0,
  'company collection XP scales with actual collected revenue'
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
  position('daily_trades' in lower(pg_get_functiondef('nexora.claim_mission_reward(text,text)'::regprocedure)))>0
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
  starting_price,current_price,highest_bidder_uid,highest_bidder_name,ends_at,status
) values (
  'pgtap_sale_fee','pgTAP sale fee','test',1,'pgtap_auction_seller','Seller',
  1000,1000,'pgtap_auction_bidder','Bidder',now()-interval '1 minute','active'
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
  'pgtap_anti_sniping','pgTAP anti-sniping','test',1,'pgtap_auction_seller','Seller',
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

select * from extensions.finish();
rollback;
