-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118151655
-- Remote migration name: 20261118151500_harden_player_rpc_schema
-- Source: Supabase postgres_logs at 2026-11-18 15:16:55 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

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
;
