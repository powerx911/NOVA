-- Remove a legacy hidden recipe that duplicated the quantum-server output.
-- The supported recipe catalog contains exactly one quantum-server recipe.
do $patch$
declare
  v_definition text;
begin
  select pg_get_functiondef('nexora.manufacture_recipe(text,text,integer)'::regprocedure)
    into v_definition;

  if position('rec_quantum_server_advanced' in v_definition)=0 then
    raise notice 'Legacy advanced quantum-server recipe is already absent';
    return;
  end if;

  v_definition := regexp_replace(
    v_definition,
    E'\\s*when ''rec_quantum_server_advanced'' then[^;]*;',
    '',
    'g'
  );

  if position('rec_quantum_server_advanced' in v_definition)>0 then
    raise exception 'LEGACY_QUANTUM_SERVER_RECIPE_STILL_PRESENT';
  end if;

  if position('when ''rec_quantum_server'' then' in v_definition)=0
     or position('when ''rec_biotech_module'' then' in v_definition)=0 then
    raise exception 'SUPPORTED_RECIPE_BRANCHES_MISSING';
  end if;

  execute v_definition;
end
$patch$;
