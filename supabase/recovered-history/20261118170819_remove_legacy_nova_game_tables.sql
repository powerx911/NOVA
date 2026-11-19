-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118170819
-- Remote migration name: remove_legacy_nova_game_tables
-- Source: Supabase postgres_logs at 2026-11-18 17:08:19 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

drop table public.nova_buildings;
drop table public.nova_command_receipts;
drop table public.nova_competitive_activities;
drop table public.nova_competitive_assets;
drop table public.nova_competitive_battles;
drop table public.nova_competitive_commands;
drop table public.nova_competitive_inventory;
drop table public.nova_competitive_ledger;
drop table public.nova_competitive_profiles;
drop table public.nova_competitive_wallets;
drop table public.nova_market_inventory_ledger;
drop table public.nova_market_orders;
drop table public.nova_market_listings;
drop table public.nova_player_economy;
drop table public.nova_player_profiles;
drop table public.nova_resource_ledger;
drop table public.nova_castles;
;
