-- Prevent a second factory or warehouse upgrade charge until the pending upgrade is completed.
-- An elapsed timer is still pending until its completion RPC clears every state marker.
do $patch$
declare
  v_definition text;
  v_owner_check text := $owner$if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;$owner$;
  v_owner_pattern text := 'if[[:space:]]+v_factory\.owner_uid[[:space:]]*<>[[:space:]]*p_uid[[:space:]]+then[[:space:]]+raise[[:space:]]+exception[[:space:]]+''UNAUTHORIZED'';[[:space:]]+end[[:space:]]+if;';
  v_new_guard text := $guard$if v_factory.upgrade_started_at is not null
    or v_factory.upgrade_ends_at is not null
    or v_factory.upgrade_target_level is not null
    or v_factory.warehouse_upgrade_started_at is not null
    or v_factory.warehouse_upgrade_ends_at is not null
    or v_factory.warehouse_upgrade_target_level is not null then
    raise exception 'UPGRADE_NOT_FINISHED';
  end if;$guard$;
begin
  select pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure)
    into v_definition;
  if position(v_new_guard in v_definition) = 0 then
    if v_definition !~ v_owner_pattern then
      raise exception 'FACTORY_UPGRADE_OWNER_CHECK_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := regexp_replace(v_definition, v_owner_pattern, v_owner_check || E'\n  ' || v_new_guard, 'g');
  end if;
  execute v_definition;

  select pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)'::regprocedure)
    into v_definition;
  if position(v_new_guard in v_definition) = 0 then
    if v_definition !~ v_owner_pattern then
      raise exception 'FACTORY_WAREHOUSE_OWNER_CHECK_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := regexp_replace(v_definition, v_owner_pattern, v_owner_check || E'\n  ' || v_new_guard, 'g');
  end if;
  execute v_definition;

  if position('UPGRADE_NOT_FINISHED' in pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure)) = 0
     or position('warehouse_upgrade_target_level' in pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure)) = 0
     or position('UPGRADE_NOT_FINISHED' in pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)'::regprocedure)) = 0
     or position('upgrade_target_level' in pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)'::regprocedure)) = 0 then
    raise exception 'FACTORY_UPGRADE_PENDING_GUARD_VALIDATION_FAILED';
  end if;
end
$patch$;
