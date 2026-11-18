-- Early factories intentionally earn less than starter companies.
-- High-tier factories scale through level upgrades and can exceed company income later.
create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint,production_rate numeric,operating_cost numeric,rarity_factor numeric)
language sql immutable set search_path to '' as $function$
  select cfg.founding_cost,cfg.production_rate,cfg.operating_cost,cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,2.00::numeric,25.00::numeric,1.00::numeric),
    ('silicon_ore',2400,2.00,28.00,1.20),
    ('energy_cells',3200,1.50,32.00,1.40),
    ('crude_alloy',4200,1.50,35.00,1.65),
    ('carbon_fiber',6000,1.25,42.00,2.10),
    ('rare_minerals',9000,2.00,50.00,3.60)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$function$;
