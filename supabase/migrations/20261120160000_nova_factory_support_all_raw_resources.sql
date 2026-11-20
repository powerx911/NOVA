-- Keep the factory founding constraint aligned with the ten resources
-- exposed by FACTORY_RESOURCES and nexora.factory_resource_config().
alter table nexora.factories
  drop constraint if exists factories_resource_id_check;

alter table nexora.factories
  add constraint factories_resource_id_check
  check (resource_id = any (array[
    'copper_wire'::text,
    'silicon_ore'::text,
    'energy_cells'::text,
    'crude_alloy'::text,
    'carbon_fiber'::text,
    'rare_minerals'::text,
    'titanium_ore'::text,
    'polymer_resin'::text,
    'biotech_gel'::text,
    'quantum_dust'::text
  ]));
