-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118232146
-- Remote migration name: nova_factory_profit_margin_v2
-- Source: Supabase postgres_logs at 2026-11-18 23:21:46 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint,production_rate numeric,operating_cost numeric,rarity_factor numeric)
language sql immutable set search_path to '' as $function$
  select cfg.founding_cost,cfg.production_rate,cfg.operating_cost,cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,1.10::numeric,25.00::numeric,1.00::numeric),
    ('silicon_ore',2400,1.03,28.00,1.20),
    ('energy_cells',3200,0.92,32.00,1.40),
    ('crude_alloy',4200,0.89,35.00,1.65),
    ('carbon_fiber',6000,0.88,42.00,2.10),
    ('rare_minerals',9000,0.87,50.00,3.60),
    ('titanium_ore',12000,0.86,60.00,4.00),
    ('polymer_resin',15000,0.85,65.00,4.50),
    ('biotech_gel',22000,0.84,80.00,5.00),
    ('quantum_dust',30000,0.83,110.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$function$;;
