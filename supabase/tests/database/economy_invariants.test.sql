-- Run with: supabase test db
-- This suite is intentionally transactional and leaves no fixture rows behind.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

select ok(
  not exists (select 1 from nexora.wallets where balance < 0),
  'no player wallet has a negative balance'
);

select is(
  (
    select count(*)::bigint
    from nexora.wallets w
    where w.balance <> 2500 + coalesce((
      select sum(case
        when t.to_uid = w.user_id then t.net_amount
        when t.from_uid = w.user_id then -t.amount
        else 0
      end)
      from nexora.transactions t
      where t.to_uid = w.user_id or t.from_uid = w.user_id
    ), 0)
  ),
  0::bigint,
  'wallet balances reconcile to the immutable transaction ledger'
);

select throws_ok(
  $$insert into nexora.wallets(user_id, balance) values ('pgtap_negative_wallet', -1)$$,
  '23514',
  null,
  'the database rejects a negative wallet balance'
);

insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values ('pgtap_pause_owner', 2500, 2500, 0);

insert into nexora.factories(
  id, owner_uid, owner_name, name, resource_id, level, skill_level,
  is_active, warehouse_qty, production_remainder, operating_cost_remainder,
  last_produced_at
)
values (
  'pgtap_pause_factory', 'pgtap_pause_owner', 'pgTAP', 'Pause regression factory',
  'copper_wire', 1, 0, true, 0, 0, 0, now() - interval '2 hours'
);

select lives_ok(
  $$select nexora.set_factory_active('pgtap_pause_owner', 'pgtap_pause_factory', false)$$,
  'pausing an active factory synchronizes its elapsed production first'
);

select is(
  (select is_active from nexora.factories where id = 'pgtap_pause_factory'),
  false,
  'factory is inactive after the pause RPC'
);

select is(
  (select balance from nexora.wallets where user_id = 'pgtap_pause_owner'),
  2450::bigint,
  'two elapsed hours of copper-wire operating costs are charged before pausing'
);

select is(
  (select count(*)::bigint from nexora.transactions where from_uid = 'pgtap_pause_owner' and type = 'factory_operating'),
  1::bigint,
  'pause creates exactly one operating-cost ledger row'
);

select lives_ok(
  $$select nexora.sync_factory_production('pgtap_pause_owner', 'pgtap_pause_factory')$$,
  'a later sync of a paused factory succeeds without production'
);

select is(
  (select balance from nexora.wallets where user_id = 'pgtap_pause_owner'),
  2450::bigint,
  'syncing after pause does not charge a second operating cost'
);

select is(
  (select count(*)::bigint from nexora.transactions where from_uid = 'pgtap_pause_owner' and type = 'factory_operating'),
  1::bigint,
  'syncing after pause does not append another operating-cost ledger row'
);

select * from finish();
rollback;
