-- Atomic idempotency for money-moving commands and quote-checked market batches.
-- The browser never receives direct access to this ledger; all writes go through nexora-api.

create table if not exists nexora.idempotency_requests (
  user_id text not null, action text not null, request_id text not null,
  request_hash text not null, response jsonb, created_at timestamptz not null default now(),
  primary key (user_id, action, request_id),
  constraint idempotency_request_id_length check (length(request_id) between 16 and 128)
);
create index if not exists idempotency_requests_created_at_idx on nexora.idempotency_requests (created_at desc);
alter table nexora.idempotency_requests enable row level security;
revoke all on table nexora.idempotency_requests from public, anon, authenticated;
grant select, insert, update, delete on table nexora.idempotency_requests to service_role;

create or replace function nexora.transfer_credits_idempotent(p_uid text, p_recipient_username text, p_amount bigint, p_note text, p_request_id text)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_hash text; v_existing nexora.idempotency_requests%rowtype; v_response jsonb;
begin
  if p_request_id is null or p_request_id !~ '^[A-Za-z0-9:_-]{16,128}$' then raise exception 'INVALID_IDEMPOTENCY_KEY'; end if;
  v_hash := md5(jsonb_build_object('recipient', lower(btrim(coalesce(p_recipient_username, ''))), 'amount', p_amount, 'note', left(coalesce(p_note, ''), 180))::text);
  insert into nexora.idempotency_requests(user_id, action, request_id, request_hash)
  values (p_uid, 'transfer_credits', p_request_id, v_hash) on conflict (user_id, action, request_id) do nothing;
  select * into v_existing from nexora.idempotency_requests where user_id=p_uid and action='transfer_credits' and request_id=p_request_id for update;
  if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_KEY_REUSED'; end if;
  if v_existing.response is not null then return v_existing.response || jsonb_build_object('idempotent_replay', true); end if;
  v_response := nexora.transfer_credits(p_uid, p_recipient_username, p_amount, p_note);
  update nexora.idempotency_requests set response=v_response where user_id=p_uid and action='transfer_credits' and request_id=p_request_id;
  return v_response;
end;
$function$;

create or replace function nexora.deposit_org_treasury_idempotent(p_uid text, p_org_id text, p_amount bigint, p_request_id text)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare v_hash text; v_existing nexora.idempotency_requests%rowtype; v_response jsonb;
begin
  if p_request_id is null or p_request_id !~ '^[A-Za-z0-9:_-]{16,128}$' then raise exception 'INVALID_IDEMPOTENCY_KEY'; end if;
  v_hash := md5(jsonb_build_object('org_id', p_org_id, 'amount', p_amount)::text);
  insert into nexora.idempotency_requests(user_id, action, request_id, request_hash)
  values (p_uid, 'org_treasury_deposit', p_request_id, v_hash) on conflict (user_id, action, request_id) do nothing;
  select * into v_existing from nexora.idempotency_requests where user_id=p_uid and action='org_treasury_deposit' and request_id=p_request_id for update;
  if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_KEY_REUSED'; end if;
  if v_existing.response is not null then return v_existing.response || jsonb_build_object('idempotent_replay', true); end if;
  v_response := nexora.deposit_org_treasury(p_uid, p_org_id, p_amount);
  update nexora.idempotency_requests set response=v_response where user_id=p_uid and action='org_treasury_deposit' and request_id=p_request_id;
  return v_response;
end;
$function$;

create or replace function nexora.buy_market_listings_at_quote_idempotent(p_uid text, p_items jsonb, p_requirements jsonb, p_request_id text)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
  v_hash text; v_existing nexora.idempotency_requests%rowtype; v_profile nexora.player_profiles%rowtype;
  v_seller_uids text[]; v_item record; v_listing nexora.market_listings%rowtype;
  v_purchase jsonb; v_purchases jsonb := '[]'::jsonb; v_response jsonb;
  v_requirement record; v_owned integer; v_planned integer;
begin
  if p_request_id is null or p_request_id !~ '^[A-Za-z0-9:_-]{16,128}$' then raise exception 'INVALID_IDEMPOTENCY_KEY'; end if;
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' then raise exception 'INVALID_PURCHASE_PLAN'; end if;
  if jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 100 then raise exception 'INVALID_PURCHASE_PLAN'; end if;
  if p_requirements is null or jsonb_typeof(p_requirements) is distinct from 'array' then raise exception 'INVALID_PURCHASE_PLAN'; end if;
  if jsonb_array_length(p_requirements) > 100 then raise exception 'INVALID_PURCHASE_PLAN'; end if;
  if exists (select 1 from jsonb_to_recordset(p_requirements) as r(item_id text, required_quantity integer)
    where coalesce(item_id, '')='' or coalesce(required_quantity,0)<1) then raise exception 'INVALID_PURCHASE_PLAN'; end if;
  if (select count(*) from jsonb_to_recordset(p_requirements) as r(item_id text, required_quantity integer))
     <> (select count(distinct item_id) from jsonb_to_recordset(p_requirements) as r(item_id text, required_quantity integer)) then raise exception 'INVALID_PURCHASE_PLAN'; end if;
  if exists (select 1 from jsonb_to_recordset(p_items) as x(listing_id text, quantity integer, expected_unit_price bigint)
    where coalesce(listing_id, '')='' or coalesce(quantity,0)<1 or coalesce(expected_unit_price,0)<1) then raise exception 'INVALID_PURCHASE_PLAN'; end if;
  if (select count(*) from jsonb_to_recordset(p_items) as x(listing_id text, quantity integer, expected_unit_price bigint))
     <> (select count(distinct listing_id) from jsonb_to_recordset(p_items) as x(listing_id text, quantity integer, expected_unit_price bigint)) then raise exception 'INVALID_PURCHASE_PLAN'; end if;

  v_hash := md5(jsonb_build_object('items',p_items,'requirements',p_requirements)::text);
  insert into nexora.idempotency_requests(user_id, action, request_id, request_hash)
  values (p_uid, 'buy_market_listings', p_request_id, v_hash) on conflict (user_id, action, request_id) do nothing;
  select * into v_existing from nexora.idempotency_requests where user_id=p_uid and action='buy_market_listings' and request_id=p_request_id for update;
  if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_KEY_REUSED'; end if;
  if v_existing.response is not null then return v_existing.response || jsonb_build_object('idempotent_replay', true); end if;

  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select array_agg(distinct l.seller_uid) into v_seller_uids
  from jsonb_to_recordset(p_items) as x(listing_id text, quantity integer, expected_unit_price bigint)
  join nexora.market_listings l on l.id=x.listing_id where l.seller_uid <> 'SYSTEM';

  -- Match the existing market RPC lock order: profile, wallets by uid, then listings.
  perform 1 from nexora.wallets w
  where w.user_id=p_uid or w.user_id=any(coalesce(v_seller_uids,array[]::text[]))
  order by w.user_id for update;

  -- Lock and validate every quoted listing before changing any inventory or wallet.
  for v_item in select * from jsonb_to_recordset(p_items)
    as x(listing_id text, quantity integer, expected_unit_price bigint) order by listing_id
  loop
    select * into v_listing from nexora.market_listings where id=v_item.listing_id for update;
    if not found then raise exception 'LISTING_NOT_FOUND'; end if;
    if v_listing.seller_uid=p_uid then raise exception 'CANNOT_BUY_OWN_LISTING'; end if;
    if v_listing.status <> 'active' or v_listing.remaining_qty < v_item.quantity then raise exception 'INSUFFICIENT_LISTING_QTY'; end if;
    if v_listing.unit_price <> v_item.expected_unit_price then raise exception 'MARKET_QUOTE_CHANGED'; end if;
  end loop;

  -- Recheck the player's real inventory under row locks so a stale quote cannot overbuy.
  if jsonb_array_length(p_requirements) > 0 then
    if exists (
      select 1 from jsonb_to_recordset(p_items) as x(listing_id text, quantity integer, expected_unit_price bigint)
      join nexora.market_listings l on l.id=x.listing_id
      where not exists (select 1 from jsonb_to_recordset(p_requirements) as r(item_id text, required_quantity integer) where r.item_id=l.item_id)
    ) then raise exception 'INVALID_PURCHASE_PLAN'; end if;
    for v_requirement in select * from jsonb_to_recordset(p_requirements) as r(item_id text, required_quantity integer)
    loop
      select quantity into v_owned from nexora.inventory where user_id=p_uid and item_id=v_requirement.item_id for update;
      if not found then v_owned:=0; end if;
      select coalesce(sum(x.quantity),0)::integer into v_planned
      from jsonb_to_recordset(p_items) as x(listing_id text, quantity integer, expected_unit_price bigint)
      join nexora.market_listings l on l.id=x.listing_id where l.item_id=v_requirement.item_id;
      if v_owned + v_planned <> v_requirement.required_quantity then raise exception 'INVENTORY_REQUIREMENT_CHANGED'; end if;
    end loop;
  end if;

  for v_item in select * from jsonb_to_recordset(p_items)
    as x(listing_id text, quantity integer, expected_unit_price bigint) order by listing_id
  loop
    v_purchase := nexora.buy_market_listing(p_uid, v_item.listing_id, v_item.quantity);
    v_purchases := v_purchases || jsonb_build_array(v_purchase);
  end loop;

  v_response := jsonb_build_object('purchases',v_purchases,'purchase_count',jsonb_array_length(v_purchases));
  update nexora.idempotency_requests set response=v_response where user_id=p_uid and action='buy_market_listings' and request_id=p_request_id;
  return v_response;
end;
$function$;

-- Prevent bypassing the idempotent Edge API entry points.
revoke all on function nexora.transfer_credits(text,text,bigint,text) from public, anon, authenticated;
revoke all on function nexora.buy_market_listing(text,text,integer) from public, anon, authenticated;
revoke all on function nexora.deposit_org_treasury(text,text,bigint) from public, anon, authenticated;
revoke all on function nexora.transfer_credits_idempotent(text,text,bigint,text,text) from public, anon, authenticated;
revoke all on function nexora.deposit_org_treasury_idempotent(text,text,bigint,text) from public, anon, authenticated;
revoke all on function nexora.buy_market_listings_at_quote_idempotent(text,jsonb,jsonb,text) from public, anon, authenticated;
grant execute on function nexora.transfer_credits_idempotent(text,text,bigint,text,text) to service_role;
grant execute on function nexora.deposit_org_treasury_idempotent(text,text,bigint,text) to service_role;
grant execute on function nexora.buy_market_listings_at_quote_idempotent(text,jsonb,jsonb,text) to service_role;
