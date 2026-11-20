-- Production schema parity guard.
-- Expected counts are the read-only NOVA production inventory captured on 2026-11-20.
-- If this test fails, update the CI baseline/replay set; do not lower the expected counts
-- merely to make a stale snapshot pass.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(5);

select extensions.is(
  (select count(*)::integer from information_schema.tables where table_schema='nexora' and table_type='BASE TABLE'),
  45,
  'isolated schema contains the 45 production tables'
);

select extensions.is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='nexora' and p.prokind='f'),
  145,
  'isolated schema contains 144 production functions plus the pending account-deletion RPC'
);

select extensions.is(
  (select count(*)::integer from pg_trigger t join pg_class c on c.oid=t.tgrelid
   join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='nexora' and not t.tgisinternal),
  37,
  'isolated schema contains the 37 production triggers'
);

select extensions.is(
  (select count(*)::integer from pg_indexes where schemaname='nexora'),
  97,
  'isolated schema contains the 97 production indexes'
);

select extensions.is(
  (select count(*)::integer from pg_constraint c join pg_namespace n on n.oid=c.connamespace
   where n.nspname='nexora'),
  167,
  'isolated schema contains the 167 production constraints'
);

select * from extensions.finish();
rollback;
