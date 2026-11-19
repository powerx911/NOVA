-- Economy abuse guards: revenue XP follows actual collected income; transfers have progression and daily limits.
-- No production data is touched by this migration until it is explicitly applied.

create or replace function nexora.collect_company_revenue(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_company nexora.companies%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_capacity bigint[]:=array[3500,7000,14000,25000,40000];
  v_vault_level integer;
  v_net bigint;
  v_elapsed numeric;
  v_payout bigint;
  v_now timestamptz:=now();
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_log text:='clog_'||gen_random_uuid()::text;
  v_xp_gain bigint;
  v_xp bigint;
  v_level_after integer:=1;
  v_remaining bigint;
  v_step bigint;
begin
  select * into v_company
  from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.last_collected_at is not null
     and v_now-v_company.last_collected_at<interval '30 seconds' then
    raise exception 'NOTHING_TO_COLLECT';
  end if;

  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found or v_wallet.user_id is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_net:=nexora.company_net_hourly(p_company_id);
  v_vault_level:=greatest(1,least(5,v_company.vault_level));
  v_elapsed:=greatest(0,extract(epoch from (v_now-coalesce(v_company.last_collected_at,v_now)))/3600);
  v_payout:=least(
    v_capacity[v_vault_level],
    greatest(0,coalesce(v_company.vault_balance,0)+floor(v_net*least(12,v_elapsed))::bigint)
  );
  if v_payout<1 then raise exception 'NOTHING_TO_COLLECT'; end if;

  update nexora.wallets
    set balance=balance+v_payout,total_earned=total_earned+v_payout,last_tx_id=v_tx,updated_at=now()
    where user_id=p_uid;
  update nexora.companies
    set total_revenue=total_revenue+v_payout,vault_balance=0,last_collected_at=v_now,updated_at=now()
    where id=p_company_id;

  -- 1 XP per 15 credits actually collected: no minimum reward for tiny API calls,
  -- and no reputation/influence for withdrawing money already earned by the company.
  v_xp_gain:=floor((v_company.total_revenue+v_payout)::numeric/15)::bigint
    - floor(v_company.total_revenue::numeric/15)::bigint;
  v_xp:=v_profile.xp+v_xp_gain;
  v_remaining:=v_xp;
  while v_level_after<200 loop
    v_step:=200+(v_level_after-1)*120;
    exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level_after:=v_level_after+1;
  end loop;

  update nexora.player_profiles
    set xp=v_xp,level=v_level_after,updated_at=now()
    where user_id=p_uid;

  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,'SYSTEM',p_uid,v_payout,0,v_payout,'company_collect',p_company_id,
      'Company revenue collected: '||v_company.name,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
    values(v_log,p_company_id,p_uid,'collect',v_payout,'Collected +$'||v_payout::text);
  return jsonb_build_object('ok',true,'payout',v_payout,'xp_gain',v_xp_gain);
end;
$$;

create or replace function nexora.transfer_credits(p_uid text,p_recipient_username text,p_amount bigint,p_note text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_to_uid text;
  v_profile nexora.player_profiles%rowtype;
  v_from nexora.wallets%rowtype;
  v_to nexora.wallets%rowtype;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_notification text:='ntf_'||gen_random_uuid()::text;
  v_note text:=left(coalesce(btrim(p_note),''),180);
  v_recipient_name text;
  v_fee bigint;
  v_net bigint;
  v_day_start timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC';
  v_transferred_today bigint;
begin
  if p_amount is null or p_amount<=0 then raise exception 'INVALID_AMOUNT'; end if;

  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_profile.level<10 then raise exception 'TRANSFER_LEVEL_REQUIRED'; end if;

  select uid,username into v_to_uid,v_recipient_name
    from nexora.usernames where username_lower=lower(btrim(p_recipient_username));
  if v_to_uid is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
  if v_to_uid=p_uid then raise exception 'SELF_OR_MISSING_RECIPIENT'; end if;

  -- Deterministic wallet lock order prevents opposite-direction transfers from deadlocking.
  perform 1 from nexora.wallets
    where user_id in (p_uid,v_to_uid) order by user_id for update;
  select * into v_from from nexora.wallets where user_id=p_uid;
  select * into v_to from nexora.wallets where user_id=v_to_uid;
  if v_from.user_id is null or v_to.user_id is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;

  select coalesce(sum(amount),0) into v_transferred_today
    from nexora.transactions
    where from_uid=p_uid and type='transfer' and status='completed'
      and created_at>=v_day_start;
  if v_transferred_today+p_amount>10000 then
    raise exception 'TRANSFER_DAILY_LIMIT';
  end if;
  if p_amount>v_from.balance then raise exception 'INSUFFICIENT_FUNDS'; end if;

  v_fee:=round(p_amount*0.03)::bigint;
  v_net:=p_amount-v_fee;
  if v_net<1 then raise exception 'INVALID_AMOUNT'; end if;

  update nexora.wallets
    set balance=balance-p_amount,total_spent=total_spent+p_amount,last_tx_id=v_tx,updated_at=now()
    where user_id=p_uid;
  update nexora.wallets
    set balance=balance+v_net,total_earned=total_earned+v_net,last_tx_id=v_tx,updated_at=now()
    where user_id=v_to_uid;

  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,v_to_uid,p_amount,v_fee,v_net,'transfer',v_to_uid,
      coalesce(nullif(v_note,''),'Transfer to '||v_recipient_name),'completed');
  insert into nexora.audit_logs(id,user_id,action,entity_type,entity_id,details)
    values('aud_'||gen_random_uuid()::text,p_uid,'wallet_transfer','transaction',v_tx,
      jsonb_build_object('recipient_uid',v_to_uid,'amount',p_amount,'fee',v_fee,'net_amount',v_net));
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
    values(v_notification,p_uid,'Transfer Sent',
      '-$'||p_amount::text||' -> '||v_recipient_name||' (3% fee: $'||v_fee::text||')','economy',false);
  return jsonb_build_object('ok',true,'transaction_id',v_tx,'amount',p_amount,'fee',v_fee,'net_amount',v_net,
    'daily_remaining',greatest(0,10000-v_transferred_today-p_amount));
end;
$$;

revoke all on function nexora.collect_company_revenue(text,text) from public,anon,authenticated;
grant execute on function nexora.collect_company_revenue(text,text) to service_role;
revoke all on function nexora.transfer_credits(text,text,bigint,text) from public,anon,authenticated;
grant execute on function nexora.transfer_credits(text,text,bigint,text) to service_role;


-- Auction proceeds incur a 4% seller-side sink fee for both companies and factories.
create or replace function nexora.apply_company_auction_sale_fee()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_fee bigint;
  v_tx text:='tx_'||gen_random_uuid()::text;
begin
  if old.status='active' and new.status='sold' and new.highest_bidder_uid is not null then
    v_fee:=round(new.current_price*0.04)::bigint;
    if v_fee>0 then
      update nexora.wallets
        set balance=balance-v_fee,total_spent=total_spent+v_fee,updated_at=now()
        where user_id=new.seller_uid;
      if not found then raise exception 'SELLER_WALLET_NOT_FOUND'; end if;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
        values(v_tx,new.seller_uid,'SYSTEM',v_fee,0,v_fee,'auction_fee',new.id,
          '4% company/factory auction sale fee','completed');
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists company_auction_sale_fee on nexora.company_auctions;
create trigger company_auction_sale_fee
after update of status on nexora.company_auctions
for each row execute function nexora.apply_company_auction_sale_fee();

-- Anti-sniping: any valid new high bid in the final five minutes resets the close
-- to five minutes after the bid. Applies to both company and factory auctions.
create or replace function nexora.extend_company_auction_on_late_bid()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status='active'
     and new.status='active'
     and (new.current_price>old.current_price or new.highest_bidder_uid is distinct from old.highest_bidder_uid)
     and old.ends_at>now()
     and old.ends_at<=now()+interval '5 minutes' then
    new.ends_at:=now()+interval '5 minutes';
    if new.asset_type='factory' and new.factory_id is not null then
      update nexora.factories
        set auction_ends_at=new.ends_at,updated_at=now()
        where id=new.factory_id and auction_id=new.id;
    elsif new.company_id is not null then
      update nexora.companies
        set auction_ends_at=new.ends_at,updated_at=now()
        where id=new.company_id and auction_id=new.id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists company_auction_late_bid_extension on nexora.company_auctions;
create trigger company_auction_late_bid_extension
before update of current_price on nexora.company_auctions
for each row execute function nexora.extend_company_auction_on_late_bid();

revoke all on function nexora.apply_company_auction_sale_fee() from public,anon,authenticated;
revoke all on function nexora.extend_company_auction_on_late_bid() from public,anon,authenticated;
