-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118222810
-- Remote migration name: nova_factory_pause_sync_fix
-- Source: Supabase postgres_logs at 2026-11-18 22:28:10 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.set_factory_active(p_uid text,p_factory_id text,p_active boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_factory nexora.factories%rowtype;
begin
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;

  -- Bank any accrued production before pausing so the last active interval is not lost.
  if not coalesce(p_active,false) and v_factory.is_active then
    perform nexora.sync_factory_production(p_uid,p_factory_id);
  end if;

  update nexora.factories
    set is_active=coalesce(p_active,false),last_produced_at=now(),updated_at=now()
    where id=p_factory_id;
  return jsonb_build_object('ok',true,'is_active',coalesce(p_active,false));
end $$;

revoke all on function nexora.set_factory_active(text,text,boolean) from public,anon,authenticated;
grant execute on function nexora.set_factory_active(text,text,boolean) to service_role;;
