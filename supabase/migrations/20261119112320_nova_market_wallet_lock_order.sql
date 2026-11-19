-- Lock buyer/seller wallets in a deterministic order for reciprocal market purchases.
-- Keeps the no-XP market purchase behavior introduced in 20261119006000.
create or replace function nexora.buy_market_listing(p_uid text,p_listing_id text,p_qty integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_listing nexora.market_listings%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_seller nexora.wallets%rowtype;
  v_inventory nexora.inventory%rowtype;
  v_total bigint;
  v_fee bigint;
  v_net bigint;
  v_tax numeric;
  v_event_delta numeric;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_order text;
  v_stats jsonb;
  v_expected_seller text;
begin
  if p_qty is null or p_qty < 1 then raise exception 'INVALID_QUANTITY'; end if;

  -- Profile first, then all involved wallets in uid order, then the listing row.
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select * into v_listing from nexora.market_listings where id=p_listing_id;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.seller_uid=p_uid then raise exception 'CANNOT_BUY_OWN_LISTING'; end if;
  v_expected_seller:=v_listing.seller_uid;

  if v_expected_seller<>'SYSTEM' then
    perform 1 from nexora.wallets
      where user_id in (p_uid,v_expected_seller)
      order by user_id
      for update;
  else
    perform 1 from nexora.wallets where user_id=p_uid for update;
  end if;

  select * into v_listing from nexora.market_listings where id=p_listing_id for update;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.seller_uid is distinct from v_expected_seller then raise exception 'LISTING_CHANGED_RETRY'; end if;
  if v_listing.status <> 'active' or v_listing.remaining_qty < p_qty then raise exception 'INSUFFICIENT_LISTING_QTY'; end if;

  select * into v_wallet from nexora.wallets where user_id=p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_total := v_listing.unit_price * p_qty;
  if v_wallet.balance < v_total then raise exception 'INSUFFICIENT_FUNDS'; end if;

  v_event_delta := coalesce((select sum(tax_delta) from nexora.world_events where active=true and starts_at <= now() and ends_at > now()),0);
  v_tax := greatest(0.01,least(0.12,0.05 - coalesce((v_profile.skills->>'trade')::numeric,0)*0.004 + v_event_delta));
  v_fee := round(v_total * v_tax)::bigint;
  v_net := v_total - v_fee;

  if v_listing.seller_uid <> 'SYSTEM' then
    select * into v_seller from nexora.wallets where user_id=v_listing.seller_uid;
    if not found then raise exception 'SELLER_ACCOUNT_NOT_FOUND'; end if;
  end if;

  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=v_listing.item_id for update;
  update nexora.wallets set balance=balance-v_total,total_spent=total_spent+v_total,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  if v_listing.seller_uid <> 'SYSTEM' then
    update nexora.wallets set balance=balance+v_net,total_earned=total_earned+v_net,last_tx_id=v_tx,updated_at=now() where user_id=v_listing.seller_uid;
  end if;

  update nexora.market_listings set remaining_qty=remaining_qty-p_qty,
    status=case when remaining_qty-p_qty=0 then 'sold' else 'active' end,updated_at=now()
    where id=p_listing_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
    values(v_tx,p_uid,v_listing.seller_uid,v_total,v_fee,v_net,'market_buy',p_listing_id,
      'Market buy: '||p_qty::text||'x '||v_listing.item_id,'completed');
  v_order:='ord_'||v_tx;
  insert into nexora.market_orders(id,listing_id,buyer_uid,seller_uid,item_id,quantity,unit_price,total_price,tax_amount,tx_id)
    values(v_order,p_listing_id,p_uid,v_listing.seller_uid,v_listing.item_id,p_qty,v_listing.unit_price,v_total,v_fee,v_tx);

  if v_inventory.user_id is null then
    insert into nexora.inventory(user_id,item_id,quantity) values(p_uid,v_listing.item_id,p_qty);
  else
    update nexora.inventory set quantity=quantity+p_qty,updated_at=now()
      where user_id=p_uid and item_id=v_listing.item_id;
  end if;

  v_stats:=jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{tradesCount}',
    to_jsonb(coalesce((v_profile.stats->>'tradesCount')::integer,0)+1),true);
  -- Market purchases count toward trade statistics only; they grant no XP, reputation, or influence.
  update nexora.player_profiles set stats=v_stats,updated_at=now() where user_id=p_uid;
  return jsonb_build_object('ok',true,'order_id',v_order,'transaction_id',v_tx,'total',v_total,'tax',v_fee);
end;
$$;

revoke all on function nexora.buy_market_listing(text,text,integer) from public,anon,authenticated;
grant execute on function nexora.buy_market_listing(text,text,integer) to service_role;
