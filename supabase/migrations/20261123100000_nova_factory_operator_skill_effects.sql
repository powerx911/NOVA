-- Make operator skill effects consistent with the factory UI and requested balance.
-- Preserve the current production curve, operating-cost progression, and reserve logic.

do $patch$
declare
  v_definition text;
  v_old_output text := '(1+v_factory.skill_level*0.02)';
  v_new_output text := '(1+v_factory.skill_level*0.04)';
  v_old_cost text := '(1-v_factory.skill_level*0.015)';
  v_new_cost text := '(1-v_factory.skill_level*0.025)';
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure)
    into v_definition;

  if position(v_new_output in v_definition) > 0
     and position(v_new_cost in v_definition) > 0 then
    raise notice 'Factory operator skill effects already updated';
    return;
  end if;

  if position(v_old_output in v_definition) = 0 then
    raise exception 'FACTORY_SKILL_OUTPUT_ANCHOR_NOT_FOUND';
  end if;
  if position(v_old_cost in v_definition) = 0 then
    raise exception 'FACTORY_SKILL_OPERATING_COST_ANCHOR_NOT_FOUND';
  end if;

  v_definition := replace(v_definition, v_old_output, v_new_output);
  v_definition := replace(v_definition, v_old_cost, v_new_cost);

  if position(v_new_output in v_definition) = 0
     or position(v_new_cost in v_definition) = 0 then
    raise exception 'FACTORY_SKILL_EFFECT_PATCH_VALIDATION_FAILED';
  end if;

  execute v_definition;
end
$patch$;
