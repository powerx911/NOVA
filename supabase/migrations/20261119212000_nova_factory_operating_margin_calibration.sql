-- Preserve controlled factory margins after raising starting output from 3 to 20 units/hour.
create or replace function nexora.factory_resource_config(p_resource_id text)
returns table(founding_cost bigint, production_rate numeric, operating_cost numeric, rarity_factor numeric)
language sql immutable
set search_path = ''
as $config$
  select cfg.founding_cost,cfg.production_rate,cfg.operating_cost,cfg.rarity_factor
  from (values
    ('copper_wire'::text,1800::bigint,20.000::numeric,500.00::numeric,1.00::numeric),
    ('silicon_ore',2400,18.000,563.00,1.20),
    ('energy_cells',3200,16.000,643.00,1.40),
    ('crude_alloy',4200,14.000,500.00,1.65),
    ('carbon_fiber',6000,11.000,541.00,2.10),
    ('rare_minerals',9000,8.000,500.00,3.60),
    ('titanium_ore',12000,7.000,532.00,4.00),
    ('polymer_resin',15000,6.000,509.00,4.50),
    ('biotech_gel',22000,4.000,429.00,5.00),
    ('quantum_dust',30000,3.000,429.00,6.00)
  ) as cfg(resource_id,founding_cost,production_rate,operating_cost,rarity_factor)
  where cfg.resource_id=p_resource_id
$config$;

-- Costs grow more slowly than output, while skill bonuses remain deliberately small.
do $migration$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure)
    into v_definition;

  if position('0.06' in v_definition) = 0
     or position('0.04' in v_definition) = 0
     or position('0.03' in v_definition) = 0 then
    raise exception 'FACTORY_OPERATING_MARGIN_SOURCE_NOT_FOUND';
  end if;

  v_definition := regexp_replace(
    v_definition,
    'greatest[(]0,[[:space:]]*v_factory[.]level[[:space:]]*-[[:space:]]*1[)][[:space:]]*[*][[:space:]]*0[.]06',
    'greatest(0,v_factory.level-1)*0.025',
    'g'
  );
  v_definition := regexp_replace(
    v_definition,
    'v_factory[.]skill_level[[:space:]]*[*][[:space:]]*0[.]04',
    'v_factory.skill_level*0.01',
    'g'
  );
  v_definition := regexp_replace(
    v_definition,
    'v_factory[.]skill_level[[:space:]]*[*][[:space:]]*0[.]03',
    'v_factory.skill_level*0.005',
    'g'
  );

  if position('0.025' in v_definition) = 0
     or position('0.01' in v_definition) = 0
     or position('0.005' in v_definition) = 0 then
    raise exception 'FACTORY_OPERATING_MARGIN_CALIBRATION_FAILED';
  end if;

  execute v_definition;
end
$migration$;
