-- Keep shared weekly goals demanding but achievable within a seven-day cycle.
update nexora.contract_config
set config_value = '{
  "trade_volume":25000,
  "produce_units":700,
  "company_revenue":40000,
  "company_upgrades":16,
  "factory_upgrades":16,
  "companies_founded":2,
  "factories_founded":2,
  "treasury_donations":12500,
  "contracts_completed":20,
  "org_contracts_completed":6,
  "personal_contracts_completed":12
}'::jsonb
where config_key='weekly_goal_bases';

with goal_bases as (
  select * from (values
    ('trade_volume',25000::numeric),
    ('produce_units',700::numeric),
    ('company_revenue',40000::numeric),
    ('company_upgrades',16::numeric),
    ('factory_upgrades',16::numeric),
    ('companies_founded',2::numeric),
    ('factories_founded',2::numeric),
    ('treasury_donations',12500::numeric),
    ('contracts_completed',20::numeric),
    ('org_contracts_completed',6::numeric),
    ('personal_contracts_completed',12::numeric)
  ) as b(goal_type,base_target)
)
update nexora.org_weekly_goals g
set target_amount=round(b.base_target*(1+0.20*greatest(1,o.level))*power(greatest(1,o.member_count)::numeric,0.85)),
    status=case when g.current_amount>=round(b.base_target*(1+0.20*greatest(1,o.level))*power(greatest(1,o.member_count)::numeric,0.85))
      then 'completed' else 'active' end,
    completed_at=case when g.current_amount>=round(b.base_target*(1+0.20*greatest(1,o.level))*power(greatest(1,o.member_count)::numeric,0.85))
      then coalesce(g.completed_at,now()) else null end
from nexora.organizations o join goal_bases b on true
where g.org_id=o.id and g.goal_type=b.goal_type
  and g.week_start=date_trunc('week',timezone('UTC',now()))::date and g.status='active';
