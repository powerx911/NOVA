-- Cover the market foreign keys used for seller history, order joins, and inventory audit lookups.
create index if not exists nova_market_listings_seller_id_idx
  on public.nova_market_listings (seller_id);

create index if not exists nova_market_orders_listing_id_idx
  on public.nova_market_orders (listing_id);

create index if not exists nova_market_inventory_ledger_listing_id_idx
  on public.nova_market_inventory_ledger (listing_id);
