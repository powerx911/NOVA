-- Make operator skill effects consistent with the factory UI and requested balance.
-- Preserve the current production curve, operating-cost progression, and reserve logic.

do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure)
    into v_definition;

  if position('v_factory.skill_level*0.04' in v_definition) > 0
     and position('v_factory.skill_level*0.025' in v_definition) > 0 then
    raise notice 'Factory operator skill effects already updated';
    return;
  end if;

  -- The active production curve already applies a 4% output bonus per level.
  if position('v_factory.skill_level*0.04' in v_definition) = 0 then
    raise exception 'FACTORY_SKILL_OUTPUT_ANCHOR_NOT_FOUND';
  end if;
  if position('v_factory.skill_level*0.005' in v_definition) = 0 then
    raise exception 'FACTORY_SKILL_OPERATING_COST_ANCHOR_NOT_FOUND';
  end if;

  -- Change only the operator-skill cost reduction; preserve factory-level costs.
  v_definition := replace(
    v_definition,
    '(1-v_factory.skill_level*0.005)',
    '(1-v_factory.skill_level*0.025)'
  );

  if position('v_factory.skill_level*0.04' in v_definition) = 0
     or position('v_factory.skill_level*0.025' in v_definition) = 0 then
    raise exception 'FACTORY_SKILL_EFFECT_PATCH_VALIDATION_FAILED';
  end if;

  execute v_definition;
end
$patch$;
