-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118170652
-- Remote migration name: nexora_username_compatibility
-- Source: Supabase postgres_logs at 2026-11-18 17:06:52 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

alter table nexora.usernames rename column user_id to uid;;
