-- Restore the canonical biotechnology recipe after the legacy hidden-recipe
-- removal accidentally left its assignments appended to this recipe branch.
-- This changes only the server-side recipe definition; no player data is rewritten.
do $patch$
declare
  v_definition text;
  v_replacement text := $branch$when 'rec_biotech_module' then v_output:='bio_module'; v_output_qty:=1; v_cost:=320; v_xp:=16; v_required:=2; v_inputs:='[{"itemId":"biotech_gel","qty":2},{"itemId":"quantum_dust","qty":1}]'::jsonb;$branch$;
begin
  select pg_get_functiondef('nexora.manufacture_recipe(text,text,integer)'::regprocedure)
    into v_definition;

  if v_definition is null then
    raise exception 'MANUFACTURE_RECIPE_FUNCTION_MISSING';
  end if;

  if position('when ''rec_biotech_module'' then' in v_definition) = 0 then
    raise exception 'BIOTECH_RECIPE_BRANCH_MISSING';
  end if;

  -- Replace the complete branch line, not a partial SQL fragment. The previous
  -- patch removed the next WHEN branch but left its assignments on this line.
  v_definition := regexp_replace(
    v_definition,
    E'when ''rec_biotech_module'' then[^\\n]*',
    v_replacement,
    'g'
  );

  if position(
    'v_cost:=320; v_xp:=16; v_required:=2; v_inputs:=' ||
    quote_literal('[{"itemId":"biotech_gel","qty":2},{"itemId":"quantum_dust","qty":1}]') ||
    '::jsonb;'
    in v_definition
  ) = 0 then
    raise exception 'BIOTECH_RECIPE_CANONICAL_BRANCH_NOT_RESTORED';
  end if;

  if position('v_cost:=60; v_xp:=18; v_required:=3' in v_definition) > 0 then
    raise exception 'HIDDEN_RECIPE_ASSIGNMENTS_STILL_PRESENT';
  end if;

  execute v_definition;
end
$patch$;
