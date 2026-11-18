create or replace function nexora.create_organization(p_uid text,p_name text,p_tag text,p_description text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_profile nexora.player_profiles%rowtype;v_wallet nexora.wallets%rowtype;v_id text:='org_'||gen_random_uuid()::text;v_tx text:='tx_'||gen_random_uuid()::text;v_xp bigint;v_level integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_leadership numeric;
begin
 if p_name is null or length(btrim(p_name))<3 or length(btrim(p_name))>40 then raise exception 'INVALID_NAME';end if;
 if p_tag is null or length(btrim(p_tag))<2 or length(btrim(p_tag))>6 or btrim(p_tag)!~'^[A-Z0-9]+$' then raise exception 'INVALID_TAG';end if;
 select * into v_profile from nexora.player_profiles where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if v_profile.org_id is not null then raise exception 'ALREADY_IN_ORG';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if v_wallet.balance<1000 then raise exception 'INSUFFICIENT_FUNDS';end if;
 insert into nexora.organizations(id,name,tag,description,leader_uid,leader_name,treasury_balance,member_count,reputation,level,member_capacity,join_mode,research)
 values(v_id,btrim(p_name),btrim(p_tag),left(coalesce(btrim(p_description),''),240),p_uid,v_profile.username,0,1,15,1,20,'request','{}'::jsonb);
 insert into nexora.organization_members(org_id,user_id,username,role,permissions)
 values(v_id,p_uid,v_profile.username,'leader','["manage_members","manage_roles","manage_treasury","manage_org"]'::jsonb);
 update nexora.wallets set balance=balance-1000,total_spent=total_spent+1000,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
 values(v_tx,p_uid,'SYSTEM',1000,0,1000,'org_create',v_id,'Founded organization ['||btrim(p_tag)||'] '||btrim(p_name),'completed');
 v_xp:=v_profile.xp+150;v_remaining:=v_xp;
 while v_level<200 loop v_step:=200+(v_level-1)*120;exit when v_remaining<v_step;v_remaining:=v_remaining-v_step;v_level:=v_level+1;end loop;
 v_gained:=greatest(0,v_level-v_profile.level);v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*.1;
 update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,
  reputation=reputation+round(20*v_leadership)::bigint,influence=influence+round(25*v_leadership)::bigint,org_id=v_id,updated_at=now()
 where user_id=p_uid;
 return jsonb_build_object('ok',true,'org_id',v_id);
exception when unique_violation then raise exception 'TAG_TAKEN';
end;$$;

create or replace function nexora.start_organization_upgrade(p_uid text,p_org_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_cost bigint;v_level integer;v_finance numeric;v_engineering numeric;v_duration numeric;v_target integer;v_end timestamptz;v_tx text:='org_upgrade_'||gen_random_uuid()::text;
begin
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role not in ('leader','deputy') then raise exception 'UNAUTHORIZED';end if;
 if v_org.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS';end if;
 v_level:=greatest(1,v_org.level);if v_level>=10 then raise exception 'MAX_LEVEL';end if;
 v_finance:=least(10,greatest(0,coalesce((v_org.research->>'finance')::numeric,0)));
 v_engineering:=least(10,greatest(0,coalesce((v_org.research->>'engineering')::numeric,0)));
 v_cost:=round(12000*v_level*v_level*(1-v_finance*.005));if v_org.treasury_balance<v_cost then raise exception 'INSUFFICIENT_TREASURY';end if;
 v_target:=v_level+1;v_duration:=round(8*60*60*1000*power(1.5::numeric,greatest(0,v_target-2))*(1-v_engineering*.005));
 v_end:=now()+make_interval(secs=>v_duration/1000);
 update nexora.organizations set treasury_balance=treasury_balance-v_cost,upgrade_started_at=now(),upgrade_ends_at=v_end,upgrade_target_level=v_target,updated_at=now() where id=p_org_id;
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note)
 values(v_tx,p_org_id,p_uid,v_member.username,'upgrade',v_cost,'Started organization upgrade to Lv.'||v_target::text);
 return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_end,'cost',v_cost,'duration_ms',v_duration);
end;$$;

create or replace function nexora.complete_organization_upgrade(p_uid text,p_org_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_target integer;v_capacity integer;
begin
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role not in ('leader','deputy') then raise exception 'UNAUTHORIZED';end if;
 v_target:=coalesce(v_org.upgrade_target_level,0);if v_target=0 or v_org.upgrade_ends_at is null then raise exception 'UPGRADE_NOT_READY';end if;
 if now()<v_org.upgrade_ends_at then raise exception 'UPGRADE_NOT_READY';end if;
 if v_target<>v_org.level+1 then raise exception 'INVALID_UPGRADE_STATE';end if;
 v_capacity:=least(80,20+(v_target-1)*5+coalesce((v_org.research->>'expansion')::integer,0));
 update nexora.organizations set level=v_target,member_capacity=v_capacity,upgrade_ends_at=null,upgrade_started_at=null,upgrade_target_level=null,updated_at=now() where id=p_org_id;
 return jsonb_build_object('ok',true,'level',v_target,'member_capacity',v_capacity);
end;$$;

create or replace function nexora.research_organization(p_uid text,p_org_id text,p_research_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_base bigint;v_current integer;v_cost bigint;v_research jsonb;v_capacity integer;v_tx text:='org_research_'||gen_random_uuid()::text;
begin
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role not in ('leader','deputy') then raise exception 'UNAUTHORIZED';end if;
 v_base:=case p_research_id when 'commerce' then 25000 when 'engineering' then 30000 when 'expansion' then 20000 when 'finance' then 35000 when 'diplomacy' then 18000 else null end;
 if v_base is null then raise exception 'INVALID_RESEARCH';end if;
 v_current:=coalesce((v_org.research->>p_research_id)::integer,0);if v_current>=10 then raise exception 'RESEARCH_MAX_LEVEL';end if;
 v_cost:=v_base*(v_current+1)*(v_current+1);if v_org.treasury_balance<v_cost then raise exception 'INSUFFICIENT_TREASURY';end if;
 v_research:=jsonb_set(coalesce(v_org.research,'{}'::jsonb),array[p_research_id],to_jsonb(v_current+1),true);
 v_capacity:=case when p_research_id='expansion' then least(80,20+(greatest(1,v_org.level)-1)*5+v_current+1)
 else coalesce(nullif(v_org.member_capacity,0),least(70,20+(greatest(1,v_org.level)-1)*5)) end;
 update nexora.organizations set treasury_balance=treasury_balance-v_cost,research=v_research,member_capacity=v_capacity,updated_at=now() where id=p_org_id;
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note)
 values(v_tx,p_org_id,p_uid,v_member.username,'upgrade',v_cost,'Research '||p_research_id||' advanced to Lv.'||(v_current+1)::text);
 return jsonb_build_object('ok',true,'research_id',p_research_id,'level',v_current+1,'cost',v_cost,'member_capacity',v_capacity);
end;$$;

revoke all on function nexora.create_organization(text,text,text,text) from public,anon,authenticated;
revoke all on function nexora.start_organization_upgrade(text,text) from public,anon,authenticated;
revoke all on function nexora.complete_organization_upgrade(text,text) from public,anon,authenticated;
revoke all on function nexora.research_organization(text,text,text) from public,anon,authenticated;
grant execute on function nexora.create_organization(text,text,text,text) to service_role;
grant execute on function nexora.start_organization_upgrade(text,text) to service_role;
grant execute on function nexora.complete_organization_upgrade(text,text) to service_role;
grant execute on function nexora.research_organization(text,text,text) to service_role;
