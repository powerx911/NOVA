create table nexora.nexora_daily_sales (
  user_id text not null,
  sale_date date not null default (now() at time zone 'utc')::date,
  amount bigint not null default 0 check (amount >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, sale_date)
);

create or replace function nexora.sell_to_nexora(p_uid text, p_item_id text, p_qty integer)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_base bigint;
  v_price bigint;
  v_total bigint;
  v_sold bigint;
  v_inventory bigint;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_day date := (now() at time zone 'utc')::date;
begin
  if p_qty is null or p_qty < 1 then raise exception 'INVALID_QUANTITY'; end if;
  v_base := case p_item_id
    when 'silicon_ore' then 35 when 'copper_wire' then 28 when 'energy_cells' then 45
    when 'crude_alloy' then 40 when 'carbon_fiber' then 55 when 'rare_minerals' then 70
    when 'titanium_ore' then 85 when 'polymer_resin' then 95 when 'biotech_gel' then 120
    when 'quantum_dust' then 160 when 'microchips' then 145 when 'precision_frame' then 175
    when 'synth_polymer' then 190 when 'quantum_server' then 560 when 'logistics_drone' then 620
    when 'bio_module' then 0 else null end;
  if v_base is null then raise exception 'INVALID_ITEM'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_uid || ':nexora_daily_sale:' || v_day::text, 0));
  select quantity into v_inventory from nexora.inventory where user_id = p_uid and item_id = p_item_id for update;
  if coalesce(v_inventory, 0) < p_qty then raise exception 'INSUFFICIENT_INVENTORY'; end if;
  insert into nexora.nexora_daily_sales(user_id, sale_date, amount) values (p_uid, v_day, 0) on conflict do nothing;
  select amount into v_sold from nexora.nexora_daily_sales where user_id = p_uid and sale_date = v_day for update;
  v_price := greatest(1, round(v_base * 0.60)::bigint);
  v_total := v_price * p_qty;
  if v_sold + v_total > 1500 then raise exception 'DAILY_SALE_LIMIT'; end if;
  perform 1 from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  update nexora.inventory set quantity = quantity - p_qty, updated_at = now() where user_id = p_uid and item_id = p_item_id;
  update nexora.wallets set balance = balance + v_total, total_earned = total_earned + v_total, last_tx_id = v_tx, updated_at = now() where user_id = p_uid;
  update nexora.nexora_daily_sales set amount = amount + v_total, updated_at = now() where user_id = p_uid and sale_date = v_day;
  insert into nexora.transactions(id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status)
  values (v_tx, 'NEXORA', p_uid, v_total, 0, v_total, 'nexora_sale', p_item_id, 'NEXORA purchase: ' || p_qty || 'x ' || p_item_id, 'completed');
  return jsonb_build_object('ok', true, 'quantity', p_qty, 'unit_price', v_price, 'total', v_total, 'daily_sold', v_sold + v_total, 'daily_remaining', 1500 - (v_sold + v_total));
end
$function$;

revoke all on function nexora.sell_to_nexora(text, text, integer) from public, anon, authenticated;
grant execute on function nexora.sell_to_nexora(text, text, integer) to service_role;