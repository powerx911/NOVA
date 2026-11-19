-- Give each factory resource its own stronger, convex level progression.
-- The level-100 output multiplier ranges from ~4.93x to ~7.04x before skill bonuses.
create or replace function nexora.factory_progression_multiplier(p_resource_id text, p_level integer)
returns numeric
language sql
immutable
set search_path = ''
as $function$
  with curve as (
    select
      case p_resource_id
        when 'copper_wire' then 0.028::numeric
        when 'silicon_ore' then 0.030::numeric
        when 'energy_cells' then 0.032::numeric
        when 'crude_alloy' then 0.034::numeric
        when 'carbon_fiber' then 0.036::numeric
        when 'rare_minerals' then 0.038::numeric
        when 'titanium_ore' then 0.040::numeric
        when 'polymer_resin' then 0.042::numeric
        when 'biotech_gel' then 0.044::numeric
        when 'quantum_dust' then 0.046::numeric
        else 0.028::numeric
      end as linear_growth,
      case p_resource_id
        when 'copper_wire' then 0.00020::numeric
        when 'silicon_ore' then 0.00022::numeric
        when 'energy_cells' then 0.00024::numeric
        when 'crude_alloy' then 0.00026::numeric
        when 'carbon_fiber' then 0.00028::numeric
        when 'rare_minerals' then 0.00030::numeric
        when 'titanium_ore' then 0.00032::numeric
        when 'polymer_resin' then 0.00034::numeric
        when 'biotech_gel' then 0.00036::numeric
        when 'quantum_dust' then 0.00038::numeric
        else 0.00020::numeric
      end as quadratic_growth
  )
  select 1
    + linear_growth * greatest(0, coalesce(p_level, 1) - 1)
    + quadratic_growth * power(greatest(0, coalesce(p_level, 1) - 1)::numeric, 2)
  from curve
$function$;

do $migration$
declare
  v_definition text;
  v_pattern text := 'v_rate := v_cfg[.]production_rate[[:space:]]*[*][[:space:]]*[(]1[[:space:]]*[+][[:space:]]*0[.]018[[:space:]]*[*][[:space:]]*greatest[(]0,[[:space:]]*v_factory[.]level[[:space:]]*-[[:space:]]*1[)][[:space:]]*[+][[:space:]]*0[.]00012[[:space:]]*[*][[:space:]]*power[(]greatest[(]0,[[:space:]]*v_factory[.]level[[:space:]]*-[[:space:]]*1[)]::numeric,[[:space:]]*2[)][)][[:space:]]*[*][[:space:]]*[(]1[[:space:]]*[+][[:space:]]*v_factory[.]skill_level[[:space:]]*[*][[:space:]]*0[.]01[)][[:space:]]*;';
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure)
    into v_definition;

  if position('0.018' in v_definition) = 0
     or position('0.00012' in v_definition) = 0 then
    raise exception 'FACTORY_PROGRESSION_CURVE_SOURCE_NOT_FOUND';
  end if;

  v_definition := regexp_replace(
    v_definition,
    v_pattern,
    'v_rate := v_cfg.production_rate * nexora.factory_progression_multiplier(v_factory.resource_id, v_factory.level) * (1 + v_factory.skill_level * 0.01);',
    'g'
  );

  if position('nexora.factory_progression_multiplier(v_factory.resource_id, v_factory.level)' in v_definition) = 0 then
    raise exception 'FACTORY_RESOURCE_CURVE_REPLACEMENT_FAILED';
  end if;

  execute v_definition;
end
$migration$;
