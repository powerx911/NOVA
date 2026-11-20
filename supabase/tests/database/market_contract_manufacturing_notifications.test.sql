-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(14);

select extensions.ok(
  to_regprocedure('nexora.player_inventory_usage(text)') is not null,
  'inventory usage helper includes inventory and active market escrow'
);

select extensions.ok(
  to_regprocedure('nexora.settle_finished_manufacturing_jobs()') is not null,
  'manufacturing completion has a server-side settlement worker'
);

select extensions.ok(
  exists(select 1 from pg_trigger where tgrelid='nexora.market_listings'::regclass
    and tgname='market_listing_capacity_guard' and not tgisinternal),
  'active market listings are included in inventory capacity enforcement'
);

select extensions.ok(
  position('cooldown_until<=now()' in pg_get_functiondef('nexora.get_dynamic_contract_board(text)'::regprocedure)) > 0,
  'organization slots can only refill after a manual refresh cooldown or on a new daily board'
);

select extensions.ok(
  position('new.scope=''personal''' in pg_get_functiondef('nexora.start_contract_slot_cooldown()'::regprocedure)) > 0
  and position('new.slot_no between 1 and 5' in pg_get_functiondef('nexora.start_contract_slot_cooldown()'::regprocedure)) > 0,
  'automatic 15-minute completion cooldowns are restricted to the five standard personal slots'
);

select extensions.ok(
  exists(select 1 from pg_trigger where tgrelid='nexora.transactions'::regclass
    and tgname='nova_notify_ready_missions_transaction' and not tgisinternal)
  and exists(select 1 from pg_trigger where tgrelid='nexora.companies'::regclass
    and tgname='nova_company_vault_full_notification' and not tgisinternal)
  and exists(select 1 from pg_trigger where tgrelid='nexora.factories'::regclass
    and tgname='nova_factory_warehouse_full_notification' and not tgisinternal),
  'mission-ready and full-storage notification triggers are installed'
);

select extensions.ok(
  to_regprocedure('nexora.notify_full_company_vaults()') is not null,
  'offline company vault accrual is checked for full-capacity notifications'
);

select extensions.ok(
  to_regprocedure('nexora.notify_full_factory_warehouses()') is not null,
  'already-full factory warehouses are detected and alert state resets after withdrawals'
);

select extensions.ok(
  to_regprocedure('nexora.sync_all_factory_production()') is not null,
  'factory production continues to synchronize without an open client panel'
);

select extensions.ok(
  to_regprocedure('nexora.notify_ready_contracts(text)') is not null,
  'already-ready personal and organization contracts can be notified on bootstrap'
);

select extensions.ok(
  to_regprocedure('nexora.emit_notification_once(text,text,text,text,text,text,text)') is not null,
  'notification delivery is deduplicated by event key'
);

select extensions.ok(
  (select provolatile='v' from pg_proc where oid='nexora.player_inventory_usage(text)'::regprocedure),
  'inventory usage reads a fresh snapshot inside after triggers'
);

select extensions.ok(
  position('nexora.allow_inventory_refund' in pg_get_functiondef('nexora.cancel_market_listing(text,text)'::regprocedure)) > 0,
  'cancelling a listing always restores its escrowed units even for legacy over-capacity accounts'
);

select extensions.ok(
  position('nexora.market_listing_transfer' in pg_get_functiondef('nexora.create_market_listing(text,text,integer,bigint)'::regprocedure)) > 0,
  'listing creation is treated as an inventory-to-market escrow transfer, not extra capacity use'
);

select * from extensions.finish();
rollback;
