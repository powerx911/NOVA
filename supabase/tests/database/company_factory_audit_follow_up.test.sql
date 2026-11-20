-- Regression coverage for the company/factory audit follow-up migration.
-- Run with: supabase test db
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(6);

insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values ('pgtap_audit_reserve_owner', 350, 350, 0);

insert into nexora.factories(
  id, owner_uid, owner_name, name, resource_id, level, skill_level,
  is_active, warehouse_qty, production_remainder, operating_cost_remainder,
  last_produced_at
)
values (
  'pgtap_audit_reserve_factory', 'pgtap_audit_reserve_owner', 'pgTAP',
  'Audit reserve factory', 'copper_wire', 1, 0, true, 0, 0, 0,
  now() - interval '2 hours'
);

select extensions.lives_ok(
  $$select nexora.sync_factory_production('pgtap_audit_reserve_owner', 'pgtap_audit_reserve_factory')$$,
  'factory sync succeeds when only the protected reserve remains available'
);

select extensions.is(
  (select balance from nexora.wallets where user_id = 'pgtap_audit_reserve_owner'),
  300::bigint,
  'factory operating costs never consume the protected 300-credit wallet reserve'
);

select extensions.is(
  (select is_active from nexora.factories where id = 'pgtap_audit_reserve_factory'),
  false,
  'factory pauses automatically after reaching the protected wallet reserve'
);

select extensions.is(
  (select amount from nexora.transactions
   where from_uid = 'pgtap_audit_reserve_owner' and type = 'factory_operating'),
  50::bigint,
  'factory charges only the funds above the protected reserve'
);

select extensions.ok(
  position('if v_factory.upgrade_ends_at is not null then raise exception ''UPGRADE_NOT_FINISHED''' in
    lower(pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure))) > 0
  and position('if v_factory.warehouse_upgrade_ends_at is not null then raise exception ''UPGRADE_NOT_FINISHED''' in
    lower(pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)'::regprocedure))) > 0,
  'factory and warehouse upgrades reject every existing unfinished upgrade, including elapsed ones'
);

select extensions.ok(
  position('v_duration / 1000' in lower(pg_get_functiondef('nexora.upgrade_company_vault(text,text)'::regprocedure))) > 0
  and position('v_duration / 2000' in lower(pg_get_functiondef('nexora.upgrade_company_vault(text,text)'::regprocedure))) = 0,
  'company vault upgrade duration converts milliseconds to seconds exactly once'
);

select * from extensions.finish();
rollback;
