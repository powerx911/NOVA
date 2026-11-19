-- Run with: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(5);

select extensions.is(
  nexora.factory_progression_multiplier('copper_wire', 1),
  1::numeric,
  'factory progression starts at the base rate at level one'
);

select extensions.ok(
  (select count(distinct round(nexora.factory_progression_multiplier(resource_id, 100), 6)) = 10
   from (values
     ('copper_wire'), ('silicon_ore'), ('energy_cells'), ('crude_alloy'),
     ('carbon_fiber'), ('rare_minerals'), ('titanium_ore'), ('polymer_resin'),
     ('biotech_gel'), ('quantum_dust')
   ) as resources(resource_id)),
  'all ten raw resources have distinct level-100 progression multipliers'
);

select extensions.ok(
  (select bool_and(
    nexora.factory_progression_multiplier(resource_id, 100) >= 4.9
    and nexora.factory_progression_multiplier(resource_id, 100) <= 7.1
  )
   from (values
     ('copper_wire'), ('silicon_ore'), ('energy_cells'), ('crude_alloy'),
     ('carbon_fiber'), ('rare_minerals'), ('titanium_ore'), ('polymer_resin'),
     ('biotech_gel'), ('quantum_dust')
   ) as resources(resource_id)),
  'level-100 progression is stronger but remains inside the calibrated 4.9x–7.1x range'
);

select extensions.ok(
  (select bool_and(
    nexora.factory_progression_multiplier(resource_id, 3)
      - nexora.factory_progression_multiplier(resource_id, 2)
    <
    nexora.factory_progression_multiplier(resource_id, 76)
      - nexora.factory_progression_multiplier(resource_id, 75)
  )
   from (values
     ('copper_wire'), ('silicon_ore'), ('energy_cells'), ('crude_alloy'),
     ('carbon_fiber'), ('rare_minerals'), ('titanium_ore'), ('polymer_resin'),
     ('biotech_gel'), ('quantum_dust')
   ) as resources(resource_id)),
  'every resource uses an accelerating convex curve'
);

select extensions.ok(
  (select bool_and(
    nexora.factory_progression_multiplier(resource_id, 100)
      > nexora.factory_progression_multiplier(resource_id, 99)
  )
   from (values
     ('copper_wire'), ('silicon_ore'), ('energy_cells'), ('crude_alloy'),
     ('carbon_fiber'), ('rare_minerals'), ('titanium_ore'), ('polymer_resin'),
     ('biotech_gel'), ('quantum_dust')
   ) as resources(resource_id)),
  'every resource continues to gain production through level 100'
);

select * from extensions.finish();
rollback;
