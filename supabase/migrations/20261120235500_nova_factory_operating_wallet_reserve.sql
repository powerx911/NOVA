-- Protect a 300-credit operating reserve while preserving the current
-- resource-specific production curve and the 1.8% operating-cost progression.

do $patch$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('nexora.sync_factory_production(text,text)'::regprocedure)
    into v_definition;

  if position('v_min_balance constant bigint := 300;' in v_definition) > 0 then
    raise notice 'Factory operating reserve already present; migration is idempotent';
    return;
  end if;

  v_old := '  v_funds_exhausted boolean := false;' || E'\n';
  v_new := v_old
    || '  v_min_balance constant bigint := 300;' || E'\n'
    || '  v_available numeric;' || E'\n';
  if position(v_old in v_definition) = 0 then
    raise exception 'FACTORY_RESERVE_DECLARATION_ANCHOR_NOT_FOUND';
  end if;
  v_definition := replace(v_definition, v_old, v_new);

  v_old := 'set is_active=(v_wallet.balance>coalesce(v_factory.operating_cost_remainder,0))';
  v_new := 'set is_active=(v_wallet.balance>v_min_balance+coalesce(v_factory.operating_cost_remainder,0))';
  if position(v_old in v_definition) = 0 then
    raise exception 'FACTORY_RESERVE_IDLE_UPDATE_ANCHOR_NOT_FOUND';
  end if;
  v_definition := replace(v_definition, v_old, v_new);

  v_old := '''is_active'',(v_wallet.balance>coalesce(v_factory.operating_cost_remainder,0))';
  v_new := '''is_active'',(v_wallet.balance>v_min_balance+coalesce(v_factory.operating_cost_remainder,0)),''minimum_balance'',v_min_balance';
  if position(v_old in v_definition) = 0 then
    raise exception 'FACTORY_RESERVE_IDLE_RESPONSE_ANCHOR_NOT_FOUND';
  end if;
  v_definition := replace(v_definition, v_old, v_new);

  v_old := $old$
  v_desired_hours:=least(v_elapsed,greatest(0,(v_space-v_factory.production_remainder)/v_rate));
  v_hours:=v_desired_hours;
  v_raw_cost:=coalesce(v_factory.operating_cost_remainder,0)+v_expense*v_hours;
  v_cost:=floor(v_raw_cost)::bigint;
  if v_raw_cost>=v_wallet.balance and v_raw_cost>0 then
    v_hours:=greatest(0,(v_wallet.balance-coalesce(v_factory.operating_cost_remainder,0))/v_expense);
    v_hours:=least(v_hours,v_desired_hours);
    v_cost:=v_wallet.balance;
    v_cost_remainder:=0;
    v_funds_exhausted:=true;
  else
    v_cost_remainder:=v_raw_cost-v_cost;
  end if;
$old$;

  v_new := $new$
  v_desired_hours:=least(v_elapsed,greatest(0,(v_space-v_factory.production_remainder)/v_rate));
  v_available:=greatest(0,v_wallet.balance-v_min_balance-coalesce(v_factory.operating_cost_remainder,0));
  if v_expense>0 and v_available < v_expense*v_desired_hours then
    v_hours:=least(v_desired_hours,v_available/v_expense);
    v_funds_exhausted:=true;
  else
    v_hours:=v_desired_hours;
  end if;
  v_raw_cost:=coalesce(v_factory.operating_cost_remainder,0)+v_expense*v_hours;
  v_cost:=floor(v_raw_cost)::bigint;
  v_cost_remainder:=v_raw_cost-v_cost;
$new$;

  if position(v_old in v_definition) = 0 then
    raise exception 'FACTORY_RESERVE_COST_BLOCK_ANCHOR_NOT_FOUND';
  end if;
  v_definition := replace(v_definition, v_old, v_new);

  v_old := $old$
  update nexora.factories
  set warehouse_qty=warehouse_qty+v_qty,
      production_remainder=v_production_remainder,
      operating_cost_remainder=v_cost_remainder,
      is_active=not v_funds_exhausted,
      last_produced_at=now(),updated_at=now()
  where id=p_factory_id;
$old$;
  v_new := $new$
  v_funds_exhausted:=v_funds_exhausted or (v_wallet.balance-v_cost<=v_min_balance);

  update nexora.factories
  set warehouse_qty=warehouse_qty+v_qty,
      production_remainder=v_production_remainder,
      operating_cost_remainder=v_cost_remainder,
      is_active=not v_funds_exhausted,
      last_produced_at=now(),updated_at=now()
  where id=p_factory_id;
$new$;

  if position(v_old in v_definition) = 0 then
    raise exception 'FACTORY_RESERVE_FINAL_STATE_ANCHOR_NOT_FOUND';
  end if;
  v_definition := replace(v_definition, v_old, v_new);

  v_old := '''is_active'',not v_funds_exhausted';
  v_new := '''is_active'',not v_funds_exhausted,''minimum_balance'',v_min_balance';
  if position(v_old in v_definition) = 0 then
    raise exception 'FACTORY_RESERVE_FINAL_RESPONSE_ANCHOR_NOT_FOUND';
  end if;
  v_definition := replace(v_definition, v_old, v_new);

  if position('v_min_balance constant bigint := 300;' in v_definition)=0
     or position('v_available:=greatest(0,v_wallet.balance-v_min_balance' in v_definition)=0
     or position('0.018' in v_definition)=0
     or position('factory_progression_multiplier' in v_definition)=0 then
    raise exception 'FACTORY_RESERVE_FINAL_VALIDATION_FAILED';
  end if;

  execute v_definition;
end
$patch$;
