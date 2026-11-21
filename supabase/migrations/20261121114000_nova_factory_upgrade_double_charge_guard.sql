-- Prevent a second factory or warehouse upgrade charge until the pending upgrade is completed.
-- An elapsed timer is still pending until its completion RPC clears the state markers.
do $patch$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('nexora.upgrade_factory(text,text)'::regprocedure)
    into v_definition;

  v_old := $old$if v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS'; end if;$old$;
  v_new := $new$if v_factory.upgrade_started_at is not null
    or v_factory.upgrade_ends_at is not null
    or v_factory.upgrade_target_level is not null
    or v_factory.warehouse_upgrade_started_at is not null
    or v_factory.warehouse_upgrade_ends_at is not null
    or v_factory.warehouse_upgrade_target_level is not null then
    raise exception 'UPGRADE_NOT_FINISHED';
  end if;$new$;

  if position(v_new in v_definition) = 0 then
    if position(v_old in v_definition) = 0 then
      raise exception 'FACTORY_UPGRADE_PENDING_GUARD_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_old, v_new);
  end if;
  execute v_definition;

  select pg_get_functiondef('nexora.upgrade_factory_warehouse(text,text)'::regprocedure)
    into v_definition;

  v_old := $old$if v_factory.warehouse_upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;
  if v_factory.upgrade_ends_at is not null then raise exception 'UPGRADE_NOT_FINISHED'; end if;$old$;
  v_new := $new$if v_factory.warehouse_upgrade_started_at is not null
     or v_factory.warehouse_upgrade_ends_at is not null
     or v_factory.warehouse_upgrade_target_level is not null
     or v_factory.upgrade_started_at is not null
     or v_factory.upgrade_ends_at is not null
     or v_factory.upgrade_target_level is not null then
    raise exception 'UPGRADE_NOT_FINISHED';
  end if;$new$;

  if position(v_new in v_definition) = 0 then
    if position(v_old in v_definition) = 0 then
      raise exception 'FACTORY_WAREHOUSE_PENDING_GUARD_PATCH_ANCHOR_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_old, v_new);
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
