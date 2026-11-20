create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(12);

select extensions.ok(
  (select relrowsecurity from pg_class where oid='nexora.manufacturing_jobs'::regclass),
  'manufacturing_jobs has row-level security enabled'
);

select extensions.ok(
  not exists(select 1 from pg_policies where schemaname='nexora' and tablename='manufacturing_jobs'),
  'manufacturing_jobs has no broad direct-access policies'
);

select extensions.ok(
  not has_table_privilege('anon', 'nexora.manufacturing_jobs', 'select'),
  'anon cannot directly read manufacturing_jobs'
);

select extensions.ok(
  not has_table_privilege('authenticated', 'nexora.manufacturing_jobs', 'select'),
  'authenticated cannot directly read manufacturing_jobs'
);

select extensions.ok(
  not has_table_privilege('service_role', 'nexora.manufacturing_jobs', 'select'),
  'service_role cannot bypass the RPC boundary with direct table reads'
);

select extensions.ok(
  exists(
    select 1 from pg_index i
    where i.indexrelid='nexora.company_auctions_company_id_idx'::regclass
      and i.indisvalid
  ),
  'company_auctions company_id foreign key has a valid supporting index'
);

select extensions.ok(
  exists(
    select 1 from pg_index i
    where i.indexrelid='nexora.company_auctions_factory_id_idx'::regclass
      and i.indisvalid
  ),
  'company_auctions factory_id foreign key has a valid supporting index'
);

select extensions.ok(
  (select prosecdef from pg_proc where oid='nexora.manufacture_recipe(text,text,integer)'::regprocedure),
  'manufacture_recipe remains SECURITY DEFINER'
);

select extensions.ok(
  (select prosecdef from pg_proc where oid='nexora.cancel_manufacturing_job(text,text)'::regprocedure),
  'cancel_manufacturing_job remains SECURITY DEFINER'
);

select extensions.ok(
  (select prosecdef from pg_proc where oid='nexora.complete_manufacturing_job(text,text)'::regprocedure),
  'complete_manufacturing_job remains SECURITY DEFINER'
);

select extensions.ok(
  (select prosecdef from pg_proc where oid='nexora.get_manufacturing_job(text)'::regprocedure),
  'get_manufacturing_job remains SECURITY DEFINER'
);

select extensions.ok(
  (select prosecdef from pg_proc where oid='nexora.settle_finished_manufacturing_jobs()'::regprocedure),
  'settle_finished_manufacturing_jobs remains SECURITY DEFINER'
);

select * from extensions.finish();
rollback;
