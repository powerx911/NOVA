-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118181814
-- Remote migration name: nexora_server_operations
-- Source: Supabase postgres_logs at 2026-11-18 18:18:14 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

CREATE OR REPLACE FUNCTION nexora.claim_mission_reward(p_uid text, p_mission_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_category text;v_metric text;v_target integer;v_credits bigint;v_xp_gain integer;v_rep integer;v_title text;
 v_profile nexora.player_profiles%rowtype;v_wallet nexora.wallets%rowtype;v_progress integer;v_claim text:=p_uid||'_'||p_mission_id;
 v_tx text:='tx_'||gen_random_uuid()::text;v_xp bigint;v_level integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_leadership numeric;v_stats jsonb;
begin
 case p_mission_id
  when 'tut_first_trade' then v_category:='tutorial';v_metric:='trades';v_target:=1;v_credits:=450;v_xp_gain:=90;v_rep:=10;v_title:='Enter the Open Market';
  when 'tut_first_production' then v_category:='tutorial';v_metric:='produced';v_target:=1;v_credits:=550;v_xp_gain:=110;v_rep:=15;v_title:='Start Production Line';
  when 'tut_first_company' then v_category:='tutorial';v_metric:='companies';v_target:=1;v_credits:=850;v_xp_gain:=160;v_rep:=25;v_title:='Found Your First Company';
  when 'daily_active_trader' then v_category:='daily';v_metric:='trades';v_target:=3;v_credits:=600;v_xp_gain:=120;v_rep:=14;v_title:='Active Market Trader';
  when 'weekly_real_estate' then v_category:='weekly';v_metric:='properties';v_target:=1;v_credits:=950;v_xp_gain:=210;v_rep:=28;v_title:='Real Estate Expansion';
  when 'seasonal_syndicate' then v_category:='seasonal';v_metric:='org';v_target:=1;v_credits:=1200;v_xp_gain:=260;v_rep:=35;v_title:='Economic Syndicate Alliance';
  else raise exception 'INVALID_MISSION';
 end case;
 select * into v_profile from nexora.player_profiles where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 if exists(select 1 from nexora.player_missions where user_id=p_uid and mission_id=p_mission_id) then raise exception 'MISSION_ALREADY_CLAIMED';end if;
 v_progress:=case v_metric when 'trades' then coalesce((v_profile.stats->>'tradesCount')::integer,0)
  when 'produced' then coalesce((v_profile.stats->>'totalProduced')::integer,0)
  when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::integer,0)
  when 'properties' then coalesce((v_profile.stats->>'propertiesOwned')::integer,0)
  when 'org' then case when v_profile.org_id is null then 0 else 1 end
  else v_profile.level end;
 if v_progress<v_target then raise exception 'MISSION_NOT_COMPLETE';end if;
 insert into nexora.player_missions(user_id,mission_id,category,reward_credits,reward_xp) values(p_uid,p_mission_id,v_category,v_credits,v_xp_gain);
 update nexora.wallets set balance=balance+v_credits,total_earned=total_earned+v_credits,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
 values(v_tx,'SYSTEM',p_uid,v_credits,0,v_credits,'mission_reward',v_claim,'Mission reward: '||v_title,'completed');
 v_xp:=v_profile.xp+v_xp_gain;v_remaining:=v_xp;
 while v_level<200 loop v_step:=200+(v_level-1)*120;exit when v_remaining<v_step;v_remaining:=v_remaining-v_step;v_level:=v_level+1;end loop;
 v_gained:=greatest(0,v_level-v_profile.level);v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*.1;
 v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{missionsCompleted}',to_jsonb(coalesce((v_profile.stats->>'missionsCompleted')::integer,0)+1),true);
 update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,
  reputation=reputation+round(v_rep*v_leadership)::bigint,influence=influence+round(5*v_leadership)::bigint,stats=v_stats,updated_at=now()
 where user_id=p_uid;
 return jsonb_build_object('ok',true,'reward_credits',v_credits,'reward_xp',v_xp_gain);
end;$function$;

CREATE OR REPLACE FUNCTION nexora.complete_organization_upgrade(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_target integer;v_capacity integer;
begin
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role not in ('leader','deputy') then raise exception 'UNAUTHORIZED';end if;
 v_target:=coalesce(v_org.upgrade_target_level,0);
 if v_target=0 or v_org.upgrade_ends_at is null then raise exception 'UPGRADE_NOT_READY';end if;
 if now()<v_org.upgrade_ends_at then raise exception 'UPGRADE_NOT_READY';end if;
 if v_target<>v_org.level+1 then raise exception 'INVALID_UPGRADE_STATE';end if;
 v_capacity:=least(80,20+(v_target-1)*5+coalesce((v_org.research->>'expansion')::integer,0));
 update nexora.organizations set level=v_target,member_capacity=v_capacity,upgrade_ends_at=null,upgrade_started_at=null,upgrade_target_level=null,updated_at=now() where id=p_org_id;
 return jsonb_build_object('ok',true,'level',v_target,'member_capacity',v_capacity);
end;$function$;

CREATE OR REPLACE FUNCTION nexora.create_organization(p_uid text, p_name text, p_tag text, p_description text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_profile nexora.player_profiles%rowtype;v_wallet nexora.wallets%rowtype;v_id text:='org_'||gen_random_uuid()::text;
 v_tx text:='tx_'||gen_random_uuid()::text;v_xp bigint;v_level integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_leadership numeric;
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
end;$function$;

CREATE OR REPLACE FUNCTION nexora.deposit_org_treasury(p_uid text, p_org_id text, p_amount bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;

CREATE OR REPLACE FUNCTION nexora.fetch_leaderboards()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object(
  'players',coalesce((select jsonb_agg(jsonb_build_object(
   'uid',user_id,'username',username,'avatarId',avatar_id,'title',title,'level',level,'xp',xp,
   'reputation',reputation,'influence',influence,'skillPoints',skill_points,'skills',skills,'stats',stats,'orgId',org_id
  ) order by influence desc) from (select * from nexora.player_profiles order by influence desc limit 20) p),'[]'::jsonb),
  'companies',coalesce((select jsonb_agg(jsonb_build_object(
   'id',id,'ownerUid',owner_uid,'ownerName',owner_name,'name',name,'sector',sector,'level',level,'capital',capital,
   'employeesCount',employees_count,'baseRevenuePerHour',base_revenue_per_hour,'expensePerHour',expense_per_hour,
   'totalRevenue',total_revenue,'vaultLevel',vault_level,'vaultBalance',vault_balance,
   'levelUpgradeStartedAt',level_upgrade_started_at,'levelUpgradeEndsAt',level_upgrade_ends_at,
   'levelUpgradeTargetLevel',level_upgrade_target_level,'levelUpgradeCost',level_upgrade_cost,
   'vaultUpgradeStartedAt',vault_upgrade_started_at,'vaultUpgradeEndsAt',vault_upgrade_ends_at,
   'vaultUpgradeTargetLevel',vault_upgrade_target_level,'auctionId',auction_id,'auctionEndsAt',auction_ends_at,
   'auctionStatus',auction_status,'lastCollectedAt',last_collected_at,'createdAt',created_at,'updatedAt',updated_at
  ) order by total_revenue desc) from (select * from nexora.companies order by total_revenue desc limit 20) c),'[]'::jsonb),
  'organizations',coalesce((select jsonb_agg(jsonb_build_object(
   'id',id,'name',name,'tag',tag,'description',description,'leaderUid',leader_uid,'leaderName',leader_name,
   'treasuryBalance',treasury_balance,'memberCount',member_count,'reputation',reputation,'level',level,
   'memberCapacity',member_capacity,'joinMode',join_mode,'research',research,'upgradeStartedAt',upgrade_started_at,
   'upgradeEndsAt',upgrade_ends_at,'upgradeTargetLevel',upgrade_target_level,'createdAt',created_at,'updatedAt',updated_at
  ) order by reputation desc) from (select * from nexora.organizations order by reputation desc limit 20) o),'[]'::jsonb)
 );
$function$;

CREATE OR REPLACE FUNCTION nexora.get_org_pending_requests(p_org_id text, p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_member nexora.organization_members%rowtype;v_result jsonb;
begin
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;
 if not found or not (v_member.permissions ? 'manage_members') then raise exception 'UNAUTHORIZED';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'orgId',org_id,'uid',user_id,'username',username,'status',status,'createdAt',created_at) order by created_at),'[]'::jsonb)
 into v_result from nexora.organization_requests where org_id=p_org_id and status='pending';
 return v_result;
end;$function$;

CREATE OR REPLACE FUNCTION nexora.handle_org_join_request(p_actor_uid text, p_org_id text, p_request_id text, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;

CREATE OR REPLACE FUNCTION nexora.kick_org_member(p_actor_uid text, p_org_id text, p_target_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;

CREATE OR REPLACE FUNCTION nexora.leave_organization(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_member nexora.organization_members%rowtype;
begin
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role='leader' then raise exception 'LEADER_CANNOT_LEAVE';end if;
 delete from nexora.organization_members where org_id=p_org_id and user_id=p_uid;
 update nexora.organizations set member_count=greatest(1,member_count-1),updated_at=now() where id=p_org_id;
 update nexora.player_profiles set org_id=null,updated_at=now() where user_id=p_uid and org_id=p_org_id;
 return jsonb_build_object('ok',true);
end;$function$;

CREATE OR REPLACE FUNCTION nexora.request_join_organization(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;

CREATE OR REPLACE FUNCTION nexora.research_organization(p_uid text, p_org_id text, p_research_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;

CREATE OR REPLACE FUNCTION nexora.start_organization_upgrade(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_org nexora.organizations%rowtype;v_member nexora.organization_members%rowtype;v_cost bigint;v_level integer;v_finance numeric;v_engineering numeric;v_duration numeric;v_target integer;v_end timestamptz;v_tx text:='org_upgrade_'||gen_random_uuid()::text;
begin
 select * into v_org from nexora.organizations where id=p_org_id for update;if not found then raise exception 'NOT_FOUND';end if;
 select * into v_member from nexora.organization_members where org_id=p_org_id and user_id=p_uid;if not found then raise exception 'NOT_FOUND';end if;
 if v_member.role not in ('leader','deputy') then raise exception 'UNAUTHORIZED';end if;
 if v_org.upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS';end if;
 v_level:=greatest(1,v_org.level);if v_level>=10 then raise exception 'MAX_LEVEL';end if;
 v_finance:=least(10,greatest(0,coalesce((v_org.research->>'finance')::numeric,0)));
 v_engineering:=least(10,greatest(0,coalesce((v_org.research->>'engineering')::numeric,0)));
 v_cost:=round(12000*v_level*v_level*(1-v_finance*.005));
 if v_org.treasury_balance<v_cost then raise exception 'INSUFFICIENT_TREASURY';end if;
 v_target:=v_level+1;v_duration:=round(8*60*60*1000*power(1.5::numeric,greatest(0,v_target-2))*(1-v_engineering*.005));
 v_end:=now()+make_interval(secs=>v_duration/1000);
 update nexora.organizations set treasury_balance=treasury_balance-v_cost,upgrade_started_at=now(),upgrade_ends_at=v_end,upgrade_target_level=v_target,updated_at=now() where id=p_org_id;
 insert into nexora.organization_transactions(id,org_id,user_id,username,type,amount,note)
 values(v_tx,p_org_id,p_uid,v_member.username,'upgrade',v_cost,'Started organization upgrade to Lv.'||v_target::text);
 return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_end,'cost',v_cost,'duration_ms',v_duration);
end;$function$;

CREATE OR REPLACE FUNCTION nexora.sync_self_org_membership(p_uid text, p_org_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;

CREATE OR REPLACE FUNCTION nexora.unlock_eligible_achievements(p_uid text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_profile nexora.player_profiles%rowtype;v_unlocked text[]:='{}';
begin
 select * into v_profile from nexora.player_profiles where user_id=p_uid;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 insert into nexora.player_achievements(user_id,achievement_id)
 select p_uid,a.id from (values
  ('ach_merchant','trades',5),('ach_industrial_pioneer','produced',5),('ach_tycoon','companies',2),
  ('ach_landlord','properties',2),('ach_level_5','level',5),('ach_reputation_100','reputation',100)
 ) as a(id,metric,threshold)
 where case a.metric
  when 'trades' then coalesce((v_profile.stats->>'tradesCount')::integer,0)
  when 'produced' then coalesce((v_profile.stats->>'totalProduced')::integer,0)
  when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::integer,0)
  when 'properties' then coalesce((v_profile.stats->>'propertiesOwned')::integer,0)
  when 'level' then v_profile.level
  else v_profile.reputation end >= a.threshold
 on conflict(user_id,achievement_id) do nothing;
 select coalesce(array_agg(achievement_id),'{}'::text[]) into v_unlocked from nexora.player_achievements where user_id=p_uid;
 return jsonb_build_object('unlocked_ids',v_unlocked);
end;$function$;

CREATE OR REPLACE FUNCTION nexora.update_org_member_role(p_actor_uid text, p_org_id text, p_target_uid text, p_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;

CREATE OR REPLACE FUNCTION nexora.withdraw_org_treasury(p_uid text, p_org_id text, p_amount bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end;$function$;

REVOKE ALL ON FUNCTION nexora.claim_mission_reward(p_uid text, p_mission_id text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.complete_organization_upgrade(p_uid text, p_org_id text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.create_organization(p_uid text, p_name text, p_tag text, p_description text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.deposit_org_treasury(p_uid text, p_org_id text, p_amount bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.fetch_leaderboards() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.get_org_pending_requests(p_org_id text, p_uid text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.handle_org_join_request(p_actor_uid text, p_org_id text, p_request_id text, p_decision text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.kick_org_member(p_actor_uid text, p_org_id text, p_target_uid text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.leave_organization(p_uid text, p_org_id text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.request_join_organization(p_uid text, p_org_id text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.research_organization(p_uid text, p_org_id text, p_research_id text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.start_organization_upgrade(p_uid text, p_org_id text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.sync_self_org_membership(p_uid text, p_org_id text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.unlock_eligible_achievements(p_uid text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.update_org_member_role(p_actor_uid text, p_org_id text, p_target_uid text, p_role text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION nexora.withdraw_org_treasury(p_uid text, p_org_id text, p_amount bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION nexora.claim_mission_reward(p_uid text, p_mission_id text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.complete_organization_upgrade(p_uid text, p_org_id text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.create_organization(p_uid text, p_name text, p_tag text, p_description text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.deposit_org_treasury(p_uid text, p_org_id text, p_amount bigint) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.fetch_leaderboards() TO service_role;
GRANT EXECUTE ON FUNCTION nexora.get_org_pending_requests(p_org_id text, p_uid text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.handle_org_join_request(p_actor_uid text, p_org_id text, p_request_id text, p_decision text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.kick_org_member(p_actor_uid text, p_org_id text, p_target_uid text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.leave_organization(p_uid text, p_org_id text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.request_join_organization(p_uid text, p_org_id text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.research_organization(p_uid text, p_org_id text, p_research_id text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.start_organization_upgrade(p_uid text, p_org_id text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.sync_self_org_membership(p_uid text, p_org_id text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.unlock_eligible_achievements(p_uid text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.update_org_member_role(p_actor_uid text, p_org_id text, p_target_uid text, p_role text) TO service_role;
GRANT EXECUTE ON FUNCTION nexora.withdraw_org_treasury(p_uid text, p_org_id text, p_amount bigint) TO service_role;
;
