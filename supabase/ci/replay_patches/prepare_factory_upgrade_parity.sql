-- CI-only precondition normalizer for replaying the historical production migration.
-- The production 20261120234000 migration expects the pre-parity factory-upgrade
-- formulas. Earlier recovered SQL can leave a semantically equivalent but different
-- formula in the disposable replay database. Restore the exact old expressions so the
-- unmodified production migration can apply and the final schema matches production.
do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure)
    into v_definition;

  v_definition := regexp_replace(
    v_definition,
    'v_cost[[:space:]]*:=[^;]*;',
    'v_cost:=ceil(v_cfg.founding_cost*0.18*power(v_factory.level::numeric,1.25))::bigint;',
    'g'
  );
  v_definition := regexp_replace(
    v_definition,
    'v_duration_seconds[[:space:]]*:=([^;]*);',
    'v_duration_seconds:=120*power(720::numeric,(v_target-2)::numeric/98);',
    'g'
  );

  if position('v_cost:=ceil(v_cfg.founding_cost*0.18*power(v_factory.level::numeric,1.25))::bigint;' in v_definition)=0
     or position('v_duration_seconds:=120*power(720::numeric,(v_target-2)::numeric/98);' in v_definition)=0 then
    raise notice 'Factory upgrade replay precondition function: %', v_definition;
    raise exception 'FACTORY_UPGRADE_REPLAY_PRECONDITION_NOT_FOUND';
  end if;

  execute v_definition;

  -- Normalize the guarded factory production function to the exact precondition
  -- expected by the immutable production migration. The migration itself then
  -- performs the final 0.025 -> 0.018 adjustment.
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure)
    into v_definition;
  v_definition := regexp_replace(
    v_definition,
    'v_expense[[:space:]]*:=[^;]*;',
    'v_expense:=v_cfg.operating_cost*(1+greatest(0,v_factory.level-1)*0.025)*(1-v_factory.skill_level*0.005);',
    'g'
  );
  if position('greatest(0,v_factory.level-1)*0.025' in v_definition) = 0 then
    raise exception 'FACTORY_OPERATING_REPLAY_PRECONDITION_NOT_FOUND';
  end if;
  execute v_definition;
end
$patch$;
