-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118170811
-- Remote migration name: remove_legacy_nova_functions
-- Source: Supabase postgres_logs at 2026-11-18 17:08:11 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

drop trigger if exists nova_seed_competitive_inventory on public.nova_competitive_profiles;
drop trigger if exists nova_track_energy_spend on public.nova_competitive_wallets;
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.prokind='f' and n.nspname='public' and p.proname like 'nova_%'
    order by p.proname
  loop execute format('drop function %s',r.sig); end loop;
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.prokind='f' and n.nspname='private' and p.proname like 'nova_%'
    order by p.proname
  loop execute format('drop function %s',r.sig); end loop;
end $$;
;
