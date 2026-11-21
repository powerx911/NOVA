-- Regression simulation for B3: a rate change must not reprice time already accrued.
-- This test is intentionally expected to fail against the current implementation
-- until accrual is anchored to the rate that applied during the elapsed interval.
create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(3);

insert into nexora.player_profiles(user_id, username, username_lower, xp, level, skills, stats)
values (
  'pgtap_company_accrual_anchor',
  'pgtap_accrual_anchor',
  'pgtap_accrual_anchor',
  0, 1, '{"management":0,"finance":0}'::jsonb, '{}'::jsonb
);

insert into nexora.wallets(user_id, balance, total_earned, total_spent)
values ('pgtap_company_accrual_anchor', 0, 0, 0);

insert into nexora.companies(
  id, owner_uid, owner_name, name, sector,
  base_revenue_per_hour, expense_per_hour, total_revenue,
  vault_level, vault_balance, last_collected_at
)
values (
  'pgtap_company_accrual_anchor',
  'pgtap_company_accrual_anchor',
  'pgTAP Accrual Anchor',
  'pgTAP Accrual Anchor',
  'trade',
  100, 0, 0,
  1, 500, now() - interval '2 hours'
);

create temporary table accrual_anchor_snapshot as
select
  (nexora.company_collectable_amount('pgtap_company_accrual_anchor')->>'collectable')::bigint as collectable_before,
  nexora.company_net_hourly('pgtap_company_accrual_anchor') as rate_before;

select extensions.is(
  (select rate_before from accrual_anchor_snapshot),
  100::bigint,
  'simulation starts at the known 100-credit hourly rate'
);

update nexora.player_profiles
set skills = jsonb_set(coalesce(skills, '{}'::jsonb), '{management}', '5'::jsonb)
where user_id = 'pgtap_company_accrual_anchor';

select extensions.ok(
  nexora.company_net_hourly('pgtap_company_accrual_anchor')
    > (select rate_before from accrual_anchor_snapshot),
  'the simulated skill upgrade increases the current hourly rate'
);

select extensions.is(
  (nexora.company_collectable_amount('pgtap_company_accrual_anchor')->>'collectable')::bigint,
  (select collectable_before from accrual_anchor_snapshot),
  'changing the rate does not retroactively reprice the two hours already accrued'
);

select * from extensions.finish();
rollback;
