-- Regression coverage for serialization of concurrent organization contract claims.
begin;
select extensions.plan(3);

select extensions.ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'nexora.contract_offers'::regclass
      and tgname = 'contract_offers_lock_active_org_claim'
      and not tgisinternal
  ),
  'active organization contract claims are serialized by a before-write trigger'
);

select extensions.ok(
  (select prosecdef from pg_proc
   where oid = 'nexora.lock_active_org_contract_claim()'::regprocedure),
  'claim-lock trigger function runs as security definer'
);

select extensions.ok(
  (select proconfig @> array['search_path=""'] from pg_proc
   where oid = 'nexora.lock_active_org_contract_claim()'::regprocedure),
  'claim-lock trigger function has a fixed empty search_path'
);

select * from extensions.finish();
rollback;
