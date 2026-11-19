-- RECOVERED UNTRACKED SQL EXECUTION — NOT A MIGRATION LEDGER ENTRY
-- PostgreSQL log timestamp: 2026-11-18 17:36:20 UTC
-- Source: postgres_logs client-backend statement event; POST /mcp metadata stripped.
-- Recovered 2026-11-19. SQL body preserved as logged.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.fulfill_trade_contract(p_uid text,p_contract_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_item text; v_qty integer; v_base bigint; v_xp integer; v_rep integer; v_title text;
  v_date text := to_char(now() at time zone 'UTC','YYYY-MM-DD');
  v_claim text; v_profile nexora.player_profiles%rowtype; v_wallet nexora.wallets%rowtype;
  v_inventory nexora.inventory%rowtype; v_tier_bonus numeric := 0; v_payout bigint;
  v_tx text := 'tx_' || gen_random_uuid()::text; v_level integer := 1; v_remaining bigint; v_step bigint;
  v_new_xp bigint; v_levels_gained integer; v_leadership numeric; v_stats jsonb;
begin
  case p_contract_id
    when 'ctr_chip_batch' then v_item:='microchips'; v_qty:=2; v_base:=420; v_xp:=75; v_rep:=12; v_title:='Cloud Lab Microchip Supply';
    when 'ctr_drone_fleet' then v_item:='logistics_drone'; v_qty:=1; v_base:=890; v_xp:=145; v_rep:=24; v_title:='Express Cargo Drone Fleet';
    when 'ctr_quantum_node' then v_item:='quantum_server'; v_qty:=1; v_base:=840; v_xp:=135; v_rep:=22; v_title:='Quantum Node Deployment';
    else raise exception 'INVALID_CONTRACT';
  end case;
  v_claim:=p_contract_id || '_' || v_date;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if exists(select 1 from nexora.contract_claims where user_id=p_uid and contract_id=v_claim) then raise exception 'CONTRACT_ALREADY_FULFILLED'; end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=v_item for update;
  if not found or v_inventory.quantity<v_qty then raise exception 'MISSING_INPUTS'; end if;
  v_tier_bonus:=case
    when v_profile.reputation>=700 then 0.15
    when v_profile.reputation>=350 then 0.12
    when v_profile.reputation>=160 then 0.08
    when v_profile.reputation>=60 then 0.04
    else 0 end;
  v_payout:=least(2500,round(v_base*(1+coalesce((v_profile.skills->>'negotiation')::numeric,0)*0.07)*(1+v_tier_bonus))::bigint);
  update nexora.inventory set quantity=quantity-v_qty,updated_at=now() where user_id=p_uid and item_id=v_item;
  update nexora.wallets set balance=balance+v_payout,total_earned=total_earned+v_payout,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.contract_claims(user_id,contract_id,amount) values(p_uid,v_claim,v_payout);
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_payout,0,v_payout,'contract_deal',v_claim,'Contract fulfilled: ' || v_title,'completed');
  v_new_xp:=v_profile.xp+v_xp; v_remaining:=v_new_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120; exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step; v_level:=v_level+1;
  end loop;
  v_levels_gained:=greatest(0,v_level-v_profile.level); v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{tradesCount}',to_jsonb(coalesce((v_profile.stats->>'tradesCount')::integer,0)+1),true);
  update nexora.player_profiles set xp=v_new_xp,level=v_level,skill_points=skill_points+v_levels_gained*2,
    reputation=reputation+round(v_rep*v_leadership)::bigint,influence=influence+round(5*v_leadership)::bigint,
    stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'payout',v_payout,'contract_id',v_claim);
end;
$$;
revoke all on function nexora.fulfill_trade_contract(text,text) from public,anon,authenticated;
grant execute on function nexora.fulfill_trade_contract(text,text) to service_role;
