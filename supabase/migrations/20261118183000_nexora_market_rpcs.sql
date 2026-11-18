create or replace function nexora.create_market_listing(p_uid text,p_item_id text,p_qty integer,p_unit_price bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_inventory nexora.inventory%rowtype; v_username text; v_id text := 'lst_' || gen_random_uuid()::text;
begin
  if p_item_id not in ('silicon_ore','copper_wire','energy_cells','crude_alloy','carbon_fiber','rare_minerals','microchips','precision_frame','synth_polymer','quantum_server','logistics_drone','bio_module') then raise exception 'INVALID_ITEM'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 10000 or p_unit_price is null or p_unit_price < 1 or p_unit_price > 1000000 then raise exception 'INVALID_LISTING_PARAMS'; end if;
  select username into v_username from nexora.player_profiles where user_id=p_uid;
  if v_username is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=p_item_id for update;
  if not found or v_inventory.quantity < p_qty then raise exception 'INSUFFICIENT_INVENTORY'; end if;
  update nexora.inventory set quantity=quantity-p_qty,updated_at=now() where user_id=p_uid and item_id=p_item_id;
  insert into nexora.market_listings(id,seller_uid,seller_name,item_id,quantity,remaining_qty,unit_price,status)
  values(v_id,p_uid,v_username,p_item_id,p_qty,p_qty,p_unit_price,'active');
  return jsonb_build_object('ok',true,'listing_id',v_id);
end;
$$;

create or replace function nexora.buy_market_listing(p_uid text,p_listing_id text,p_qty integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_listing nexora.market_listings%rowtype; v_wallet nexora.wallets%rowtype;
  v_profile nexora.player_profiles%rowtype; v_seller nexora.wallets%rowtype;
  v_inventory nexora.inventory%rowtype; v_total bigint; v_fee bigint; v_net bigint;
  v_tax numeric; v_event_delta numeric; v_tx text := 'tx_' || gen_random_uuid()::text;
  v_order text; v_new_xp bigint; v_level integer := 1; v_remaining bigint; v_step bigint;
  v_levels_gained integer; v_leadership numeric; v_stats jsonb;
begin
  if p_qty is null or p_qty < 1 then raise exception 'INVALID_QUANTITY'; end if;
  select * into v_listing from nexora.market_listings where id=p_listing_id for update;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.status <> 'active' or v_listing.remaining_qty < p_qty then raise exception 'INSUFFICIENT_LISTING_QTY'; end if;
  if v_listing.seller_uid=p_uid then raise exception 'CANNOT_BUY_OWN_LISTING'; end if;
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_total := v_listing.unit_price * p_qty;
  if v_wallet.balance < v_total then raise exception 'INSUFFICIENT_FUNDS'; end if;
  v_event_delta := coalesce((select sum(tax_delta) from nexora.world_events where active=true and starts_at <= now() and ends_at > now()),0);
  v_tax := greatest(0.01,least(0.12,0.05 - coalesce((v_profile.skills->>'trade')::numeric,0)*0.004 + v_event_delta));
  v_fee := round(v_total * v_tax)::bigint; v_net := v_total - v_fee;
  if v_listing.seller_uid <> 'SYSTEM' then
    select * into v_seller from nexora.wallets where user_id=v_listing.seller_uid for update;
    if not found then raise exception 'SELLER_ACCOUNT_NOT_FOUND'; end if;
  end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=v_listing.item_id for update;
  update nexora.wallets set balance=balance-v_total,total_spent=total_spent+v_total,last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  if v_listing.seller_uid <> 'SYSTEM' then
    update nexora.wallets set balance=balance+v_net,total_earned=total_earned+v_net,last_tx_id=v_tx,updated_at=now() where user_id=v_listing.seller_uid;
  end if;
  update nexora.market_listings set remaining_qty=remaining_qty-p_qty,status=case when remaining_qty-p_qty=0 then 'sold' else 'active' end,updated_at=now() where id=p_listing_id;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,v_listing.seller_uid,v_total,v_fee,v_net,'market_buy',p_listing_id,'Market buy: ' || p_qty::text || 'x ' || v_listing.item_id,'completed');
  v_order := 'ord_' || v_tx;
  insert into nexora.market_orders(id,listing_id,buyer_uid,seller_uid,item_id,quantity,unit_price,total_price,tax_amount,tx_id)
  values(v_order,p_listing_id,p_uid,v_listing.seller_uid,v_listing.item_id,p_qty,v_listing.unit_price,v_total,v_fee,v_tx);
  if v_inventory.user_id is null then insert into nexora.inventory(user_id,item_id,quantity) values(p_uid,v_listing.item_id,p_qty);
  else update nexora.inventory set quantity=quantity+p_qty,updated_at=now() where user_id=p_uid and item_id=v_listing.item_id; end if;
  v_new_xp := v_profile.xp + 25 + least(50,p_qty*2); v_remaining := v_new_xp;
  while v_level < 200 loop
    v_step := 200 + (v_level-1)*120; exit when v_remaining < v_step;
    v_remaining := v_remaining-v_step; v_level := v_level+1;
  end loop;
  v_levels_gained := greatest(0,v_level-v_profile.level);
  v_leadership := 1 + coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  v_stats := jsonb_set(coalesce(v_profile.stats,'{}'::jsonb),'{tradesCount}',to_jsonb(coalesce((v_profile.stats->>'tradesCount')::integer,0)+1),true);
  update nexora.player_profiles set xp=v_new_xp,level=v_level,skill_points=skill_points+v_levels_gained*2,
    reputation=reputation+round(2*v_leadership)::bigint,influence=influence+round(1*v_leadership)::bigint,stats=v_stats,updated_at=now()
  where user_id=p_uid;
  return jsonb_build_object('ok',true,'order_id',v_order,'transaction_id',v_tx,'total',v_total,'tax',v_fee);
end;
$$;

create or replace function nexora.cancel_market_listing(p_uid text,p_listing_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_listing nexora.market_listings%rowtype;
begin
  select * into v_listing from nexora.market_listings where id=p_listing_id for update;
  if not found then raise exception 'LISTING_NOT_FOUND'; end if;
  if v_listing.seller_uid<>p_uid or v_listing.status<>'active' then raise exception 'CANNOT_CANCEL_LISTING'; end if;
  update nexora.market_listings set remaining_qty=0,status='cancelled',updated_at=now() where id=p_listing_id;
  insert into nexora.inventory(user_id,item_id,quantity,last_listing_id) values(p_uid,v_listing.item_id,v_listing.remaining_qty,p_listing_id)
  on conflict(user_id,item_id) do update set quantity=nexora.inventory.quantity+excluded.quantity,last_listing_id=excluded.last_listing_id,updated_at=now();
  return jsonb_build_object('ok',true,'returned_qty',v_listing.remaining_qty);
end;
$$;

revoke all on function nexora.create_market_listing(text,text,integer,bigint) from public,anon,authenticated;
revoke all on function nexora.buy_market_listing(text,text,integer) from public,anon,authenticated;
revoke all on function nexora.cancel_market_listing(text,text) from public,anon,authenticated;
grant execute on function nexora.create_market_listing(text,text,integer,bigint) to service_role;
grant execute on function nexora.buy_market_listing(text,text,integer) to service_role;
grant execute on function nexora.cancel_market_listing(text,text) to service_role;
