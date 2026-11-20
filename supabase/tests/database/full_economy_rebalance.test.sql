-- Coverage for the unified business and factory economy curves.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(8);

select extensions.is(
  nexora.company_upgrade_cost('trade', 1),
  360::bigint,
  'trade company level 1 upgrade uses the rebalance cost curve'
);

select extensions.ok(
  nexora.company_upgrade_duration_seconds(5) > nexora.company_upgrade_duration_seconds(2),
  'company upgrade duration increases with target level'
);

select extensions.is(
  (select founding_cost from nexora.factory_resource_config('energy_cells')),
  4200::bigint,
  'energy cell factory founding cost is 4200'
);

select extensions.is(
  (select operating_cost from nexora.factory_resource_config('energy_cells')),
  630::numeric,
  'energy cell factory operating cost is balanced against its market value'
);

select extensions.ok(
  position('0.04' in lower(pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure))) > 0
  and position('0.018' in lower(pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure))) > 0,
  'factory output and operating-cost curves use the unified progression'
);

select extensions.ok(
  position('2500' in pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)')) > 0
  and position('720' in pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)')) > 0,
  'warehouse costs and the final warehouse duration are present'
);

select extensions.ok(
  position('company_level_multiplier' in lower(pg_get_functiondef('nexora.company_net_hourly(text)'::regprocedure))) > 0,
  'company income uses the smooth level multiplier'
);

select extensions.ok(
  position('nexora.company_upgrade_duration_seconds' in lower(pg_get_functiondef('nexora.start_company_upgrade(text,text)'::regprocedure))) > 0,
  'company upgrade RPC uses the shared duration curve'
);

select * from extensions.finish();
rollback;
