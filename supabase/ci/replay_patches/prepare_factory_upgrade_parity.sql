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

  -- Restore the legacy founding values only in the disposable replay database.
  -- The immutable production migration immediately after this patch upgrades them
  -- to the current sector baselines.
  select pg_get_functiondef('nexora.found_company(text,text,text)'::regprocedure)
    into v_definition;
  v_definition := replace(v_definition,
    'when ''trade'' then v_cost:=1200; v_revenue:=160; v_expense:=30;',
    'when ''trade'' then v_cost:=900; v_revenue:=140; v_expense:=35;');
  v_definition := replace(v_definition,
    'when ''services'' then v_cost:=2200; v_revenue:=220; v_expense:=60;',
    'when ''services'' then v_cost:=1100; v_revenue:=175; v_expense:=45;');
  v_definition := replace(v_definition,
    'when ''logistics'' then v_cost:=3800; v_revenue:=300; v_expense:=85;',
    'when ''logistics'' then v_cost:=1400; v_revenue:=225; v_expense:=60;');
  v_definition := replace(v_definition,
    'when ''manufacturing'' then v_cost:=6000; v_revenue:=410; v_expense:=120;',
    'when ''manufacturing'' then v_cost:=1800; v_revenue:=290; v_expense:=80;');
  v_definition := replace(v_definition,
    'when ''tech'' then v_cost:=9000; v_revenue:=550; v_expense:=160;',
    'when ''tech'' then v_cost:=2200; v_revenue:=365; v_expense:=95;');
  if position('v_cost:=900; v_revenue:=140; v_expense:=35;' in v_definition) = 0 then
    raise exception 'COMPANY_FOUNDING_REPLAY_PRECONDITION_NOT_FOUND';
  end if;
  execute v_definition;
end
$patch$;

-- Normalize the company-vault function's historical formatting for the immutable
-- production migration that follows. This does not change the final business logic;
-- it only makes the precondition text deterministic for the original patch.
do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.upgrade_company_vault(text,text)'::regprocedure)
    into v_definition;

  v_definition := regexp_replace(v_definition,
    'when 1 then v_cost[[:space:]]*:=[[:space:]]*1500;',
    'when 1 then v_cost:=1500;', 'g');
  v_definition := regexp_replace(v_definition,
    'when 2 then v_cost[[:space:]]*:=[[:space:]]*4000;',
    'when 2 then v_cost:=4000;', 'g');
  v_definition := regexp_replace(v_definition,
    'when 3 then v_cost[[:space:]]*:=[[:space:]]*10000;',
    'when 3 then v_cost:=10000;', 'g');
  v_definition := regexp_replace(v_definition,
    'when 4 then v_cost[[:space:]]*:=[[:space:]]*25000;',
    'when 4 then v_cost:=25000;', 'g');

  v_definition := regexp_replace(v_definition,
    'if[[:space:]]+v_target[[:space:]]*<=[[:space:]]*50[[:space:]]+then[[:space:]]*v_duration[[:space:]]*:=[^;]*;[[:space:]]*else[[:space:]]*v_duration[[:space:]]*:=[^;]*;[[:space:]]*end if;',
    'if v_target<=50 then v_duration:=round(2000*power(43200::numeric,(v_target-2)::numeric/48)); else v_duration:=round(86400000*power(15::numeric,(v_target-50)::numeric/50)); end if;',
    'g');

  v_definition := regexp_replace(v_definition,
    'make_interval\(secs[[:space:]]*=>[[:space:]]*greatest\(1,[[:space:]]*v_duration[[:space:]]*/[[:space:]]*1000\)\)',
    'make_interval(secs=>greatest(1,v_duration/2000))',
    'g');

  if position('when 1 then v_cost:=1500;' in v_definition) = 0
     or position('when 4 then v_cost:=25000;' in v_definition) = 0
     or position('v_duration/2000' in v_definition) = 0 then
    raise exception 'COMPANY_VAULT_REPLAY_PRECONDITION_NOT_FOUND';
  end if;

  execute v_definition;
end
$patch$;
