-- RECOVERED UNTRACKED SQL EXECUTION — NOT A MIGRATION LEDGER ENTRY
-- PostgreSQL log timestamp: 2026-11-18 17:57:49 UTC
-- Source: postgres_logs client-backend statement event; POST /mcp metadata stripped.
-- Recovered 2026-11-19. SQL body preserved as logged.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.request_join_organization(p_uid text,p_org_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_profile nexora.player_profiles%rowtype;v_org nexora.organizations%rowtype;v_id text:='req_'||gen_random_uuid()::text;
begin
 select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
 if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if v_profile.org_id is not null then raise exception 'ALREADY_IN_ORG';end if;
 select * into v_org from nexora.organizations where id=p_org_id;
 if not found then raise exception 'NOT_FOUND';end if;
 if exists(select 1 from nexora.organization_requests where org_id=p_org_id and user_id=p_uid and status='pending') then raise exception 'REQUEST_ALREADY_PENDING';end if;
 insert into nexora.organization_requests(id,org_id,user_id,username,status) values(v_id,p_org_id,p_uid,v_profile.username,'pending');
 return jsonb_build_object('ok',true,'request_id',v_id);
end;$$;

create or replace function nexora.handle_org_join_request(p_actor_uid text,p_org_id text,p_request_id text,p_decision text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_req nexora.organization_requests%rowtype;v_org nexora.organizations%rowtype;v_actor nexora.organization_members%rowtype;v_profile nexora.player_profiles%rowtype;v_capacity integer;
begin
 if p_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION';end if;
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_actor from nexora.organization_members where org_id=p_org_id and user_id=p_actor_uid;
 if not found or not (v_actor.permissions ? 'manage_members') then raise exception 'UNAUTHORIZED';end if;
 select * into v_req from nexora.organization_requests where id=p_request_id and org_id=p_org_id for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if v_req.status<>'pending' then raise exception 'REQUEST_ALREADY_HANDLED';end if;
 if p_decision='approved' then
  select * into v_profile from nexora.player_profiles where user_id=v_req.user_id for update;
  if not found then raise exception 'NOT_FOUND';end if;
  if v_profile.org_id is not null then raise exception 'APPLICANT_IN_OTHER_ORG';end if;
  if exists(select 1 from nexora.organization_members where org_id=p_org_id and user_id=v_req.user_id) then raise exception 'ALREADY_ORG_MEMBER';end if;
  v_capacity:=coalesce(nullif(v_org.member_capacity,0),least(70,20+(greatest(1,v_org.level)-1)*5));
  if v_org.member_count>=v_capacity then raise exception 'ORG_FULL';end if;
  insert into nexora.organization_members(org_id,user_id,username,role,permissions) values(p_org_id,v_req.user_id,v_req.username,'member','[]'::jsonb);
  update nexora.player_profiles set org_id=p_org_id,updated_at=now() where user_id=v_req.user_id;
  update nexora.organizations set member_count=member_count+1,updated_at=now() where id=p_org_id;
 end if;
 update nexora.organization_requests set status=p_decision,updated_at=now() where id=p_request_id;
 return jsonb_build_object('ok',true);
end;$$;

create or replace function nexora.update_org_member_role(p_actor_uid text,p_org_id text,p_target_uid text,p_role text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor nexora.organization_members%rowtype;v_target nexora.organization_members%rowtype;v_aw integer;v_tw integer;v_perms jsonb;
begin
 if p_role not in ('deputy','officer','member') then raise exception 'INVALID_ROLE';end if;
 select * into v_actor from nexora.organization_members where org_id=p_org_id and user_id=p_actor_uid;
 select * into v_target from nexora.organization_members where org_id=p_org_id and user_id=p_target_uid for update;
 if not found or v_actor.user_id is null then raise exception 'NOT_FOUND';end if;
 if not (v_actor.permissions ? 'manage_roles') then raise exception 'UNAUTHORIZED';end if;
 v_aw:=case v_actor.role when 'leader' then 4 when 'deputy' then 3 when 'officer' then 2 else 1 end;
 v_tw:=case v_target.role when 'leader' then 4 when 'deputy' then 3 when 'officer' then 2 else 1 end;
 if v_aw<=v_tw then raise exception 'RANK_TOO_HIGH';end if;
 v_perms:=case p_role when 'deputy' then '["manage_members","manage_roles","manage_treasury"]'::jsonb when 'officer' then '["manage_members"]'::jsonb else '[]'::jsonb end;
 update nexora.organization_members set role=p_role,permissions=v_perms where org_id=p_org_id and user_id=p_target_uid;
 return jsonb_build_object('ok',true);
end;$$;

create or replace function nexora.leave_organization(p_uid text,p_org_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_member nexora.organization_members%rowtype;
begin
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role='leader' then raise exception 'LEADER_CANNOT_LEAVE';end if;
 delete from nexora.organization_members where org_id=p_org_id and user_id=p_uid;
 update nexora.organizations set member_count=greatest(1,member_count-1),updated_at=now() where id=p_org_id;
 update nexora.player_profiles set org_id=null,updated_at=now() where user_id=p_uid and org_id=p_org_id;
 return jsonb_build_object('ok',true);
end;$$;

create or replace function nexora.kick_org_member(p_actor_uid text,p_org_id text,p_target_uid text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor nexora.organization_members%rowtype;v_target nexora.organization_members%rowtype;v_aw integer;v_tw integer;
begin
 if p_actor_uid=p_target_uid then raise exception 'CANNOT_KICK_SELF';end if;
 select * into v_actor from nexora.organization_members where org_id=p_org_id and user_id=p_actor_uid;
 select * into v_target from nexora.organization_members where org_id=p_org_id and user_id=p_target_uid for update;
 if not found or v_actor.user_id is null then raise exception 'NOT_FOUND';end if;
 if not (v_actor.permissions ? 'manage_members') then raise exception 'UNAUTHORIZED';end if;
 v_aw:=case v_actor.role when 'leader' then 4 when 'deputy' then 3 when 'officer' then 2 else 1 end;
 v_tw:=case v_target.role when 'leader' then 4 when 'deputy' then 3 when 'officer' then 2 else 1 end;
 if v_aw<=v_tw then raise exception 'RANK_TOO_HIGH';end if;
 delete from nexora.organization_members where org_id=p_org_id and user_id=p_target_uid;
 update nexora.organizations set member_count=greatest(1,member_count-1),updated_at=now() where id=p_org_id;
 update nexora.player_profiles set org_id=null,updated_at=now() where user_id=p_target_uid and org_id=p_org_id;
 return jsonb_build_object('ok',true);
end;$$;

create or replace function nexora.deposit_org_treasury(p_uid text,p_org_id text,p_amount bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_wallet nexora.wallets%rowtype;v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_tx text:='tx_'||gen_random_uuid()::text;v_otx text:='otx_'||gen_random_uuid()::text;v_username text;
begin
 if p_amount<=0 or p_amount>10000000 then raise exception 'INVALID_AMOUNT';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'UNAUTHORIZED';end if;
 if v_wallet.balance<p_amount then raise exception 'INSUFFICIENT_FUNDS';end if;
 update nexora.wallets set balance=balance-p_amount,total_spent=total_spent+p_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 update nexora.organizations set treasury_balance=treasury_balance+p_amount,reputation=reputation+greatest(1,floor((p_amount/100.0)*(1+least(10,coalesce((research->>'diplomacy')::integer,0))*.01))::bigint),updated_at=now() where id=p_org_id;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status) values(v_tx,p_uid,'ORG',p_amount,0,p_amount,'org_deposit',p_org_id,'Org treasury deposit ['||v_org.tag||']','completed');
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note) values(v_otx,p_org_id,p_uid,v_member.username,'deposit',p_amount,'Deposit by '||v_member.username);
 return jsonb_build_object('ok',true);
end;$$;

create or replace function nexora.withdraw_org_treasury(p_uid text,p_org_id text,p_amount bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_wallet nexora.wallets%rowtype;v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_tx text:='tx_'||gen_random_uuid()::text;v_otx text:='otx_'||gen_random_uuid()::text;
begin
 if p_amount<=0 or p_amount>10000000 then raise exception 'INVALID_AMOUNT';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;
 if not found or not (v_member.permissions ? 'manage_treasury') then raise exception 'UNAUTHORIZED';end if;
 if v_org.treasury_balance<p_amount then raise exception 'INSUFFICIENT_TREASURY';end if;
 update nexora.wallets set balance=balance+p_amount,total_earned=total_earned+p_amount,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 update nexora.organizations set treasury_balance=treasury_balance-p_amount,updated_at=now() where id=p_org_id;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status) values(v_tx,'ORG',p_uid,p_amount,0,p_amount,'org_withdraw',p_org_id,'Org treasury withdrawal ['||v_org.tag||']','completed');
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note) values(v_otx,p_org_id,p_uid,v_member.username,'withdraw',p_amount,'Withdrawal by '||v_member.username);
 return jsonb_build_object('ok',true);
end;$$;

create or replace function nexora.get_org_pending_requests(p_org_id text,p_uid text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_member nexora.organization_members%rowtype;v_result jsonb;
begin
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;
 if not found or not (v_member.permissions ? 'manage_members') then raise exception 'UNAUTHORIZED';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'orgId',org_id,'uid',user_id,'username',username,'status',status,'createdAt',created_at) order by created_at),'[]'::jsonb)
 into v_result from nexora.organization_requests where org_id=p_org_id and status='pending';
 return v_result;
end;$$;

do $$ declare f record; begin
 for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='nexora' and p.proname in ('request_join_organization','handle_org_join_request','update_org_member_role','leave_organization','kick_org_member','deposit_org_treasury','withdraw_org_treasury','get_org_pending_requests')
 loop execute format('revoke all on function %s from public,anon,authenticated',f.sig); execute format('grant execute on function %s to service_role',f.sig); end loop;
end $$;
