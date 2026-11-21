-- CI-only verifier for the data-free production schema snapshot.
-- This script is run only against a disposable PostgreSQL database.
DO $verify$
DECLARE
  v_tables integer;
  v_functions integer;
  v_security_definer integer;
  v_triggers integer;
  v_indexes integer;
  v_constraints integer;
  v_rls_enabled integer;
  v_rls_disabled integer;
BEGIN
  SELECT count(*) INTO v_tables
  FROM information_schema.tables
  WHERE table_schema = 'nexora' AND table_type = 'BASE TABLE';

  SELECT count(*), count(*) FILTER (WHERE p.prosecdef)
    INTO v_functions, v_security_definer
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'nexora' AND p.prokind = 'f';

  SELECT count(*) INTO v_triggers
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'nexora' AND NOT t.tgisinternal;

  SELECT count(*) INTO v_indexes FROM pg_indexes WHERE schemaname = 'nexora';

  SELECT count(*) INTO v_constraints
  FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
  WHERE n.nspname = 'nexora';

  SELECT count(*) FILTER (WHERE c.relrowsecurity),
         count(*) FILTER (WHERE NOT c.relrowsecurity)
    INTO v_rls_enabled, v_rls_disabled
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'nexora' AND c.relkind = 'r';


  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='nexora.manufacturing_jobs'::regclass)
     OR NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='nexora' AND indexname='company_auctions_company_id_idx')
     OR NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='nexora' AND indexname='company_auctions_factory_id_idx') THEN
    RAISE EXCEPTION 'Manufacturing RLS or auction foreign-key indexes are missing from the production snapshot';
  END IF;

  IF position('ORG_TREASURY_WITHDRAWALS_DISABLED' in pg_get_functiondef('nexora.withdraw_org_treasury(text,text,bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'Organization treasury withdrawals are not disabled in the production snapshot';
  END IF;

  IF position('v_cost:=320; v_xp:=16; v_required:=2' in pg_get_functiondef('nexora.manufacture_recipe(text,text,integer)'::regprocedure)) = 0
     OR position('v_cost:=60; v_xp:=18; v_required:=3' in pg_get_functiondef('nexora.manufacture_recipe(text,text,integer)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'Biotechnology manufacturing recipe is not canonical in the production snapshot';
  END IF;

  IF position('least(80,floor(v_payout/15)::integer)' in pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)) = 0
     OR position('reputation=reputation+' in pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)) > 0
     OR position('influence=influence+' in pg_get_functiondef('nexora.collect_company_revenue(text,text)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'Company revenue rewards are not proportional to the actual payout';
  END IF;

  IF position('upgrade_not_finished' in lower(pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure))) = 0
     OR position('warehouse_upgrade_target_level' in lower(pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure))) = 0
     OR position('upgrade_not_finished' in lower(pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)'::regprocedure))) = 0
     OR position('upgrade_target_level' in lower(pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)'::regprocedure))) = 0 THEN
    RAISE EXCEPTION 'Factory or warehouse upgrade double-charge guards are missing';
  END IF;

  IF NOT EXISTS (
       SELECT 1 FROM pg_trigger
       WHERE tgrelid='nexora.contract_offers'::regclass
         AND tgname='contract_offers_lock_active_org_claim'
         AND NOT tgisinternal
     )
     OR position('pg_advisory_xact_lock' in pg_get_functiondef('nexora.lock_active_org_contract_claim()'::regprocedure)) = 0
     OR position('raise exception ''ORG_ACTIVE_CONTRACT_LIMIT''' in pg_get_functiondef('nexora.lock_active_org_contract_claim()'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'Concurrent organization contract claim protection is missing';
  END IF;

  IF position('0.046::numeric' in pg_get_functiondef('nexora.factory_progression_multiplier(text,integer)'::regprocedure)) = 0
     OR position('0.028::numeric' in pg_get_functiondef('nexora.factory_progression_multiplier(text,integer)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'Resource-specific factory progression curves are missing from the production snapshot';
  END IF;

  IF v_tables <> 46
     OR v_functions <> 152
     OR v_security_definer <> 139
     OR v_triggers <> 41
     OR v_indexes <> 102
     OR v_constraints <> 169
     OR v_rls_enabled <> 46
     OR v_rls_disabled <> 0 THEN
    RAISE EXCEPTION
      'Production schema snapshot mismatch: tables %, functions %, SECURITY DEFINER %, triggers %, indexes %, constraints %, RLS enabled %, RLS disabled %',
      v_tables, v_functions, v_security_definer, v_triggers, v_indexes, v_constraints, v_rls_enabled, v_rls_disabled;
  END IF;
END
$verify$;
