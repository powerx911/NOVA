-- Add four higher-tier raw resources to factory production and warehouse value tiers.
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
    ('rare_minerals',9000,2.00,50.00,3.60),
    ('titanium_ore',12000,1.50,60.00,4.00),
    ('polymer_resin',15000,1.25,65.00,4.50),
    ('biotech_gel',22000,1.10,80.00,5.00),
    ('quantum_dust',30000,1.00,110.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$function$;

create or replace function nexora.factory_warehouse_capacity(p_resource_id text,p_level integer)
returns bigint language sql immutable set search_path to '' as $function$
  select greatest(1,floor((array[3500,7000,14000,25000,40000]::bigint[])[greatest(1,least(5,coalesce(p_level,1)))]::numeric /
    case p_resource_id
      when 'copper_wire' then 28::numeric when 'silicon_ore' then 35::numeric
      when 'energy_cells' then 45::numeric when 'crude_alloy' then 40::numeric
      when 'carbon_fiber' then 55::numeric when 'rare_minerals' then 70::numeric
      when 'titanium_ore' then 85::numeric when 'polymer_resin' then 95::numeric
      when 'biotech_gel' then 120::numeric when 'quantum_dust' then 160::numeric
      else 30::numeric
    end))::bigint
$function$;
