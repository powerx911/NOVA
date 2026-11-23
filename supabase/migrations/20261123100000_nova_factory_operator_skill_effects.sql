-- Make operator skill effects consistent with the factory UI and requested balance.
-- Preserve the current production curve, operating-cost progression, and reserve logic.

do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure)
    into v_definition;

  if v_definition ~ 'v_factory\.skill_level[[:space:]]*\*[[:space:]]*0\.04'
     and v_definition ~ 'v_factory\.skill_level[[:space:]]*\*[[:space:]]*0\.025' then
    raise notice 'Factory operator skill effects already updated';
    return;
  end if;

  if v_definition !~ 'v_factory\.skill_level[[:space:]]*\*[[:space:]]*0\.02' then
    raise exception 'FACTORY_SKILL_OUTPUT_ANCHOR_NOT_FOUND';
  end if;
  if v_definition !~ 'v_factory\.skill_level[[:space:]]*\*[[:space:]]*0\.015' then
    raise exception 'FACTORY_SKILL_OPERATING_COST_ANCHOR_NOT_FOUND';
  end if;

  v_definition := regexp_replace(
    v_definition,
    '\(1[[:space:]]*\+[[:space:]]*v_factory\.skill_level[[:space:]]*\*[[:space:]]*0\.02\)',
    '(1 + v_factory.skill_level * 0.04)'
  );
  v_definition := regexp_replace(
    v_definition,
    '\(1[[:space:]]*- [[:space:]]*v_factory\.skill_level[[:space:]]*\*[[:space:]]*0\.015\)',
    '(1 - v_factory.skill_level * 0.025)'
  );

  if v_definition !~ 'v_factory\.skill_level[[:space:]]*\*[[:space:]]*0\.04'
     or v_definition !~ 'v_factory\.skill_level[[:space:]]*\*[[:space:]]*0\.025' then
    raise exception 'FACTORY_SKILL_EFFECT_PATCH_VALIDATION_FAILED';
  end if;

  execute v_definition;
end
$patch$;
