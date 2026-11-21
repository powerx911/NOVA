-- Verify company, factory, and warehouse upgrades cannot be charged twice while pending.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(21);

insert into nexora.player_profiles(user_id, username, username_lower, xp, level, skills, stats)
values
  ('pgtap_upgrade_company', 'pgtap_upgrade_company', 'pgtap_upgrade_company', 0, 1, '{}'::jsonb, '{}'::jsonb),
  ('pgtap_upgrade_factory', 'pgtap_upgrade_factory', 'pgtap_upgrade_factory', 0, 1, '{}'::jsonb, '{}'::jsonb),
  ('pgtap_upgrade_warehouse', 'pgtap_upgrade_warehouse', 'pgtap_upgrade_warehouse', 0, 1, '{}'::jsonb, '{}'::jsonb);

insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values
  ('pgtap_upgrade_company', 10000, 10000, 0),
  ('pgtap_upgrade_factory', 10000, 10000, 0),
  ('pgtap_upgrade_warehouse', 10000, 10000, 0);

insert into nexora.companies(
  id, owner_uid, owner_name, name, sector, level, capital,
  base_revenue_per_hour, expense_per_hour, total_revenue, vault_level, vault_balance
) values (
  'pgtap_upgrade_company', 'pgtap_upgrade_company', 'pgTAP', 'Company upgrade guard',
  'trade', 1, 1000, 100, 0, 0, 1, 0
);

select extensions.lives_ok(
  $$select nexora.start_company_upgrade('pgtap_upgrade_company', 'pgtap_upgrade_company')$$,
  'the first company upgrade starts successfully'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_upgrade_company'),
  10000 - nexora.company_upgrade_cost('trade', 1),
  'company upgrade deducts its price once'
);
select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid='pgtap_upgrade_company' and type='company_upgrade' and reference_id='pgtap_upgrade_company'),
  1::bigint,
  'company upgrade writes one financial transaction'
);

update nexora.companies set level_upgrade_ends_at=now()-interval '1 second'
where id='pgtap_upgrade_company';

select extensions.throws_ok(
  $$select nexora.start_company_upgrade('pgtap_upgrade_company', 'pgtap_upgrade_company')$$,
  'P0001', 'UPGRADE_IN_PROGRESS',
  'an elapsed but uncompleted company upgrade cannot be started again'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_upgrade_company'),
  10000 - nexora.company_upgrade_cost('trade', 1),
  'a repeated company upgrade request does not deduct a second price'
);
select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid='pgtap_upgrade_company' and type='company_upgrade' and reference_id='pgtap_upgrade_company'),
  1::bigint,
  'a repeated company upgrade request does not add a second transaction'
);

insert into nexora.inventory(user_id, item_id, quantity)
values ('pgtap_upgrade_factory', 'copper_wire', 10);

insert into nexora.factories(
  id, owner_uid, owner_name, name, resource_id, level, skill_level,
  is_active, warehouse_qty, production_remainder, operating_cost_remainder,
  last_produced_at, warehouse_level
) values (
  'pgtap_upgrade_factory', 'pgtap_upgrade_factory', 'pgTAP', 'Factory upgrade guard',
  'copper_wire', 1, 0, true, 0, 0, 0, now(), 1
);

select extensions.lives_ok(
  $$select nexora.upgrade_factory('pgtap_upgrade_factory', 'pgtap_upgrade_factory')$$,
  'the first factory level upgrade starts successfully'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_upgrade_factory'),
  10000 - 396,
  'factory level upgrade deducts its price once'
);
select extensions.is(
  (select quantity from nexora.inventory where user_id='pgtap_upgrade_factory' and item_id='copper_wire'),
  8::bigint,
  'factory level upgrade consumes its required materials once'
);
select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid='pgtap_upgrade_factory' and type='factory_upgrade' and reference_id='pgtap_upgrade_factory'),
  1::bigint,
  'factory level upgrade writes one financial transaction'
);

update nexora.factories set upgrade_ends_at=now()-interval '1 second'
where id='pgtap_upgrade_factory';

select extensions.throws_ok(
  $$select nexora.upgrade_factory('pgtap_upgrade_factory', 'pgtap_upgrade_factory')$$,
  'P0001', 'UPGRADE_NOT_FINISHED',
  'an elapsed but uncompleted factory upgrade cannot be charged again'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_upgrade_factory'),
  10000 - 396,
  'a repeated factory upgrade request does not deduct a second price'
);
select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid='pgtap_upgrade_factory' and type='factory_upgrade' and reference_id='pgtap_upgrade_factory'),
  1::bigint,
  'a repeated factory upgrade request does not add a second transaction'
);

insert into nexora.factories(
  id, owner_uid, owner_name, name, resource_id, level, skill_level,
  is_active, warehouse_qty, production_remainder, operating_cost_remainder,
  last_produced_at, warehouse_level
) values (
  'pgtap_upgrade_warehouse', 'pgtap_upgrade_warehouse', 'pgTAP', 'Warehouse upgrade guard',
  'copper_wire', 1, 0, true, 0, 0, 0, now(), 1
);

select extensions.lives_ok(
  $$select nexora.upgrade_factory_warehouse('pgtap_upgrade_warehouse', 'pgtap_upgrade_warehouse')$$,
  'the first warehouse upgrade starts successfully'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_upgrade_warehouse'),
  7500::bigint,
  'warehouse upgrade deducts its price once'
);
select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid='pgtap_upgrade_warehouse' and type='factory_warehouse_upgrade' and reference_id='pgtap_upgrade_warehouse'),
  1::bigint,
  'warehouse upgrade writes one financial transaction'
);

update nexora.factories set warehouse_upgrade_ends_at=now()-interval '1 second'
where id='pgtap_upgrade_warehouse';

select extensions.throws_ok(
  $$select nexora.upgrade_factory_warehouse('pgtap_upgrade_warehouse', 'pgtap_upgrade_warehouse')$$,
  'P0001', 'UPGRADE_NOT_FINISHED',
  'an elapsed but uncompleted warehouse upgrade cannot be charged again'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_upgrade_warehouse'),
  7500::bigint,
  'a repeated warehouse upgrade request does not deduct a second price'
);
select extensions.is(
  (select count(*)::bigint from nexora.transactions where from_uid='pgtap_upgrade_warehouse' and type='factory_warehouse_upgrade' and reference_id='pgtap_upgrade_warehouse'),
  1::bigint,
  'a repeated warehouse upgrade request does not add a second transaction'
);

select extensions.throws_ok(
  $$select nexora.upgrade_factory('pgtap_upgrade_warehouse', 'pgtap_upgrade_warehouse')$$,
  'P0001', 'UPGRADE_NOT_FINISHED',
  'a factory level upgrade cannot start while a warehouse upgrade is pending'
);
select extensions.is(
  (select balance from nexora.wallets where user_id='pgtap_upgrade_warehouse'),
  7500::bigint,
  'overlapping factory upgrade types cannot charge the same wallet again'
);

select * from extensions.finish();
rollback;
