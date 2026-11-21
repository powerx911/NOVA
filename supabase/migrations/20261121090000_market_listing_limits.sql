-- Enforce one active market listing per player/resource and cap each listing at 250.
-- Existing player duplicates were reconciled before adding the unique index.
create unique index if not exists market_listings_one_active_per_seller_item
on nexora.market_listings (seller_uid, item_id)
where status = 'active' and seller_uid <> 'SYSTEM';

create or replace function nexora.create_market_listing(p_uid text, p_item_id text, p_qty integer, p_unit_price bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_inventory nexora.inventory%rowtype;
  v_username text;
  v_id text := 'lst_' || gen_random_uuid()::text;
  v_previous_transfer_setting text;
begin
  if p_item_id not in (
    'silicon_ore','copper_wire','energy_cells','crude_alloy','carbon_fiber','rare_minerals',
    'titanium_ore','polymer_resin','biotech_gel','quantum_dust',
    'microchips','precision_frame','synth_polymer','quantum_server','logistics_drone','bio_module'
  ) then raise exception 'INVALID_ITEM'; end if;

  if p_qty is null or p_qty < 1 or p_qty > 250 or p_unit_price is null or p_unit_price < 1 or p_unit_price > 1000000 then
    raise exception 'INVALID_LISTING_PARAMS';
  end if;

  -- Serialize concurrent attempts for the same seller/resource pair.
  perform pg_advisory_xact_lock(hashtextextended(p_uid || ':' || p_item_id, 0));
  if exists (
    select 1 from nexora.market_listings
    where seller_uid = p_uid and item_id = p_item_id and status = 'active'
  ) then
    raise exception 'ACTIVE_LISTING_EXISTS';
  end if;

  select username into v_username from nexora.player_profiles where user_id=p_uid;
  if v_username is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=p_item_id for update;
  if not found or v_inventory.quantity < p_qty then raise exception 'INSUFFICIENT_INVENTORY'; end if;

  update nexora.inventory set quantity=quantity-p_qty,updated_at=now() where user_id=p_uid and item_id=p_item_id;
  v_previous_transfer_setting:=coalesce(current_setting('nexora.market_listing_transfer',true),'false');
  perform set_config('nexora.market_listing_transfer','true',true);
  insert into nexora.market_listings(id,seller_uid,seller_name,item_id,quantity,remaining_qty,unit_price,status)
  values(v_id,p_uid,v_username,p_item_id,p_qty,p_qty,p_unit_price,'active');
  perform set_config('nexora.market_listing_transfer',v_previous_transfer_setting,true);
  return jsonb_build_object('ok',true,'listing_id',v_id);
end;
$function$;
