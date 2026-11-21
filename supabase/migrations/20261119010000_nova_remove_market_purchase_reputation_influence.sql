-- Market purchases are transactions only; they must not grant reputation or influence.
CREATE OR REPLACE FUNCTION nexora.buy_market_listing(p_uid text, p_listing_id text, p_qty integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
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
BEGIN
  IF p_qty IS NULL OR p_qty < 1 THEN RAISE EXCEPTION 'INVALID_QUANTITY'; END IF;
  SELECT * INTO v_listing FROM nexora.market_listings WHERE id=p_listing_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'LISTING_NOT_FOUND'; END IF;
  IF v_listing.status <> 'active' OR v_listing.remaining_qty < p_qty THEN RAISE EXCEPTION 'INSUFFICIENT_LISTING_QTY'; END IF;
  IF v_listing.seller_uid=p_uid THEN RAISE EXCEPTION 'CANNOT_BUY_OWN_LISTING'; END IF;
  SELECT * INTO v_profile FROM nexora.player_profiles WHERE user_id=p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;
  SELECT * INTO v_wallet FROM nexora.wallets WHERE user_id=p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;

  v_total := v_listing.unit_price * p_qty;
  IF v_wallet.balance < v_total THEN RAISE EXCEPTION 'INSUFFICIENT_FUNDS'; END IF;
  v_event_delta := COALESCE((SELECT SUM(tax_delta) FROM nexora.world_events WHERE active=true AND starts_at <= now() AND ends_at > now()),0);
  v_tax := greatest(0.01,least(0.12,0.05 - coalesce((v_profile.skills->>'trade')::numeric,0)*0.004 + v_event_delta));
  v_fee := round(v_total * v_tax)::bigint;
  v_net := v_total - v_fee;

  IF v_listing.seller_uid <> 'SYSTEM' THEN
    SELECT * INTO v_seller FROM nexora.wallets WHERE user_id=v_listing.seller_uid FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'SELLER_ACCOUNT_NOT_FOUND'; END IF;
  END IF;

  SELECT * INTO v_inventory FROM nexora.inventory WHERE user_id=p_uid AND item_id=v_listing.item_id FOR UPDATE;
  UPDATE nexora.wallets
  SET balance=balance-v_total,total_spent=total_spent+v_total,last_tx_id=v_tx,updated_at=now()
  WHERE user_id=p_uid;

  IF v_listing.seller_uid <> 'SYSTEM' THEN
    UPDATE nexora.wallets
    SET balance=balance+v_net,total_earned=total_earned+v_net,last_tx_id=v_tx,updated_at=now()
    WHERE user_id=v_listing.seller_uid;
  END IF;

  UPDATE nexora.market_listings
  SET remaining_qty=remaining_qty-p_qty,
      status=CASE WHEN remaining_qty-p_qty=0 THEN 'sold' ELSE 'active' END,
      updated_at=now()
  WHERE id=p_listing_id;

  INSERT INTO nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  VALUES(v_tx,p_uid,v_listing.seller_uid,v_total,v_fee,v_net,'market_buy',p_listing_id,'Market buy: ' || p_qty::text || 'x ' || v_listing.item_id,'completed');

  v_order := 'ord_' || v_tx;
  INSERT INTO nexora.market_orders(id,listing_id,buyer_uid,seller_uid,item_id,quantity,unit_price,total_price,tax_amount,tx_id)
  VALUES(v_order,p_listing_id,p_uid,v_listing.seller_uid,v_listing.item_id,p_qty,v_listing.unit_price,v_total,v_fee,v_tx);

  IF v_inventory.user_id IS NULL THEN
    INSERT INTO nexora.inventory(user_id,item_id,quantity) VALUES(p_uid,v_listing.item_id,p_qty);
  ELSE
    UPDATE nexora.inventory SET quantity=quantity+p_qty,updated_at=now()
    WHERE user_id=p_uid AND item_id=v_listing.item_id;
  END IF;

  -- Keep trade statistics, but do not award XP, reputation, or influence for buying.
  v_stats := jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{tradesCount}',
    to_jsonb(coalesce((v_profile.stats->>'tradesCount')::integer,0)+1),true);
  UPDATE nexora.player_profiles SET stats=v_stats,updated_at=now() WHERE user_id=p_uid;

  RETURN jsonb_build_object('ok',true,'order_id',v_order,'transaction_id',v_tx,'total',v_total,'tax',v_fee);
END;
$function$;
