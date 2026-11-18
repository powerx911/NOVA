-- Keep privileged game commands outside the exposed public API schema.
create schema if not exists private;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter function public.nova_initialize_player(text) set schema private;
alter function public.nova_upgrade_building(uuid, uuid) set schema private;

revoke all on function private.nova_initialize_player(text) from public, anon;
revoke all on function private.nova_upgrade_building(uuid, uuid) from public, anon;
grant execute on function private.nova_initialize_player(text) to authenticated;
grant execute on function private.nova_upgrade_building(uuid, uuid) to authenticated;

-- Public RPC entry points run as the caller. Their only purpose is to delegate to
-- narrowly scoped private functions that validate auth.uid() and own all mutations.
create or replace function public.nova_initialize_player(p_display_name text)
returns jsonb
language sql
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.nova_initialize_player(p_display_name);
$$;

create or replace function public.nova_upgrade_building(
  p_command_id uuid,
  p_building_id uuid
)
returns jsonb
language sql
security invoker
set search_path = pg_catalog, public, private
as $$
  select private.nova_upgrade_building(p_command_id, p_building_id);
$$;

revoke all on function public.nova_initialize_player(text) from public, anon;
revoke all on function public.nova_upgrade_building(uuid, uuid) from public, anon;
grant execute on function public.nova_initialize_player(text) to authenticated;
grant execute on function public.nova_upgrade_building(uuid, uuid) to authenticated;
