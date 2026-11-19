-- RECOVERED UNTRACKED SQL EXECUTION — NOT A MIGRATION LEDGER ENTRY
-- PostgreSQL log timestamp: 2026-11-18 18:01:44 UTC
-- Source: postgres_logs client-backend statement event; POST /mcp metadata stripped.
-- Recovered 2026-11-19. SQL body preserved as logged.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.sync_self_org_membership(p_uid text,p_org_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_member nexora.organization_members%rowtype;
begin
 if p_org_id is null then
  select * into v_member from nexora.organization_members where user_id=p_uid for update;
  if found then
   if v_member.role='leader' then raise exception 'LEADER_CANNOT_LEAVE';end if;
   delete from nexora.organization_members where org_id=v_member.org_id and user_id=p_uid;
   update nexora.organizations set member_count=greatest(1,member_count-1),updated_at=now() where id=v_member.org_id;
  end if;
  update nexora.player_profiles set org_id=null,updated_at=now() where user_id=p_uid;
 else
  select * into v_member from nexora.organization_members where user_id=p_uid and org_id=p_org_id;
  if not found then raise exception 'NOT_ORG_MEMBER';end if;
  update nexora.player_profiles set org_id=p_org_id,updated_at=now() where user_id=p_uid;
 end if;
 return jsonb_build_object('ok',true);
end;$$;
revoke all on function nexora.sync_self_org_membership(text,text) from public,anon,authenticated;
grant execute on function nexora.sync_self_org_membership(text,text) to service_role;
