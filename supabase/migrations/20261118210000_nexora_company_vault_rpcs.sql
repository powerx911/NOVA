create or replace function nexora.company_net_hourly(p_company_id text)
returns bigint language plpgsql stable security definer set search_path = '' as $$
declare v_company nexora.companies%rowtype;v_profile nexora.player_profiles%rowtype;v_management numeric;v_finance numeric;v_tier numeric:=0;v_event_mult numeric:=1;v_seen text[]:='{}';v_event record;v_income_bonus numeric:=0;v_gross numeric;v_expense numeric;
begin
 select * into v_company from nexora.companies where id=p_company_id;if not found then return 0;end if;
 select * into v_profile from nexora.player_profiles where user_id=v_company.owner_uid;if not found then return 0;end if;
 v_management:=greatest(0,coalesce((v_profile.skills->>'management')::numeric,0));v_finance:=greatest(0,coalesce((v_profile.skills->>'finance')::numeric,0));
 v_tier:=case when v_profile.reputation>=700 then .08 when v_profile.reputation>=350 then .06 when v_profile.reputation>=160 then .04 when v_profile.reputation>=60 then .02 else 0 end;
 if v_profile.org_id is not null then select greatest(0,least(10,coalesce((research->>'commerce')::numeric,0))) into v_income_bonus from nexora.organizations where id=v_profile.org_id;end if;
 for v_event in select group_key,revenue_multiplier,affected_sectors from (
   select distinct on (coalesce(nullif(stack_group,''),effect_type,id)) coalesce(nullif(stack_group,''),effect_type,id) group_key,revenue_multiplier,affected_sectors,starts_at
   from nexora.world_events where active=true and starts_at<=now() and ends_at>now()
   order by coalesce(nullif(stack_group,''),effect_type,id),starts_at desc
 ) e order by group_key limit 3 loop
   if not (v_event.group_key=any(v_seen)) then
     v_seen:=array_append(v_seen,v_event.group_key);
     if coalesce(v_event.affected_sectors,'[]'::jsonb) @> jsonb_build_array(v_company.sector) then v_event_mult:=v_event_mult*coalesce(v_event.revenue_multiplier,1);end if;
   end if;
 end loop;
 v_event_mult:=greatest(.75,least(1.4,round(v_event_mult::numeric,3)));
 v_gross:=round(v_company.base_revenue_per_hour*(1+(v_company.level-1)*.32)*(1+v_management*.08)*v_event_mult*(1+v_tier)*(1+v_income_bonus*.005));
 v_expense:=round(v_company.expense_per_hour*(1+(v_company.level-1)*.2)*(1-least(.45,v_finance*.05)));
 return greatest(15,v_gross-v_expense)::bigint;
end;$$;

create or replace function nexora.start_company_upgrade(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_company nexora.companies%rowtype;v_wallet nexora.wallets%rowtype;v_cost bigint;v_target integer;v_duration numeric;v_ends timestamptz;v_tx text:='tx_'||gen_random_uuid()::text;v_log text:='clog_'||gen_random_uuid()::text;
begin
 select * into v_company from nexora.companies where id=p_company_id for update;if not found then raise exception 'COMPANY_NOT_FOUND';end if;
 if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED';end if;if v_company.level>=100 then raise exception 'MAX_LEVEL';end if;
 if v_company.level_upgrade_ends_at>now() then raise exception 'UPGRADE_IN_PROGRESS';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 v_cost:=v_company.level*550;if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS';end if;
 v_target:=v_company.level+1;
 if v_target<=50 then v_duration:=round(2000*power(43200::numeric,(v_target-2)::numeric/48));else v_duration:=round(86400000*power(15::numeric,(v_target-50)::numeric/50));end if;
 v_ends:=now()+make_interval(secs=>greatest(1,v_duration/1000));
 update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 update nexora.companies set level_upgrade_started_at=now(),level_upgrade_ends_at=v_ends,level_upgrade_target_level=v_target,level_upgrade_cost=v_cost,updated_at=now() where id=p_company_id;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status) values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_upgrade',p_company_id,'Started upgrade of '||v_company.name||' to Lv.'||v_target::text,'completed');
 insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details) values(v_log,p_company_id,p_uid,'upgrade_started',-v_cost,'Started upgrade to Level '||v_target::text);
 return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_ends);
end;$$;

create or replace function nexora.complete_company_upgrade(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_company nexora.companies%rowtype;v_profile nexora.player_profiles%rowtype;v_target integer;v_xp bigint;v_level integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_cost bigint;v_log text:='clog_'||gen_random_uuid()::text;
begin
 select * into v_company from nexora.companies where id=p_company_id for update;if not found then raise exception 'COMPANY_NOT_FOUND';end if;
 if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED';end if;v_target:=coalesce(v_company.level_upgrade_target_level,0);
 if v_company.level_upgrade_ends_at is null or v_target=0 then raise exception 'NO_UPGRADE_IN_PROGRESS';end if;
 if now()<v_company.level_upgrade_ends_at then raise exception 'UPGRADE_NOT_FINISHED';end if;
 if v_target<>v_company.level+1 or v_target>100 then raise exception 'INVALID_UPGRADE_STATE';end if;
 select * into v_profile from nexora.player_profiles where user_id=p_uid for update;if not found then raise exception 'ACCOUNT_NOT_FOUND';end if;
 v_xp:=v_profile.xp+75;v_remaining:=v_xp;
 while v_level<200 loop v_step:=200+(v_level-1)*120;exit when v_remaining<v_step;v_remaining:=v_remaining-v_step;v_level:=v_level+1;end loop;
 v_gained:=greatest(0,v_level-v_profile.level);v_cost:=coalesce(v_company.level_upgrade_cost,0);
 update nexora.companies set level=v_target,capital=capital+v_cost,level_upgrade_started_at=null,level_upgrade_ends_at=null,level_upgrade_target_level=null,level_upgrade_cost=null,updated_at=now() where id=p_company_id;
 update nexora.player_profiles set xp=v_xp,level=v_level,skill_points=skill_points+v_gained*2,updated_at=now() where user_id=p_uid;
 insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details) values(v_log,p_company_id,p_uid,'upgrade_completed',0,'Company reached Level '||v_target::text);
 return jsonb_build_object('ok',true,'level',v_target);
end;$$;

create or replace function nexora.complete_company_vault_upgrade(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_company nexora.companies%rowtype;v_target integer;v_log text:='clog_'||gen_random_uuid()::text;
begin
 select * into v_company from nexora.companies where id=p_company_id for update;if not found then raise exception 'COMPANY_NOT_FOUND';end if;
 if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED';end if;v_target:=coalesce(v_company.vault_upgrade_target_level,0);
 if v_company.vault_upgrade_ends_at is null or v_target=0 then raise exception 'NO_UPGRADE_IN_PROGRESS';end if;
 if now()<v_company.vault_upgrade_ends_at then raise exception 'UPGRADE_NOT_FINISHED';end if;
 if v_target<>v_company.vault_level+1 or v_target>5 then raise exception 'INVALID_UPGRADE_STATE';end if;
 update nexora.companies set vault_level=v_target,vault_upgrade_started_at=null,vault_upgrade_ends_at=null,vault_upgrade_target_level=null,updated_at=now() where id=p_company_id;
 insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details) values(v_log,p_company_id,p_uid,'vault_upgrade_completed',0,'Profit vault reached Level '||v_target::text);
 return jsonb_build_object('ok',true,'vault_level',v_target);
end;$$;

create or replace function nexora.upgrade_company_vault(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_company nexora.companies%rowtype;v_wallet nexora.wallets%rowtype;v_profile nexora.player_profiles%rowtype;
 v_old integer;v_target integer;v_cost bigint;v_item1 text;v_qty1 integer;v_item2 text;v_qty2 integer;
 v_capacity bigint[]:=array[3500,7000,14000,25000,40000];v_cap bigint;v_net bigint;v_preserved bigint;
 v_now timestamptz:=now();v_elapsed numeric;v_tx text:='tx_'||gen_random_uuid()::text;v_log text:='clog_'||gen_random_uuid()::text;
 v_inv1 integer;v_inv2 integer;v_duration numeric;v_ends timestamptz;
begin
 select * into v_company from nexora.companies where id=p_company_id for update;if not found then raise exception 'COMPANY_NOT_FOUND';end if;
 if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED';end if;if v_company.vault_upgrade_ends_at>v_now then raise exception 'UPGRADE_IN_PROGRESS';end if;
 v_old:=greatest(1,least(5,v_company.vault_level));if v_old>=5 then raise exception 'VAULT_MAX_LEVEL';end if;
 case v_old when 1 then v_cost:=1500;v_item1:='copper_wire';v_qty1:=20;v_item2:='crude_alloy';v_qty2:=10;
 when 2 then v_cost:=4000;v_item1:='silicon_ore';v_qty1:=20;v_item2:='energy_cells';v_qty2:=15;
 when 3 then v_cost:=10000;v_item1:='carbon_fiber';v_qty1:=15;v_item2:='precision_frame';v_qty2:=10;
 when 4 then v_cost:=25000;v_item1:='rare_minerals';v_qty1:=20;v_item2:='quantum_server';v_qty2:=5;end case;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;select * into v_profile from nexora.player_profiles where user_id=p_uid;
 if not found or v_wallet.user_id is null then raise exception 'ACCOUNT_NOT_FOUND';end if;if v_wallet.balance<v_cost then raise exception 'INSUFFICIENT_FUNDS';end if;
 select quantity into v_inv1 from nexora.inventory where user_id=p_uid and item_id=v_item1 for update;if not found or coalesce(v_inv1,0)<v_qty1 then raise exception 'MISSING_VAULT_MATERIALS';end if;
 select quantity into v_inv2 from nexora.inventory where user_id=p_uid and item_id=v_item2 for update;if not found or coalesce(v_inv2,0)<v_qty2 then raise exception 'MISSING_VAULT_MATERIALS';end if;
 v_net:=nexora.company_net_hourly(p_company_id);v_cap:=v_capacity[v_old];v_elapsed:=greatest(0,extract(epoch from (v_now-coalesce(v_company.last_collected_at,v_now)))/3600);
 v_preserved:=least(v_cap,greatest(0,coalesce(v_company.vault_balance,0)+floor(v_net*least(12,v_elapsed))::bigint));
 v_target:=v_old+1;if v_target<=50 then v_duration:=round(2000*power(43200::numeric,(v_target-2)::numeric/48));else v_duration:=round(86400000*power(15::numeric,(v_target-50)::numeric/50));end if;
 v_ends:=v_now+make_interval(secs=>greatest(1,v_duration/2000));
 update nexora.wallets set balance=balance-v_cost,total_spent=total_spent+v_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 update nexora.inventory set quantity=quantity-v_qty1,updated_at=now() where user_id=p_uid and item_id=v_item1;
 update nexora.inventory set quantity=quantity-v_qty2,updated_at=now() where user_id=p_uid and item_id=v_item2;
 update nexora.companies set vault_balance=v_preserved,last_collected_at=v_now,vault_upgrade_started_at=v_now,vault_upgrade_ends_at=v_ends,vault_upgrade_target_level=v_target,updated_at=now() where id=p_company_id;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status) values(v_tx,p_uid,'SYSTEM',v_cost,0,v_cost,'company_vault_upgrade',p_company_id,'Upgraded '||v_company.name||' profit vault to Lv.'||v_target::text,'completed');
 insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details) values(v_log,p_company_id,p_uid,'vault_upgrade',-v_cost,'Profit vault upgraded to Lv.'||v_target::text||'; preserved '||v_preserved::text);
 return jsonb_build_object('ok',true,'target_level',v_target,'ends_at',v_ends,'vault_balance',v_preserved,'capacity',v_cap);
end;$$;

create or replace function nexora.collect_company_revenue(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_company nexora.companies%rowtype;v_wallet nexora.wallets%rowtype;v_profile nexora.player_profiles%rowtype;
 v_capacity bigint[]:=array[3500,7000,14000,25000,40000];v_level integer;v_net bigint;v_elapsed numeric;
 v_payout bigint;v_now timestamptz:=now();v_tx text:='tx_'||gen_random_uuid()::text;v_log text:='clog_'||gen_random_uuid()::text;
 v_xp bigint;v_level_after integer:=1;v_remaining bigint;v_step bigint;v_gained integer;v_leadership numeric;
begin
 select * into v_company from nexora.companies where id=p_company_id for update;if not found then raise exception 'COMPANY_NOT_FOUND';end if;
 if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED';end if;
 if v_company.last_collected_at is not null and v_now-v_company.last_collected_at<interval '30 seconds' then raise exception 'NOTHING_TO_COLLECT';end if;
 select * into v_wallet from nexora.wallets where user_id=p_uid for update;select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
 if not found or v_wallet.user_id is null then raise exception 'ACCOUNT_NOT_FOUND';end if;
 v_net:=nexora.company_net_hourly(p_company_id);v_level:=greatest(1,least(5,v_company.vault_level));
 v_elapsed:=greatest(0,extract(epoch from (v_now-coalesce(v_company.last_collected_at,v_now)))/3600);
 v_payout:=least(v_capacity[v_level],greatest(0,coalesce(v_company.vault_balance,0)+floor(v_net*least(12,v_elapsed))::bigint));
 if v_payout<1 then raise exception 'NOTHING_TO_COLLECT';end if;
 update nexora.wallets set balance=balance+v_payout,total_earned=total_earned+v_payout,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
 update nexora.companies set total_revenue=total_revenue+v_payout,vault_balance=0,last_collected_at=v_now,updated_at=now() where id=p_company_id;
 v_xp:=v_profile.xp+least(80,greatest(10,floor(v_payout/15)::integer));v_remaining:=v_xp;
 while v_level_after<200 loop v_step:=200+(v_level_after-1)*120;exit when v_remaining<v_step;v_remaining:=v_remaining-v_step;v_level_after:=v_level_after+1;end loop;
 v_gained:=greatest(0,v_level_after-v_profile.level);v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*.1;
 update nexora.player_profiles set xp=v_xp,level=v_level_after,skill_points=skill_points+v_gained*2,
  reputation=reputation+round(2*v_leadership)::bigint,influence=influence+round(1*v_leadership)::bigint,updated_at=now() where user_id=p_uid;
 insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status) values(v_tx,'SYSTEM',p_uid,v_payout,0,v_payout,'company_collect',p_company_id,'Company revenue collected: '||v_company.name,'completed');
 insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details) values(v_log,p_company_id,p_uid,'collect',v_payout,'Collected +$'||v_payout::text);
 return jsonb_build_object('ok',true,'payout',v_payout);
end;$$;

revoke all on function nexora.company_net_hourly(text) from public,anon,authenticated;
revoke all on function nexora.start_company_upgrade(text,text) from public,anon,authenticated;
revoke all on function nexora.complete_company_upgrade(text,text) from public,anon,authenticated;
revoke all on function nexora.complete_company_vault_upgrade(text,text) from public,anon,authenticated;
revoke all on function nexora.upgrade_company_vault(text,text) from public,anon,authenticated;
revoke all on function nexora.collect_company_revenue(text,text) from public,anon,authenticated;
grant execute on function nexora.company_net_hourly(text) to service_role;
grant execute on function nexora.start_company_upgrade(text,text) to service_role;
grant execute on function nexora.complete_company_upgrade(text,text) to service_role;
grant execute on function nexora.complete_company_vault_upgrade(text,text) to service_role;
grant execute on function nexora.upgrade_company_vault(text,text) to service_role;
grant execute on function nexora.collect_company_revenue(text,text) to service_role;
