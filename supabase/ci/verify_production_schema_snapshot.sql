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

  IF v_tables <> 46
     OR v_functions <> 149
     OR v_security_definer <> 136
     OR v_triggers <> 38
     OR v_indexes <> 100
     OR v_constraints <> 169
     OR v_rls_enabled <> 45
     OR v_rls_disabled <> 1 THEN
    RAISE EXCEPTION
      'Production schema snapshot mismatch: tables %, functions %, SECURITY DEFINER %, triggers %, indexes %, constraints %, RLS enabled %, RLS disabled %',
      v_tables, v_functions, v_security_definer, v_triggers, v_indexes, v_constraints, v_rls_enabled, v_rls_disabled;
  END IF;
END
$verify$;
