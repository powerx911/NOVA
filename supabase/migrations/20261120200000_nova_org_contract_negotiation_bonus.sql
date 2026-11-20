-- Apply negotiation skill to shared organization contract rewards on a per-claimant basis.
-- Organization offers remain shared at their base payout; each member sees and
-- receives the bonus from their own current negotiation level.

create or replace function nexora.get_dynamic_contract_board(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_org nexora.organizations%rowtype;
  v_progression jsonb;
  v_personal_slots integer;
  v_daily_limit integer;
  v_org_slots_base integer;
  v_org_slots_divisor integer;
  v_today date:=(now() at time zone 'UTC')::date;
  v_end timestamptz:=((date_trunc('day',timezone('UTC',now()))+interval '1 day') at time zone 'UTC');
  v_personal jsonb;
  v_org_board jsonb:='[]'::jsonb;
  v_active integer;
  v_slots integer;
  v_slot integer;
  v_event record;
  v_event_slot integer;
  v_event_offer_count integer;
  v_event_index integer;
  v_claims integer;
  v_org_claims integer;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select config_value into v_progression from nexora.contract_config where config_key='progression';
  v_personal_slots:=coalesce((v_progression->>'personal_slots')::integer,6);
  v_daily_limit:=coalesce((v_progression->>'daily_claim_limit')::integer,5);
  v_org_slots_base:=coalesce((v_progression->>'org_slots_base')::integer,2);
  v_org_slots_divisor:=greatest(1,coalesce((v_progression->>'org_slots_level_divisor')::integer,2));
  perform nexora.settle_dynamic_contracts(p_uid);
  for v_slot in 1..v_personal_slots loop
    if not exists(select 1 from nexora.contract_offers where scope='personal' and user_id=p_uid
      and board_date=v_today and slot_no=v_slot and status in ('offered','accepted','processing','ready')) then
      perform nexora.generate_dynamic_contract('personal',p_uid,null,v_slot,v_today,null,null,null);
    end if;
  end loop;
  -- One or two event offers per active targeted event, outside the six standard slots.
  for v_event in
    select id from nexora.world_events where active=true and starts_at<=now() and ends_at>now()
      and target_item_id is not null and price_multiplier>1
      and exists(select 1 from nexora.contract_config c where c.config_key='catalog_prices'
        and c.config_value ? nexora.world_events.target_item_id)
    order by starts_at,id
  loop
    select coalesce(max(slot_no),0) into v_event_slot from nexora.contract_offers
      where scope='personal' and user_id=p_uid and board_date=v_today and event_id=v_event.id;
    if v_event_slot=0 then
      v_event_offer_count:=1+floor(random()*2)::integer;
      for v_event_index in 1..v_event_offer_count loop
        perform nexora.generate_dynamic_contract('personal',p_uid,null,(1000+((select count(*) from nexora.world_events e2 where e2.id<=v_event.id)-1)*2+v_event_index)::integer,v_today,null,null,v_event.id);
      end loop;
    end if;
  end loop;
  select coalesce(jsonb_agg(to_jsonb(o) order by o.slot_no,o.slot_generation),'[]'::jsonb)
    into v_personal from nexora.contract_offers o
    where o.scope='personal' and o.user_id=p_uid
      and (o.board_date=v_today or o.status in ('accepted','processing','ready'))
      and o.status in ('offered','accepted','processing','ready');
  select count(*) into v_active from nexora.contract_offers
    where scope='personal' and user_id=p_uid and status in ('accepted','processing','ready');
  select coalesce(personal_used_count,0),coalesce(org_used_count,0)
    into v_claims,v_org_claims from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today;
  if v_profile.org_id is not null then
    -- The profile, wallet and contract rows are already locked before the
    -- shared organization row, serializing board-slot generation safely.
    select * into v_org from nexora.organizations where id=v_profile.org_id for update;
    if found then
      perform nexora.ensure_org_weekly_goals(v_org.id);
      v_slots:=least(100,greatest(10,v_org.level*10));
      for v_slot in 1..v_slots loop
        if not exists(select 1 from nexora.contract_offers where scope='organization' and org_id=v_org.id
          and board_date=v_today and slot_no=v_slot and status in ('offered','accepted','processing','ready'))
          and (
            not exists(select 1 from nexora.contract_offers where scope='organization' and org_id=v_org.id
              and board_date=v_today and slot_no=v_slot)
            or exists(select 1 from nexora.contract_slot_cooldowns c
              where c.scope='organization' and c.owner_id=v_org.id and c.slot_no=v_slot
                and c.board_date=v_today and c.cooldown_until<=now())
          ) then
          perform nexora.generate_dynamic_contract('organization',null,v_org.id,v_slot,v_today,null,null,null);
        end if;
      end loop;
      -- Shared organization contracts are priced for the viewing member using
      -- that member's negotiation skill; the stored base payout stays unchanged.
      select coalesce(jsonb_agg(
        to_jsonb(o) || jsonb_build_object(
          'payout',
          round(o.base_payout * (
            1 + greatest(0,least(10,coalesce((v_profile.skills->>'negotiation')::numeric,0))) * 0.07
          ))::bigint
        ) order by o.slot_no,o.slot_generation
      ),'[]'::jsonb)
      into v_org_board from nexora.contract_offers o
      where o.scope='organization' and o.org_id=v_org.id
        and (o.board_date=v_today or o.status in ('accepted','processing','ready'))
        and o.status in ('offered','accepted','processing','ready');
    end if;
  end if;
  return jsonb_build_object('personal',coalesce(v_personal,'[]'::jsonb),
    'organization',coalesce(v_org_board,'[]'::jsonb),'organization_slots',coalesce(v_slots,0),'organization_max_slots',100,'active_personal',v_active,
    'daily_used',coalesce(v_claims,0),'daily_limit',5,
    'org_daily_used',coalesce(v_org_claims,0),'org_daily_limit',5,'offer_expires_at',v_end);
end;
$function$;

create or replace function nexora.claim_dynamic_contract(p_uid text, p_contract_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_today date:=(now() at time zone 'UTC')::date;
  v_xp integer;
  v_level integer:=1;
  v_remaining bigint;
  v_step bigint;
  v_leadership numeric;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_new_xp bigint;
  v_progression jsonb;
  v_xp_rate numeric;
  v_xp_cap integer;
  v_payout bigint;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select config_value into v_progression from nexora.contract_config where config_key='progression';
  v_xp_rate:=coalesce((v_progression->>'xp_rate')::numeric,0.17);
  v_xp_cap:=coalesce((v_progression->>'xp_cap')::integer,400);
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' and v_contract.claimed_by<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.status='processing' and v_contract.ready_at<=now() then
    update nexora.contract_offers set status='ready',updated_at=now() where id=p_contract_id;
    perform nexora.emit_notification_once(
      p_uid,'contract-ready:'||p_contract_id,
      'العقد جاهز للاستلام','Contract ready to claim',
      'أصبحت مكافأة أحد عقودك جاهزة للاستلام.','A contract reward is ready to claim.','economy'
    );
    v_contract.status:='ready';
  end if;
  if v_contract.status<>'ready' then
    if v_contract.status='processing' then raise exception 'CONTRACT_NOT_READY'; end if;
    raise exception 'CONTRACT_NOT_CLAIMABLE';
  end if;
  if v_contract.ready_at>now() then raise exception 'CONTRACT_NOT_READY'; end if;

  -- Re-read the current negotiation level at claim time. This guarantees the
  -- reward uses the latest skill even if it changed after the board was loaded.
  v_payout:=round(v_contract.base_payout * (
    1 + greatest(0,least(10,coalesce((v_profile.skills->>'negotiation')::numeric,0))) * 0.07
  ))::bigint;
  v_xp:=least(v_xp_cap,round(v_payout*v_xp_rate)::integer);
  v_new_xp:=v_profile.xp+v_xp;
  v_remaining:=v_new_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120;
    exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level:=v_level+1;
  end loop;
  v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  update nexora.wallets set balance=balance+v_payout,total_earned=total_earned+v_payout,
    last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_payout,0,v_payout,'contract_reward',p_contract_id,
    'Dynamic contract reward: '||v_contract.item_id,'completed');
  update nexora.player_profiles set xp=v_new_xp,level=v_level,
    reputation=reputation+round(v_contract.reputation_reward*v_leadership)::bigint,
    updated_at=now() where user_id=p_uid;
  if v_contract.scope='organization' then
    update nexora.organizations set reputation=reputation+v_contract.org_reputation_reward,updated_at=now()
      where id=v_contract.org_id;
  end if;
  update nexora.contract_offers set status='completed',completed_at=now(),updated_at=now() where id=p_contract_id;
  update nexora.notifications set is_read=true,event_key=null
  where user_id=p_uid and event_key='contract-ready:'||p_contract_id;
  if v_contract.scope='personal' then
    perform nexora.record_org_goal_progress(p_uid,'personal_contracts_completed',1);
  else
    perform nexora.record_org_goal_progress(p_uid,'org_contracts_completed',1);
  end if;
  if v_contract.scope='personal' and v_contract.board_date=v_today and
    not exists(select 1 from nexora.contract_offers replacement
      where replacement.scope=v_contract.scope and replacement.board_date=v_today
        and replacement.slot_no=v_contract.slot_no and replacement.status='offered'
        and ((v_contract.scope='personal' and replacement.user_id=v_contract.user_id)
          or (v_contract.scope='organization' and replacement.org_id=v_contract.org_id)))
    and (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
      and e.active=true and e.starts_at<=now() and e.ends_at>now())) then
    perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
      v_contract.slot_no,v_today,v_contract.item_id,v_contract.tier,v_contract.event_id);
  end if;
  return jsonb_build_object('ok',true,'payout',v_payout,'xp',v_xp,
    'reputation',round(v_contract.reputation_reward*v_leadership));
end;
$function$;
