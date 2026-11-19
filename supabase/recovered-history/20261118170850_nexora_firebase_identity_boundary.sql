-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118170850
-- Remote migration name: nexora_firebase_identity_boundary
-- Source: Supabase postgres_logs at 2026-11-18 17:08:50 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

do $$
declare r record;
begin
  for r in
    select conrelid::regclass as tbl, conname
    from pg_constraint
    where contype='f' and confrelid='auth.users'::regclass
      and connamespace='nexora'::regnamespace
  loop
    execute format('alter table %s drop constraint %I',r.tbl,r.conname);
  end loop;
end $$;

alter table nexora.player_profiles alter column user_id type text using user_id::text;
alter table nexora.player_private alter column user_id type text using user_id::text;
alter table nexora.wallets alter column user_id type text using user_id::text;
alter table nexora.transactions alter column from_uid type text using from_uid::text;
alter table nexora.transactions alter column to_uid type text using to_uid::text;
alter table nexora.inventory alter column user_id type text using user_id::text;
alter table nexora.market_listings alter column seller_uid type text using seller_uid::text;
alter table nexora.market_orders alter column buyer_uid type text using buyer_uid::text;
alter table nexora.market_orders alter column seller_uid type text using seller_uid::text;
alter table nexora.companies alter column owner_uid type text using owner_uid::text;
alter table nexora.company_logs alter column owner_uid type text using owner_uid::text;
alter table nexora.properties alter column owner_uid type text using owner_uid::text;
alter table nexora.organizations alter column leader_uid type text using leader_uid::text;
alter table nexora.organization_members alter column user_id type text using user_id::text;
alter table nexora.organization_requests alter column user_id type text using user_id::text;
alter table nexora.organization_transactions alter column user_id type text using user_id::text;
alter table nexora.player_missions alter column user_id type text using user_id::text;
alter table nexora.daily_claims alter column user_id type text using user_id::text;
alter table nexora.contract_claims alter column user_id type text using user_id::text;
alter table nexora.player_achievements alter column user_id type text using user_id::text;
alter table nexora.notifications alter column user_id type text using user_id::text;
alter table nexora.audit_logs alter column user_id type text using user_id::text;
alter table nexora.diagnostics_admins alter column user_id type text using user_id::text;
alter table nexora.usernames alter column uid type text using uid::text;
;
