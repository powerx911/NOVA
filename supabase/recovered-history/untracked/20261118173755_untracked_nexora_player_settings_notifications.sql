-- RECOVERED UNTRACKED SQL EXECUTION — NOT A MIGRATION LEDGER ENTRY
-- PostgreSQL log timestamp: 2026-11-18 17:37:55 UTC
-- Source: postgres_logs client-backend statement event; POST /mcp metadata stripped.
-- Recovered 2026-11-19. SQL body preserved as logged.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.update_player_settings(p_uid text,p_language text,p_notifications_enabled boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_language not in ('ar','en') then raise exception 'INVALID_LANGUAGE'; end if;
  update nexora.player_private set language=p_language,notifications_enabled=p_notifications_enabled,updated_at=now() where user_id=p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function nexora.update_player_avatar(p_uid text,p_avatar_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_avatar_id is null or length(p_avatar_id)<1 or length(p_avatar_id)>64 then raise exception 'INVALID_AVATAR'; end if;
  update nexora.player_profiles set avatar_id=p_avatar_id,updated_at=now() where user_id=p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function nexora.mark_notification_read(p_uid text,p_notification_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  update nexora.notifications set is_read=true where id=p_notification_id and user_id=p_uid;
  if not found then raise exception 'NOTIFICATION_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function nexora.mark_all_notifications_read(p_uid text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  update nexora.notifications set is_read=true where user_id=p_uid and is_read=false;
  get diagnostics v_count = row_count;
  return jsonb_build_object('ok',true,'updated',v_count);
end;
$$;

revoke all on function nexora.update_player_settings(text,text,boolean) from public,anon,authenticated;
revoke all on function nexora.update_player_avatar(text,text) from public,anon,authenticated;
revoke all on function nexora.mark_notification_read(text,text) from public,anon,authenticated;
revoke all on function nexora.mark_all_notifications_read(text) from public,anon,authenticated;
grant execute on function nexora.update_player_settings(text,text,boolean) to service_role;
grant execute on function nexora.update_player_avatar(text,text) to service_role;
grant execute on function nexora.mark_notification_read(text,text) to service_role;
grant execute on function nexora.mark_all_notifications_read(text) to service_role;
