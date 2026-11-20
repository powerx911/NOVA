-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(9);

select extensions.throws_ok(
  $$select nexora.withdraw_org_treasury('pgtap-user','pgtap-org',1)$$,
  'P0001',
  'ORG_TREASURY_WITHDRAWALS_DISABLED',
  'organization treasury withdrawals are rejected for every role'
);

insert into nexora.wallets(user_id,balance,total_spent,total_earned)
values
  ('pgtap-company-auction-bidder',500,200,0),
  ('pgtap-factory-auction-bidder',700,300,0);

insert into nexora.company_auctions(
  id,company_id,company_name,company_sector,company_level,seller_uid,seller_name,
  starting_price,current_price,highest_bidder_uid,highest_bidder_name,starts_at,ends_at,status,asset_type
) values
  ('pgtap-missing-company-auction',null,'Missing Company','tech',50,'pgtap-company-seller','Seller',
   100,200,'pgtap-company-auction-bidder','Bidder',now()-interval '2 minutes',now()-interval '1 minute','active','company'),
  ('pgtap-missing-factory-auction',null,'Missing Factory','tech',50,'pgtap-factory-seller','Seller',
   100,300,'pgtap-factory-auction-bidder','Bidder',now()-interval '2 minutes',now()-interval '1 minute','active','factory');

insert into nexora.company_auction_escrows(auction_id,bidder_uid,amount,status)
values
  ('pgtap-missing-company-auction','pgtap-company-auction-bidder',200,'reserved'),
  ('pgtap-missing-factory-auction','pgtap-factory-auction-bidder',300,'reserved');

select nexora.settle_company_auction('pgtap-missing-company-auction');
select extensions.is(
  (select status from nexora.company_auctions where id='pgtap-missing-company-auction'),
  'cancelled','missing-company auction is cancelled'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap-company-auction-bidder'),
  700::bigint,'missing-company auction returns the full reserved amount'
);
select extensions.is(
  (select status from nexora.company_auction_escrows where auction_id='pgtap-missing-company-auction'),
  'refunded','missing-company escrow is marked refunded'
);
select extensions.is(
  (select count(*) from nexora.transactions where reference_id='pgtap-missing-company-auction' and type='company_auction_refund'),
  1::bigint,'missing-company refund is recorded exactly once'
);

select nexora.settle_factory_auction('pgtap-missing-factory-auction');
select extensions.is(
  (select status from nexora.company_auctions where id='pgtap-missing-factory-auction'),
  'cancelled','missing-factory auction is cancelled'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap-factory-auction-bidder'),
  1000::bigint,'missing-factory auction returns the full reserved amount'
);
select extensions.is(
  (select status from nexora.company_auction_escrows where auction_id='pgtap-missing-factory-auction'),
  'refunded','missing-factory escrow is marked refunded'
);
select extensions.is(
  (select count(*) from nexora.transactions where reference_id='pgtap-missing-factory-auction' and type='factory_auction_refund'),
  1::bigint,'missing-factory refund is recorded exactly once'
);

select * from extensions.finish();
rollback;
