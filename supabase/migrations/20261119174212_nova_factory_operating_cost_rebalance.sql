-- Align server-side factory operating costs with the client catalog while keeping raw margins bounded.
create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
language sql immutable set search_path = ''
as $function$
  select cfg.founding_cost,cfg.production_rate,cfg.operating_cost,cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,2.750::numeric,60.00::numeric,1.00::numeric),
    ('silicon_ore',2400,2.575,70.00,1.20),
    ('energy_cells',3200,2.300,80.00,1.40),
    ('crude_alloy',4200,2.225,69.00,1.65),
    ('carbon_fiber',6000,2.200,94.00,2.10),
    ('rare_minerals',9000,2.175,118.00,3.60),
    ('titanium_ore',12000,2.150,141.00,4.00),
    ('polymer_resin',15000,2.125,156.00,4.50),
    ('biotech_gel',22000,2.100,194.00,5.00),
    ('quantum_dust',30000,2.075,256.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$function$;