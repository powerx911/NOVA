-- Safe cancellation/refunds for manufacturing jobs and bounded player market listings.
-- Processing credits remain spent; only the exact input materials are returned.

alter table nexora.manufacturing_jobs
  add column if not exists input_snapshot jsonb not null default '[]'::jsonb,
  add column if not exists batch_count integer not null default 1,
  add column if not exists cancelled_at timestamptz;

alter table nexora.manufacturing_jobs
  drop constraint if exists manufacturing_jobs_status_check;
alter table nexora.manufacturing_jobs
  add constraint manufacturing_jobs_status_check
  check (status in ('running', 'completed', 'cancelled'));

-- Preserve a per-batch snapshot for any job already running when this migration lands.
update nexora.manufacturing_jobs
set batch_count = case
      when recipe_id in ('rec_microchips','rec_precision_frame','rec_synth_polymer','rec_titanium_frame','rec_polymer_composite')
        then greatest(1, output_qty / 2)
      else greatest(1, output_qty)
    end,
    input_snapshot = case recipe_id
      when 'rec_microchips' then '[{"itemId":"silicon_ore","qty":2},{"itemId":"copper_wire","qty":2}]'::jsonb
      when 'rec_precision_frame' then '[{"itemId":"crude_alloy","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb
      when 'rec_synth_polymer' then '[{"itemId":"energy_cells","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb
      when 'rec_quantum_server' then '[{"itemId":"microchips","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb
      when 'rec_logistics_drone' then '[{"itemId":"precision_frame","qty":2},{"itemId":"microchips","qty":1}]'::jsonb
      when 'rec_bio_module' then '[{"itemId":"synth_polymer","qty":2},{"itemId":"rare_minerals","qty":2}]'::jsonb
      when 'rec_titanium_frame' then '[{"itemId":"titanium_ore","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb
      when 'rec_polymer_composite' then '[{"itemId":"polymer_resin","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb
      when 'rec_biotech_module' then '[{"itemId":"biotech_gel","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb
      when 'rec_quantum_server_advanced' then '[{"itemId":"quantum_dust","qty":2},{"itemId":"microchips","qty":1}]'::jsonb
      else '[]'::jsonb
    end
where status = 'running' and input_snapshot = '[]'::jsonb;

create or replace function nexora.enforce_player_inventory_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_level integer;
  v_capacity bigint;
  v_total bigint;
begin
  if current_setting('nexora.allow_inventory_refund', true) = 'true' then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.user_id, 0));
  select level into v_level
  from nexora.player_profiles
  where user_id = new.user_id;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_capacity := nexora.player_inventory_capacity(v_level);
  select coalesce(sum(quantity), 0) into v_total
  from nexora.inventory
  where user_id = new.user_id;

  if v_total > v_capacity then
    if tg_op = 'INSERT' or new.quantity > old.quantity then
      raise exception 'INVENTORY_CAPACITY_EXCEEDED'
        using detail = format('Inventory capacity is %s units; attempted total is %s units.', v_capacity, v_total);
    end if;
  end if;
  return null;
end;
$$;

create or replace function nexora.prepare_manufacturing_job()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- There must be exactly one player-facing recipe for Quantum Server.
  if new.recipe_id = 'rec_quantum_server_advanced' then
    raise exception 'INVALID_RECIPE';
  end if;

  if new.input_snapshot is null or new.input_snapshot = '[]'::jsonb then
    new.input_snapshot := case new.recipe_id
      when 'rec_microchips' then '[{"itemId":"silicon_ore","qty":2},{"itemId":"copper_wire","qty":2}]'::jsonb
      when 'rec_precision_frame' then '[{"itemId":"crude_alloy","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb
      when 'rec_synth_polymer' then '[{"itemId":"energy_cells","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb
      when 'rec_quantum_server' then '[{"itemId":"microchips","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb
      when 'rec_logistics_drone' then '[{"itemId":"precision_frame","qty":2},{"itemId":"microchips","qty":1}]'::jsonb
      when 'rec_bio_module' then '[{"itemId":"synth_polymer","qty":2},{"itemId":"rare_minerals","qty":2}]'::jsonb
      when 'rec_titanium_frame' then '[{"itemId":"titanium_ore","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb
      when 'rec_polymer_composite' then '[{"itemId":"polymer_resin","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb
      when 'rec_biotech_module' then '[{"itemId":"biotech_gel","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb
      else '[]'::jsonb
    end;
  end if;

  if jsonb_typeof(new.input_snapshot) <> 'array' or jsonb_array_length(new.input_snapshot) = 0 then
    raise exception 'INVALID_RECIPE';
  end if;

  if new.recipe_id in ('rec_microchips','rec_precision_frame','rec_synth_polymer','rec_titanium_frame','rec_polymer_composite') then
    if new.output_qty % 2 <> 0 then raise exception 'INVALID_MANUFACTURING_OUTPUT'; end if;
    new.batch_count := greatest(1, new.output_qty / 2);
  else
    new.batch_count := greatest(1, new.output_qty);
  end if;
  return new;
end;
$$;

drop trigger if exists manufacturing_job_input_snapshot on nexora.manufacturing_jobs;
create trigger manufacturing_job_input_snapshot
before insert on nexora.manufacturing_jobs
for each row execute function nexora.prepare_manufacturing_job();

create or replace function nexora.cancel_manufacturing_job(p_uid text, p_job_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_job nexora.manufacturing_jobs%rowtype;
  v_item record;
begin
  select * into v_job
  from nexora.manufacturing_jobs
  where id = p_job_id and user_id = p_uid
  for update;
  if not found then raise exception 'MANUFACTURING_JOB_NOT_FOUND'; end if;

  if v_job.status = 'cancelled' then
    return jsonb_build_object('ok', true, 'already_cancelled', true, 'returned_items', v_job.input_snapshot);
  end if;
  if v_job.status = 'completed' then
    raise exception 'MANUFACTURING_JOB_ALREADY_COMPLETED';
  end if;
  if v_job.ends_at <= now() then
    raise exception 'MANUFACTURING_JOB_ALREADY_FINISHED';
  end if;
  if jsonb_typeof(v_job.input_snapshot) <> 'array' or jsonb_array_length(v_job.input_snapshot) = 0 then
    raise exception 'MANUFACTURING_REFUND_SNAPSHOT_MISSING';
  end if;

  -- A refund must never be blocked by newly filled inventory slots: restoring consumed
  -- inputs is a reversal of the reservation, not a new purchase.
  perform set_config('nexora.allow_inventory_refund', 'true', true);
  for v_item in
    select value->>'itemId' as item_id, sum((value->>'qty')::integer)::integer as qty
    from jsonb_array_elements(v_job.input_snapshot)
    group by value->>'itemId'
    order by value->>'itemId'
  loop
    insert into nexora.inventory(user_id, item_id, quantity)
    values (p_uid, v_item.item_id, v_item.qty * v_job.batch_count)
    on conflict (user_id, item_id)
    do update set quantity = nexora.inventory.quantity + excluded.quantity, updated_at = now();
  end loop;
  perform set_config('nexora.allow_inventory_refund', 'false', true);

  update nexora.manufacturing_jobs
  set status = 'cancelled', cancelled_at = now()
  where id = p_job_id;

  return jsonb_build_object(
    'ok', true,
    'already_cancelled', false,
    'returned_batches', v_job.batch_count,
    'returned_items', v_job.input_snapshot
  );
end;
$function$;

create or replace function nexora.complete_manufacturing_job(p_uid text, p_job_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_job nexora.manufacturing_jobs%rowtype;
  v_profile nexora.player_profiles%rowtype;
  v_new_xp bigint;
  v_level integer := 1;
  v_remaining bigint;
  v_step bigint;
  v_levels_gained integer;
  v_leadership numeric;
  v_stats jsonb;
  v_capacity bigint;
  v_total bigint;
begin
  select * into v_job
  from nexora.manufacturing_jobs
  where id = p_job_id and user_id = p_uid
  for update;
  if not found then raise exception 'MANUFACTURING_JOB_NOT_FOUND'; end if;
  if v_job.status = 'cancelled' then raise exception 'MANUFACTURING_JOB_CANCELLED'; end if;
  if v_job.status = 'completed' then
    return jsonb_build_object('ok', true, 'output_item', v_job.output_item_id, 'output_qty', v_job.output_qty, 'already_completed', true);
  end if;
  if v_job.ends_at > now() then raise exception 'MANUFACTURING_JOB_NOT_FINISHED'; end if;

  select * into v_profile from nexora.player_profiles where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_uid, 0));
  select coalesce(sum(quantity), 0) into v_total from nexora.inventory where user_id = p_uid;
  v_capacity := nexora.player_inventory_capacity(v_profile.level);
  if v_total + v_job.output_qty > v_capacity then
    raise exception 'INVENTORY_CAPACITY_EXCEEDED';
  end if;

  insert into nexora.inventory(user_id, item_id, quantity)
  values (p_uid, v_job.output_item_id, v_job.output_qty)
  on conflict (user_id, item_id)
  do update set quantity = nexora.inventory.quantity + excluded.quantity, updated_at = now();

  v_new_xp := v_profile.xp + v_job.xp_reward;
  v_remaining := v_new_xp;
  while v_level < 200 loop
    v_step := 200 + (v_level - 1) * 120;
    exit when v_remaining < v_step;
    v_remaining := v_remaining - v_step;
    v_level := v_level + 1;
  end loop;
  v_levels_gained := greatest(0, v_level - v_profile.level);
  v_leadership := 1 + coalesce((v_profile.skills->>'leadership')::numeric, 0) * 0.1;
  v_stats := jsonb_set(
    coalesce(v_profile.stats, '{}'::jsonb),
    '{totalProduced}',
    to_jsonb(coalesce((v_profile.stats->>'totalProduced')::integer, 0) + v_job.output_qty),
    true
  );

  update nexora.player_profiles
  set xp = v_new_xp, level = v_level, skill_points = skill_points + v_levels_gained * 2,
      reputation = reputation + round(3 * v_leadership)::bigint,
      influence = influence + round(2 * v_leadership)::bigint,
      stats = v_stats, updated_at = now()
  where user_id = p_uid;

  update nexora.manufacturing_jobs
  set status = 'completed', completed_at = now()
  where id = p_job_id;

  return jsonb_build_object('ok', true, 'output_item', v_job.output_item_id, 'output_qty', v_job.output_qty);
end;
$function$;

create or replace function nexora.market_price_bounds(p_item_id text)
returns table(min_price bigint, max_price bigint)
language sql
immutable
set search_path = ''
as $$
  select greatest(1, floor(prices.base_price * 0.5)::bigint),
         greatest(1, ceil(prices.base_price * 2)::bigint)
  from (values
    ('silicon_ore', 35::numeric),
    ('copper_wire', 28::numeric),
    ('energy_cells', 45::numeric),
    ('crude_alloy', 40::numeric),
    ('carbon_fiber', 55::numeric),
    ('rare_minerals', 70::numeric),
    ('microchips', 145::numeric),
    ('precision_frame', 175::numeric),
    ('synth_polymer', 190::numeric),
    ('quantum_server', 560::numeric),
    ('logistics_drone', 620::numeric),
    ('bio_module', 680::numeric)
  ) as prices(item_id, base_price)
  where prices.item_id = p_item_id;
$$;

create or replace function nexora.enforce_market_listing_price_bounds()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_min bigint;
  v_max bigint;
begin
  select min_price, max_price into v_min, v_max
  from nexora.market_price_bounds(new.item_id);
  if v_min is null or v_max is null then raise exception 'INVALID_ITEM'; end if;
  if new.unit_price < v_min then raise exception 'PRICE_BELOW_MINIMUM'; end if;
  if new.unit_price > v_max then raise exception 'PRICE_ABOVE_MAXIMUM'; end if;
  return new;
end;
$$;

drop trigger if exists market_listing_price_bounds on nexora.market_listings;
create trigger market_listing_price_bounds
before insert or update of item_id, unit_price on nexora.market_listings
for each row execute function nexora.enforce_market_listing_price_bounds();

revoke all on function nexora.prepare_manufacturing_job() from public, anon, authenticated;
revoke all on function nexora.cancel_manufacturing_job(text, text) from public, anon, authenticated;
revoke all on function nexora.market_price_bounds(text) from public, anon, authenticated;
revoke all on function nexora.enforce_market_listing_price_bounds() from public, anon, authenticated;
grant execute on function nexora.cancel_manufacturing_job(text, text) to service_role;
grant execute on function nexora.market_price_bounds(text) to service_role;
