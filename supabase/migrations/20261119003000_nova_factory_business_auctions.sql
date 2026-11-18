-- Add factory assets to the existing company auction flow.
alter table nexora.factories drop constraint if exists factories_level_check;
alter table nexora.factories add constraint factories_level_check check (level between 1 and 100);
alter table nexora.factories
  add column if not exists auction_id text,
  add column if not exists auction_ends_at timestamptz,
  add column if not exists auction_status text;
alter table nexora.company_auctions
  add column if not exists asset_type text not null default 'company',
  add column if not exists factory_id text references nexora.factories(id) on delete set null;
alter table nexora.company_auctions alter column company_id drop not null;
alter table nexora.company_auctions add constraint company_auctions_asset_type_check check (asset_type in ('company','factory'));
alter table nexora.company_auctions drop constraint if exists company_auctions_company_level_check;
alter table nexora.company_auctions add constraint company_auctions_asset_level_check check (company_level >= 50);
create unique index if not exists company_auctions_factory_active_unique
  on nexora.company_auctions(factory_id) where factory_id is not null and status='active';
create unique index if not exists factories_auction_id_unique on nexora.factories(auction_id) where auction_id is not null;

create or replace function nexora.list_factory_for_auction(p_uid text,p_factory_id text,p_starting_price bigint)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare v_factory nexora.factories%rowtype; v_id text:='auc_'||gen_random_uuid()::text; v_ends timestamptz:=now()+interval '24 hours';
begin
  if p_starting_price is null or p_starting_price<1 or p_starting_price>1000000000000 then raise exception 'INVALID_STARTING_PRICE'; end if;
  select * into v_factory from nexora.factories where id=p_factory_id for update;
  if not found then raise exception 'FACTORY_NOT_FOUND'; end if;
  if v_factory.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_factory.level<50 then raise exception 'FACTORY_LEVEL_TOO_LOW'; end if;
  if v_factory.auction_id is not null then raise exception 'FACTORY_ALREADY_LISTED'; end if;
  if (v_factory.upgrade_ends_at is not null and v_factory.upgrade_ends_at>now())
    or (v_factory.warehouse_upgrade_ends_at is not null and v_factory.warehouse_upgrade_ends_at>now()) then raise exception 'FACTORY_UPGRADE_IN_PROGRESS'; end if;
  insert into nexora.company_auctions(id,asset_type,company_id,factory_id,company_name,company_sector,company_level,seller_uid,seller_name,starting_price,current_price,ends_at)
  values(v_id,'factory',null,v_factory.id,v_factory.name,'factory',v_factory.level,p_uid,v_factory.owner_name,p_starting_price,p_starting_price,v_ends);
  update nexora.factories set auction_id=v_id,auction_ends_at=v_ends,auction_status='active',updated_at=now() where id=p_factory_id;
  return jsonb_build_object('auction_id',v_id,'ends_at',v_ends);
end;
$function$;

create or replace function nexora.place_factory_auction_bid(p_uid text,p_auction_id text,p_amount bigint)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  v_a nexora.company_auctions%rowtype; v_p nexora.player_profiles%rowtype; v_w nexora.wallets%rowtype;
  v_e nexora.company_auction_escrows%rowtype; v_charge bigint; v_owned integer; v_reserved integer; v_tx text;
begin
  perform nexora.settle_expired_company_auctions();
  select * into v_a from nexora.company_auctions where id=p_auction_id for update;
  if not found or v_a.asset_type<>'factory' then raise exception 'AUCTION_NOT_FOUND'; end if;
  if v_a.status<>'active' then raise exception 'AUCTION_NOT_ACTIVE'; end if;
  if v_a.ends_at<=now() then return jsonb_build_object('ended',true); end if;
  if v_a.seller_uid=p_uid then raise exception 'CANNOT_BID_OWN_FACTORY'; end if;
  if p_amount is null or p_amount<(case when v_a.highest_bidder_uid is null then v_a.starting_price else v_a.current_price+1 end) then raise exception 'BID_TOO_LOW'; end if;
  select * into v_p from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select count(*) into v_owned from nexora.factories where owner_uid=p_uid;
  select count(*) into v_reserved from nexora.company_auctions where asset_type='factory' and highest_bidder_uid=p_uid and status='active' and ends_at>now() and id<>p_auction_id;
  if v_a.highest_bidder_uid is distinct from p_uid and v_owned+v_reserved>=3 then raise exception 'FACTORY_CAPACITY_REACHED'; end if;
  if v_a.highest_bidder_uid is not null and v_a.highest_bidder_uid<>p_uid then
    select * into v_e from nexora.company_auction_escrows where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid and status='reserved' for update;
    if found then
      update nexora.wallets set balance=balance+v_e.amount,total_spent=greatest(0,total_spent-v_e.amount),updated_at=now() where user_id=v_a.highest_bidder_uid;
      update nexora.company_auction_escrows set status='refunded',updated_at=now() where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
      v_tx:='tx_'||gen_random_uuid()::text;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,'SYSTEM',v_a.highest_bidder_uid,v_e.amount,0,v_e.amount,'factory_auction_refund',p_auction_id,'Refund for an outbid factory auction','completed');
    end if;
  end if;
  select * into v_w from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_a.highest_bidder_uid=p_uid then
    select * into v_e from nexora.company_auction_escrows where auction_id=p_auction_id and bidder_uid=p_uid and status='reserved' for update;
    v_charge:=greatest(0,p_amount-coalesce(v_e.amount,0));
  else v_charge:=p_amount; end if;
  if v_w.balance<v_charge then raise exception 'INSUFFICIENT_FUNDS'; end if;
  if v_charge>0 then
    update nexora.wallets set balance=balance-v_charge,total_spent=total_spent+v_charge,updated_at=now() where user_id=p_uid;
    v_tx:='tx_'||gen_random_uuid()::text;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,'SYSTEM',v_charge,0,v_charge,'factory_auction_escrow',p_auction_id,'Escrow reserved for factory auction bid','completed');
  end if;
  insert into nexora.company_auction_escrows(auction_id,bidder_uid,amount,status,updated_at)
  values(p_auction_id,p_uid,p_amount,'reserved',now())
  on conflict(auction_id,bidder_uid) do update set amount=excluded.amount,status='reserved',updated_at=now();
  update nexora.company_auctions set current_price=p_amount,highest_bidder_uid=p_uid,highest_bidder_name=v_p.username,updated_at=now() where id=p_auction_id;
  insert into nexora.company_auction_bids(id,auction_id,bidder_uid,bidder_name,amount)
  values('abid_'||gen_random_uuid()::text,p_auction_id,p_uid,v_p.username,p_amount);
  return jsonb_build_object('ok',true,'current_price',p_amount,'minimum_next_bid',p_amount+1);
end;
$function$;

create or replace function nexora.settle_factory_auction(p_auction_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare v_a nexora.company_auctions%rowtype; v_f nexora.factories%rowtype; v_e nexora.company_auction_escrows%rowtype; v_tx text;
begin
  select * into v_a from nexora.company_auctions where id=p_auction_id for update;
  if not found or v_a.asset_type<>'factory' then return jsonb_build_object('settled',false,'reason','NOT_FOUND'); end if;
  if v_a.status<>'active' or v_a.ends_at>now() then return jsonb_build_object('settled',false,'reason','NOT_EXPIRED'); end if;
  select * into v_f from nexora.factories where id=v_a.factory_id for update;
  if not found then update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id; return jsonb_build_object('settled',true,'status','cancelled'); end if;
  if v_a.highest_bidder_uid is null then
    update nexora.company_auctions set status='unsold',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.factories set auction_id=null,auction_ends_at=null,auction_status='unsold',updated_at=now() where id=v_a.factory_id;
    return jsonb_build_object('settled',true,'status','unsold');
  end if;
  select * into v_e from nexora.company_auction_escrows where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid and status='reserved' for update;
  if not found or v_e.amount<v_a.current_price then
    if found then
      update nexora.wallets set balance=balance+v_e.amount,total_spent=greatest(0,total_spent-v_e.amount),updated_at=now() where user_id=v_a.highest_bidder_uid;
      update nexora.company_auction_escrows set status='refunded',updated_at=now() where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
    end if;
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.factories set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now() where id=v_a.factory_id;
    return jsonb_build_object('settled',true,'status','cancelled','reason','ESCROW_INVALID');
  end if;
  update nexora.wallets set balance=balance+v_a.current_price,total_earned=total_earned+v_a.current_price,updated_at=now() where user_id=v_a.seller_uid;
  if not found then
    update nexora.wallets set balance=balance+v_e.amount,total_spent=greatest(0,total_spent-v_e.amount),updated_at=now() where user_id=v_a.highest_bidder_uid;
    update nexora.company_auction_escrows set status='refunded',updated_at=now() where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
    v_tx:='tx_'||gen_random_uuid()::text;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,'SYSTEM',v_a.highest_bidder_uid,v_e.amount,0,v_e.amount,'factory_auction_refund',p_auction_id,'Refund because seller wallet is unavailable','completed');
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.factories set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now() where id=v_a.factory_id;
    return jsonb_build_object('settled',true,'status','cancelled','reason','SELLER_WALLET_MISSING');
  end if;
  update nexora.factories set owner_uid=v_a.highest_bidder_uid,owner_name=v_a.highest_bidder_name,auction_id=null,auction_ends_at=null,auction_status='sold',updated_at=now() where id=v_a.factory_id;
  update nexora.company_auction_escrows set status='released',updated_at=now() where auction_id=p_auction_id and bidder_uid=v_a.highest_bidder_uid;
  update nexora.company_auctions set status='sold',winning_bid=v_a.current_price,settled_at=now(),updated_at=now() where id=p_auction_id;
  v_tx:='tx_'||gen_random_uuid()::text;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',v_a.seller_uid,v_a.current_price,0,v_a.current_price,'factory_auction_sale',v_a.factory_id,'Factory sold at auction: '||v_a.company_name,'completed');
  return jsonb_build_object('settled',true,'status','sold','factory_id',v_a.factory_id,'buyer_uid',v_a.highest_bidder_uid,'price',v_a.current_price);
end;
$function$;

create or replace function nexora.settle_expired_company_auctions()
returns integer language plpgsql security definer set search_path to '' as $function$
declare v_row record; v_count integer:=0;
begin
  for v_row in select id,asset_type from nexora.company_auctions where status='active' and ends_at<=now() order by ends_at for update skip locked loop
    if v_row.asset_type='factory' then perform nexora.settle_factory_auction(v_row.id);
    else perform nexora.settle_company_auction(v_row.id); end if;
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$function$;

create or replace function nexora.fetch_company_auctions(p_uid text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare v_result jsonb;
begin
  perform nexora.settle_expired_company_auctions();
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',a.id,'assetType',a.asset_type,'companyId',a.company_id,'factoryId',a.factory_id,
    'companyName',a.company_name,'companySector',a.company_sector,'companyLevel',a.company_level,
    'sellerUid',a.seller_uid,'sellerName',a.seller_name,'startingPrice',a.starting_price,'currentPrice',a.current_price,
    'highestBidderUid',a.highest_bidder_uid,'highestBidderName',a.highest_bidder_name,
    'startsAt',floor(extract(epoch from a.starts_at)*1000)::bigint,'endsAt',floor(extract(epoch from a.ends_at)*1000)::bigint,
    'status',a.status,'winningBid',a.winning_bid,'createdAt',floor(extract(epoch from a.created_at)*1000)::bigint
  ) order by case when a.status='active' then 0 else 1 end,a.ends_at asc),'[]'::jsonb)
  into v_result from nexora.company_auctions a
  where a.status='active' or a.created_at>now()-interval '30 days' or a.seller_uid=p_uid or a.highest_bidder_uid=p_uid;
  return v_result;
end;
$function$;

create or replace function nexora.found_factory(p_uid text,p_name text,p_resource_id text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  v_profile nexora.player_profiles%rowtype; v_wallet nexora.wallets%rowtype; v_cfg record;
  v_count integer; v_reserved integer; v_id text:='fac_'||gen_random_uuid()::text; v_tx text:='tx_'||gen_random_uuid()::text;
begin
  if p_name is null or char_length(btrim(p_name))<2 or char_length(btrim(p_name))>48 then raise exception 'INVALID_NAME'; end if;
  select * into v_cfg from nexora.factory_resource_config(p_resource_id);
  if not found then raise exception 'INVALID_RESOURCE'; end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select count(*) into v_count from nexora.factories where owner_uid=p_uid;
  select count(*) into v_reserved from nexora.company_auctions where asset_type='factory' and highest_bidder_uid=p_uid and status='active' and ends_at>now();
  if v_count+v_reserved>=3 then raise exception 'FACTORY_CAPACITY_REACHED'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_wallet.balance<v_cfg.founding_cost then raise exception 'INSUFFICIENT_FUNDS'; end if;
  insert into nexora.factories(id,owner_uid,owner_name,name,resource_id,level,skill_level,warehouse_qty,last_produced_at,warehouse_level)
  values(v_id,p_uid,v_profile.username,btrim(p_name),p_resource_id,1,0,0,now(),1);
  update nexora.wallets set balance=balance-v_cfg.founding_cost,total_spent=total_spent+v_cfg.founding_cost,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_cfg.founding_cost,0,v_cfg.founding_cost,'factory_create',v_id,'Founded raw-resource factory: '||btrim(p_name),'completed');
  return jsonb_build_object('ok',true,'factory_id',v_id,'cost',v_cfg.founding_cost);
end;
$function$;

revoke all on function nexora.list_factory_for_auction(text,text,bigint) from public;
revoke all on function nexora.place_factory_auction_bid(text,text,bigint) from public;
revoke all on function nexora.settle_factory_auction(text) from public;
grant execute on function nexora.list_factory_for_auction(text,text,bigint) to service_role;
grant execute on function nexora.place_factory_auction_bid(text,text,bigint) to service_role;
grant execute on function nexora.settle_factory_auction(text) to service_role;
