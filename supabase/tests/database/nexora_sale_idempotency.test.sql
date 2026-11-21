begin;

select extensions.plan(8);

insert into nexora.player_profiles(user_id, username, username_lower)
values ('nova_phase2_sale_idempotency_test', 'nova_phase2_test', 'nova_phase2_test');

insert into nexora.wallets(user_id, balance)
values ('nova_phase2_sale_idempotency_test', 1000);

insert into nexora.inventory(user_id, item_id, quantity)
values ('nova_phase2_sale_idempotency_test', 'silicon_ore', 10);

create temporary table phase_two_sale_replays (
  attempt integer primary key,
  response jsonb not null
);

insert into phase_two_sale_replays(attempt, response)
select 1, nexora.sell_to_nexora_idempotent(
  'nova_phase2_sale_idempotency_test', 'silicon_ore', 3, 'nova-phase2-sale-0001'
);

insert into phase_two_sale_replays(attempt, response)
select 2, nexora.sell_to_nexora_idempotent(
  'nova_phase2_sale_idempotency_test', 'silicon_ore', 3, 'nova-phase2-sale-0001'
);

select extensions.ok(
  (select (response->>'idempotent_replay') is null from phase_two_sale_replays where attempt = 1),
  'first merchant sale request executes normally'
);

select extensions.ok(
  (select response->>'idempotent_replay' = 'true' from phase_two_sale_replays where attempt = 2),
  'retry with the same key returns the cached response'
);

select extensions.is(
  (select response->>'total' from phase_two_sale_replays where attempt = 1),
  '63',
  'original sale payout is preserved'
);

select extensions.is(
  (select balance from nexora.wallets where user_id = 'nova_phase2_sale_idempotency_test'),
  1063::bigint,
  'wallet is credited exactly once'
);

select extensions.is(
  (select quantity from nexora.inventory where user_id = 'nova_phase2_sale_idempotency_test' and item_id = 'silicon_ore'),
  7::bigint,
  'inventory is debited exactly once'
);

select extensions.is(
  (select quantity_sold from nexora.nexora_daily_sales
   where user_id = 'nova_phase2_sale_idempotency_test'
     and sale_date = (now() at time zone 'utc')::date),
  3,
  'daily sale limit counter advances only once'
);

select extensions.is(
  (select count(*)::integer from nexora.transactions
   where to_uid = 'nova_phase2_sale_idempotency_test' and type = 'nexora_sale'),
  1,
  'only one transaction ledger row is created'
);

select extensions.throws_ok(
  $$select nexora.sell_to_nexora_idempotent(
    'nova_phase2_sale_idempotency_test', 'silicon_ore', 4, 'nova-phase2-sale-0001'
  )$$,
  'P0001',
  'IDEMPOTENCY_KEY_REUSED',
  'same request key cannot be reused with a different payload'
);

select * from extensions.finish();

rollback;
