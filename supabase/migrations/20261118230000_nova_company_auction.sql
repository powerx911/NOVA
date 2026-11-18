-- Company marketplace, escrow-backed bidding, ownership settlement and company capacity.
create table if not exists nexora.company_auctions (
  id text primary key,
  company_id text not null references nexora.companies(id),
  company_name text not null,
  company_sector text not null,
  company_level integer not null check (company_level >= 50),
  seller_uid text not null,
  seller_name text not null,
  starting_price bigint not null check (starting_price > 0),
  current_price bigint not null check (current_price > 0),
  highest_bidder_uid text,
  highest_bidder_name text,
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status text not null default 'active' check (status in ('active','sold','unsold','cancelled')),
  winning_bid bigint,
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists nexora.company_auction_escrows (
  auction_id text not null references nexora.company_auctions(id),
  bidder_uid text not null,
  amount bigint not null check (amount > 0),
  status text not null default 'reserved' check (status in ('reserved','refunded','released')),
  updated_at timestamptz not null default now(),
  primary key (auction_id, bidder_uid)
);

create table if not exists nexora.company_auction_bids (
  id text primary key,
  auction_id text not null references nexora.company_auctions(id),
  bidder_uid text not null,
  bidder_name text not null,
  amount bigint not null check (amount > 0),
  created_at timestamptz not null default now()
);

alter table nexora.company_auctions drop constraint if exists company_auctions_company_id_fkey;
alter table nexora.company_auctions alter column company_id drop not null;
alter table nexora.company_auctions add constraint company_auctions_company_id_fkey
  foreign key (company_id) references nexora.companies(id) on delete set null;

create index if not exists company_auctions_active_ends_idx
  on nexora.company_auctions(status, ends_at);
create index if not exists company_auctions_seller_idx
  on nexora.company_auctions(seller_uid, created_at desc);
create index if not exists company_auction_bids_auction_idx
  on nexora.company_auction_bids(auction_id, created_at desc);
create index if not exists company_auction_escrows_bidder_idx
  on nexora.company_auction_escrows(bidder_uid, status);

alter table nexora.company_auctions enable row level security;
alter table nexora.company_auction_escrows enable row level security;
alter table nexora.company_auction_bids enable row level security;
revoke all on nexora.company_auctions, nexora.company_auction_escrows, nexora.company_auction_bids from public, anon, authenticated;
grant select, insert, update, delete on nexora.company_auctions, nexora.company_auction_escrows, nexora.company_auction_bids to service_role;

-- Reserve a company slot for each current high bid. A player can own/bid for at most three companies.
create or replace function nexora.enforce_company_capacity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owned integer; v_reserved integer;
begin
  perform 1 from nexora.player_profiles where user_id=new.owner_uid for update;
  select count(*) into v_owned from nexora.companies where owner_uid=new.owner_uid;
  select count(*) into v_reserved from nexora.company_auctions
    where highest_bidder_uid=new.owner_uid and status='active' and ends_at>now();
  if v_owned + v_reserved >= 3 then raise exception 'COMPANY_CAPACITY_REACHED'; end if;
  return new;
end;
$$;
drop trigger if exists companies_capacity_guard on nexora.companies;
create trigger companies_capacity_guard before insert on nexora.companies
for each row execute function nexora.enforce_company_capacity();

create or replace function nexora.settle_company_auction(p_auction_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_auction nexora.company_auctions%rowtype;
  v_company nexora.companies%rowtype;
  v_escrow nexora.company_auction_escrows%rowtype;
  v_tx text;
begin
  select * into v_auction from nexora.company_auctions where id=p_auction_id for update;
  if not found then return jsonb_build_object('settled',false,'reason','NOT_FOUND'); end if;
  if v_auction.status <> 'active' then return jsonb_build_object('settled',false,'reason','ALREADY_SETTLED'); end if;
  if v_auction.ends_at > now() then return jsonb_build_object('settled',false,'reason','NOT_EXPIRED'); end if;

  select * into v_company from nexora.companies where id=v_auction.company_id for update;
  if not found then
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    return jsonb_build_object('settled',true,'status','cancelled');
  end if;

  if v_auction.highest_bidder_uid is null then
    update nexora.company_auctions set status='unsold',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.companies set auction_id=null,auction_ends_at=null,auction_status='unsold',updated_at=now()
      where id=v_auction.company_id;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'notif_'||gen_random_uuid()::text,v_auction.seller_uid,
      'انتهى مزاد شركتك','انتهى المزاد دون عروض شراء. يمكنك عرض الشركة مجدداً.','market',false
    where exists (select 1 from nexora.player_private where user_id=v_auction.seller_uid and notifications_enabled=true);
    insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
      values('clog_'||gen_random_uuid()::text,v_auction.company_id,v_auction.seller_uid,'auction_unsold',0,'انتهى المزاد دون عروض شراء');
    return jsonb_build_object('settled',true,'status','unsold');
  end if;

  select * into v_escrow from nexora.company_auction_escrows
    where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid and status='reserved' for update;
  if not found or v_escrow.amount < v_auction.current_price then
    -- Fail closed: refund the bidder and return the company to its seller.
    if found then
      update nexora.wallets set balance=balance+v_escrow.amount,
        total_spent=greatest(0,total_spent-v_escrow.amount),updated_at=now()
        where user_id=v_auction.highest_bidder_uid;
      update nexora.company_auction_escrows set status='refunded',updated_at=now()
        where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
      v_tx:='tx_'||gen_random_uuid()::text;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
        values(v_tx,'SYSTEM',v_auction.highest_bidder_uid,v_escrow.amount,0,v_escrow.amount,
          'company_auction_refund',p_auction_id,'Refund after company auction settlement failed','completed');
      insert into nexora.notifications(id,user_id,title,body,type,is_read)
      select 'notif_'||gen_random_uuid()::text,v_auction.highest_bidder_uid,
        'أُعيد مبلغ المزايدة','تعذر إتمام بيع الشركة، وأُعيد مبلغ الضمان إلى رصيدك.','market',false
      where exists (select 1 from nexora.player_private where user_id=v_auction.highest_bidder_uid and notifications_enabled=true);
    end if;
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.companies set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now()
      where id=v_auction.company_id;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'notif_'||gen_random_uuid()::text,v_auction.seller_uid,
      'تعذر إتمام بيع الشركة','تعذر تأكيد مبلغ الضمان، وأُلغيت عملية البيع وأُعيدت الأموال المحجوزة.','market',false
    where exists (select 1 from nexora.player_private where user_id=v_auction.seller_uid and notifications_enabled=true);
    return jsonb_build_object('settled',true,'status','cancelled','reason','ESCROW_INVALID');
  end if;

  update nexora.wallets set balance=balance+v_auction.current_price,
    total_earned=total_earned+v_auction.current_price,updated_at=now()
    where user_id=v_auction.seller_uid;
  if not found then
    update nexora.wallets set balance=balance+v_escrow.amount,
      total_spent=greatest(0,total_spent-v_escrow.amount),updated_at=now()
      where user_id=v_auction.highest_bidder_uid;
    update nexora.company_auction_escrows set status='refunded',updated_at=now()
      where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
    v_tx:='tx_'||gen_random_uuid()::text;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,'SYSTEM',v_auction.highest_bidder_uid,v_escrow.amount,0,v_escrow.amount,
        'company_auction_refund',p_auction_id,'Refund because seller settlement account is unavailable','completed');
    update nexora.company_auctions set status='cancelled',settled_at=now(),updated_at=now() where id=p_auction_id;
    update nexora.companies set auction_id=null,auction_ends_at=null,auction_status='cancelled',updated_at=now()
      where id=v_auction.company_id;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'notif_'||gen_random_uuid()::text,v_auction.highest_bidder_uid,
      'تعذر إتمام شراء الشركة','لم نتمكن من إتمام الدفع للبائع، وأُعيد مبلغ المزايدة إلى رصيدك.','market',false
    where exists (select 1 from nexora.player_private where user_id=v_auction.highest_bidder_uid and notifications_enabled=true);
    return jsonb_build_object('settled',true,'status','cancelled','reason','SELLER_WALLET_MISSING');
  end if;

  update nexora.companies set owner_uid=v_auction.highest_bidder_uid,
    owner_name=v_auction.highest_bidder_name,auction_id=null,auction_ends_at=null,auction_status='sold',updated_at=now()
    where id=v_auction.company_id;
  update nexora.company_logs set owner_uid=v_auction.highest_bidder_uid where company_id=v_auction.company_id;
  update nexora.company_auction_escrows set status='released',updated_at=now()
    where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
  update nexora.company_auctions set status='sold',winning_bid=v_auction.current_price,
    settled_at=now(),updated_at=now() where id=p_auction_id;

  v_tx:='tx_'||gen_random_uuid()::text;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,'SYSTEM',v_auction.seller_uid,v_auction.current_price,0,
      v_auction.current_price,'company_auction_sale',v_auction.company_id,
      'Purchased company at auction: '||v_auction.company_name,'completed');
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
    values('clog_'||gen_random_uuid()::text,v_auction.company_id,v_auction.highest_bidder_uid,
      'auction_sold',v_auction.current_price,'تم شراء الشركة في المزاد مقابل $'||v_auction.current_price::text);
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  select 'notif_'||gen_random_uuid()::text,v_auction.seller_uid,
    'تم بيع شركتك في المزاد','تم بيع '||v_auction.company_name||' مقابل $'||v_auction.current_price::text||'. تم إضافة المبلغ إلى رصيدك.','market',false
  where exists (select 1 from nexora.player_private where user_id=v_auction.seller_uid and notifications_enabled=true);
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  select 'notif_'||gen_random_uuid()::text,v_auction.highest_bidder_uid,
    'أصبحت مالكاً لشركة جديدة','فزت بمزاد '||v_auction.company_name||'. تم نقل الملكية إلى حسابك.','market',false
  where exists (select 1 from nexora.player_private where user_id=v_auction.highest_bidder_uid and notifications_enabled=true);
  return jsonb_build_object('settled',true,'status','sold','company_id',v_auction.company_id,'buyer_uid',v_auction.highest_bidder_uid,'price',v_auction.current_price);
end;
$$;

create or replace function nexora.settle_expired_company_auctions()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_row record; v_count integer:=0;
begin
  for v_row in select id from nexora.company_auctions
    where status='active' and ends_at<=now() order by ends_at for update skip locked
  loop
    perform nexora.settle_company_auction(v_row.id);
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

create or replace function nexora.list_company_for_auction(p_uid text,p_company_id text,p_starting_price bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_company nexora.companies%rowtype; v_auction_id text:='auc_'||gen_random_uuid()::text; v_ends timestamptz:=now()+interval '24 hours';
begin
  if p_starting_price is null or p_starting_price<1 or p_starting_price>1000000000000 then raise exception 'INVALID_STARTING_PRICE'; end if;
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.level<50 then raise exception 'COMPANY_LEVEL_TOO_LOW'; end if;
  if v_company.auction_id is not null then raise exception 'COMPANY_ALREADY_LISTED'; end if;
  if v_company.level_upgrade_started_at is not null or v_company.vault_upgrade_started_at is not null then raise exception 'COMPANY_UPGRADE_IN_PROGRESS'; end if;
  insert into nexora.company_auctions(id,company_id,company_name,company_sector,company_level,seller_uid,seller_name,starting_price,current_price,ends_at)
    values(v_auction_id,v_company.id,v_company.name,v_company.sector,v_company.level,p_uid,v_company.owner_name,p_starting_price,p_starting_price,v_ends);
  update nexora.companies set auction_id=v_auction_id,auction_ends_at=v_ends,auction_status='active',updated_at=now() where id=p_company_id;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
    values('clog_'||gen_random_uuid()::text,p_company_id,p_uid,'auction_listed',0,'تم إدراج الشركة في المزاد بسعر بداية $'||p_starting_price::text);
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  select 'notif_'||gen_random_uuid()::text,p_uid,'تم إدراج شركتك في المزاد',
    'بدأ مزاد '||v_company.name||' لمدة 24 ساعة.','market',false
  where exists (select 1 from nexora.player_private where user_id=p_uid and notifications_enabled=true);
  return jsonb_build_object('auction_id',v_auction_id,'ends_at',v_ends);
end;
$$;

create or replace function nexora.place_company_auction_bid(p_uid text,p_auction_id text,p_amount bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_auction nexora.company_auctions%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_old_wallet nexora.wallets%rowtype;
  v_old_escrow nexora.company_auction_escrows%rowtype;
  v_min bigint; v_owned integer; v_reserved integer; v_charge bigint;
  v_tx text; v_log text;
begin
  perform nexora.settle_expired_company_auctions();
  select * into v_auction from nexora.company_auctions where id=p_auction_id for update;
  if not found then raise exception 'AUCTION_NOT_FOUND'; end if;
  if v_auction.status<>'active' then raise exception 'AUCTION_NOT_ACTIVE'; end if;
  if v_auction.ends_at<=now() then return jsonb_build_object('ended',true); end if;
  if v_auction.seller_uid=p_uid then raise exception 'CANNOT_BID_OWN_COMPANY'; end if;
  if p_amount is null or p_amount<1 then raise exception 'INVALID_BID'; end if;
  v_min:=case when v_auction.highest_bidder_uid is null then v_auction.starting_price else v_auction.current_price+1 end;
  if p_amount<v_min then raise exception 'BID_TOO_LOW'; end if;

  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select count(*) into v_owned from nexora.companies where owner_uid=p_uid;
  select count(*) into v_reserved from nexora.company_auctions
    where highest_bidder_uid=p_uid and status='active' and ends_at>now() and id<>p_auction_id;
  if v_auction.highest_bidder_uid is distinct from p_uid and v_owned+v_reserved>=3 then
    raise exception 'COMPANY_CAPACITY_REACHED';
  end if;

  if v_auction.highest_bidder_uid is not null and v_auction.highest_bidder_uid<>p_uid then
    select * into v_old_escrow from nexora.company_auction_escrows
      where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid and status='reserved' for update;
    if found then
      update nexora.wallets set balance=balance+v_old_escrow.amount,
        total_spent=greatest(0,total_spent-v_old_escrow.amount),updated_at=now()
        where user_id=v_auction.highest_bidder_uid;
      update nexora.company_auction_escrows set status='refunded',updated_at=now()
        where auction_id=p_auction_id and bidder_uid=v_auction.highest_bidder_uid;
      v_tx:='tx_'||gen_random_uuid()::text;
      insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
        values(v_tx,'SYSTEM',v_auction.highest_bidder_uid,v_old_escrow.amount,0,v_old_escrow.amount,
          'company_auction_refund',p_auction_id,'Refund for an outbid company auction','completed');
      insert into nexora.notifications(id,user_id,title,body,type,is_read)
      select 'notif_'||gen_random_uuid()::text,v_auction.highest_bidder_uid,
        'تم تجاوز عرضك','تم تجاوز عرضك على شركة '||v_auction.company_name||' وأُعيد مبلغ الضمان إلى رصيدك.','market',false
      where exists (select 1 from nexora.player_private where user_id=v_auction.highest_bidder_uid and notifications_enabled=true);
    end if;
  end if;

  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_auction.highest_bidder_uid=p_uid then
    select * into v_old_escrow from nexora.company_auction_escrows
      where auction_id=p_auction_id and bidder_uid=p_uid and status='reserved' for update;
    v_charge:=greatest(0,p_amount-coalesce(v_old_escrow.amount,0));
  else
    v_charge:=p_amount;
  end if;
  if v_wallet.balance<v_charge then raise exception 'INSUFFICIENT_FUNDS'; end if;
  if v_charge>0 then
    update nexora.wallets set balance=balance-v_charge,total_spent=total_spent+v_charge,updated_at=now() where user_id=p_uid;
    v_tx:='tx_'||gen_random_uuid()::text;
    insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
      values(v_tx,p_uid,'SYSTEM',v_charge,0,v_charge,'company_auction_escrow',p_auction_id,
        'Escrow reserved for bid on '||v_auction.company_name,'completed');
  end if;
  insert into nexora.company_auction_escrows(auction_id,bidder_uid,amount,status,updated_at)
    values(p_auction_id,p_uid,p_amount,'reserved',now())
    on conflict (auction_id,bidder_uid) do update set amount=excluded.amount,status='reserved',updated_at=now();
  update nexora.company_auctions set current_price=p_amount,highest_bidder_uid=p_uid,
    highest_bidder_name=v_profile.username,updated_at=now() where id=p_auction_id;
  insert into nexora.company_auction_bids(id,auction_id,bidder_uid,bidder_name,amount)
    values('abid_'||gen_random_uuid()::text,p_auction_id,p_uid,v_profile.username,p_amount);
  v_log:='clog_'||gen_random_uuid()::text;
  insert into nexora.company_logs(id,company_id,owner_uid,action,amount,details)
    values(v_log,v_auction.company_id,v_auction.seller_uid,'auction_bid',p_amount,
      'عرض شراء جديد بقيمة $'||p_amount::text||' من '||v_profile.username);
  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  select 'notif_'||gen_random_uuid()::text,v_auction.seller_uid,'عرض شراء جديد على شركتك',
    'قدّم '||v_profile.username||' عرضاً بقيمة $'||p_amount::text||' على '||v_auction.company_name||'.','market',false
  where exists (select 1 from nexora.player_private where user_id=v_auction.seller_uid and notifications_enabled=true);
  return jsonb_build_object('ok',true,'current_price',p_amount,'minimum_next_bid',p_amount+1);
end;
$$;

create or replace function nexora.fetch_company_auctions(p_uid text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
  perform nexora.settle_expired_company_auctions();
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',a.id,'companyId',a.company_id,'companyName',a.company_name,'companySector',a.company_sector,
    'companyLevel',a.company_level,'sellerUid',a.seller_uid,'sellerName',a.seller_name,
    'startingPrice',a.starting_price,'currentPrice',a.current_price,
    'highestBidderUid',a.highest_bidder_uid,'highestBidderName',a.highest_bidder_name,
    'startsAt',floor(extract(epoch from a.starts_at)*1000)::bigint,
    'endsAt',floor(extract(epoch from a.ends_at)*1000)::bigint,
    'status',a.status,'winningBid',a.winning_bid,'createdAt',floor(extract(epoch from a.created_at)*1000)::bigint
  ) order by case when a.status='active' then 0 else 1 end,a.ends_at asc), '[]'::jsonb)
  into v_result from nexora.company_auctions a
  where a.status='active' or a.created_at>now()-interval '30 days'
    or a.seller_uid=p_uid or a.highest_bidder_uid=p_uid;
  return v_result;
end;
$$;

create or replace function nexora.delete_company(p_uid text,p_company_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_company nexora.companies%rowtype;
begin
  select * into v_company from nexora.companies where id=p_company_id for update;
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;
  if v_company.owner_uid<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_company.auction_id is not null then raise exception 'COMPANY_IN_AUCTION'; end if;
  delete from nexora.company_logs where company_id=p_company_id;
  delete from nexora.companies where id=p_company_id;
  update nexora.player_profiles set stats=jsonb_set(coalesce(stats,'{}'::jsonb),'{companiesOwned}',
    to_jsonb(greatest(0,coalesce((stats->>'companiesOwned')::integer,0)-1)),true),updated_at=now()
    where user_id=p_uid;
  insert into nexora.audit_logs(id,user_id,action,entity_type,entity_id,details)
    values('audit_'||gen_random_uuid()::text,p_uid,'delete_company','company',p_company_id,
      jsonb_build_object('company_name',v_company.name,'company_level',v_company.level));
  return jsonb_build_object('ok',true);
end;
$$;

revoke all on function nexora.enforce_company_capacity() from public,anon,authenticated;
revoke all on function nexora.settle_company_auction(text) from public,anon,authenticated;
revoke all on function nexora.settle_expired_company_auctions() from public,anon,authenticated;
revoke all on function nexora.list_company_for_auction(text,text,bigint) from public,anon,authenticated;
revoke all on function nexora.place_company_auction_bid(text,text,bigint) from public,anon,authenticated;
revoke all on function nexora.fetch_company_auctions(text) from public,anon,authenticated;
revoke all on function nexora.delete_company(text,text) from public,anon,authenticated;
grant execute on function nexora.settle_company_auction(text) to service_role;
grant execute on function nexora.settle_expired_company_auctions() to service_role;
grant execute on function nexora.list_company_for_auction(text,text,bigint) to service_role;
grant execute on function nexora.place_company_auction_bid(text,text,bigint) to service_role;
grant execute on function nexora.fetch_company_auctions(text) to service_role;
grant execute on function nexora.delete_company(text,text) to service_role;

-- Settle auctions automatically, even when no player is online.
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;
do $
begin
  if not exists (select 1 from cron.job where jobname='nexora-company-auction-settlement') then
    perform cron.schedule('nexora-company-auction-settlement','* * * * *',
      'select nexora.settle_expired_company_auctions();');
  end if;
end;
$$;
