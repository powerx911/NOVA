-- Calibrate the convex factory curve so each upgrade adds more output than the prior one
-- without letting level 100 exceed ~3.96x the resource-specific starting rate (before skills).
do $migration$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure)
    into v_definition;

  if position('0.025*greatest(0,v_factory.level-1)' in v_definition) = 0
     or position('0.00015*power(greatest(0,v_factory.level-1)::numeric,2)' in v_definition) = 0 then
    raise exception 'FACTORY_PROGRESSION_CURVE_SOURCE_NOT_FOUND';
  end if;

  v_definition := replace(
    v_definition,
    '0.025*greatest(0,v_factory.level-1)',
    '0.018*greatest(0,v_factory.level-1)'
  );
  v_definition := replace(
    v_definition,
    '0.00015*power(greatest(0,v_factory.level-1)::numeric,2)',
    '0.00012*power(greatest(0,v_factory.level-1)::numeric,2)'
  );

  if position('0.018*greatest(0,v_factory.level-1)' in v_definition) = 0
     or position('0.00012*power(greatest(0,v_factory.level-1)::numeric,2)' in v_definition) = 0 then
    raise exception 'FACTORY_PROGRESSION_CURVE_CALIBRATION_FAILED';
  end if;

  execute v_definition;
end
$migration$;
