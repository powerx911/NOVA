begin;
select extensions.plan(1);

select extensions.ok(
  (select pg_get_functiondef('nexora.lock_active_org_contract_claim()'::regprocedure)
    like '%raise exception ''ORG_ACTIVE_CONTRACT_LIMIT''%'),
  'a competing active claim is rejected with the domain error after taking the member lock'
);

select * from extensions.finish();
rollback;
