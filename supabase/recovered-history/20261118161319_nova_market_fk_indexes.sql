-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118161319
-- Remote migration name: nova_market_fk_indexes
-- Source: Supabase postgres_logs at 2026-11-18 16:13:19 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

-- Cover the market foreign keys used for seller history, order joins, and inventory audit lookups.
create index if not exists nova_market_listings_seller_id_idx
  on public.nova_market_listings (seller_id);

create index if not exists nova_market_orders_listing_id_idx
  on public.nova_market_orders (listing_id);

create index if not exists nova_market_inventory_ledger_listing_id_idx
  on public.nova_market_inventory_ledger (listing_id);
;
