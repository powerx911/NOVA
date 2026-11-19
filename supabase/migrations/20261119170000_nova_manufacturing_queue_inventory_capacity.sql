-- Player inventory capacity and server-authoritative manufacturing queue.
-- Capacity grows smoothly with player level; each manufactured output unit consumes real production time.
create or replace function nexora.player_inventory_capacity(p_level integer)
returns bigint
language sql immutable
set search_path = ''
as $$
  select 100::bigint + 15::bigint * greatest(0, least(199, coalesce(p_level, 1) - 1));
$$;

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
  perform pg_advisory_xact_lock(hashtextextended(new.user_id, 0));
  select level into v_level
  from nexora.player_profiles
  where user_id = new.user_id;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_capacity := nexora.player_inventory_capacity(v_level);
  select coalesce(sum(quantity), 0) into v_total
  from nexora.inventory
  where user_id = new.user_id;

  if v_total > v_capacity and (tg_op = 'INSERT' or new.quantity > old.quantity) then
    raise exception 'INVENTORY_CAPACITY_EXCEEDED'
      using detail = format('Inventory capacity is %s units; attempted total is %s units.', v_capacity, v_total);
  end if;
  return null;
end;
$$;

drop trigger if exists inventory_capacity_guard on nexora.inventory;
create trigger inventory_capacity_guard
after insert or update of quantity on nexora.inventory
for each row execute function nexora.enforce_player_inventory_capacity();

create table if not exists nexora.manufacturing_jobs (
  id text primary key,
  user_id text not null references nexora.player_profiles(user_id) on delete cascade,
  recipe_id text not null,
  output_item_id text not null,
  output_qty integer not null check (output_qty > 0),
  xp_reward integer not null check (xp_reward >= 0),
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status text not null default 'running' check (status in ('running', 'completed')),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists manufacturing_jobs_one_running_per_player
on nexora.manufacturing_jobs(user_id)
where status = 'running';
create index if not exists manufacturing_jobs_user_created_idx
on nexora.manufacturing_jobs(user_id, created_at desc);

create or replace function nexora.get_manufacturing_job(p_uid text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'id', j.id,
      'recipe_id', j.recipe_id,
      'output_item_id', j.output_item_id,
      'output_qty', j.output_qty,
      'started_at', j.started_at,
      'ends_at', j.ends_at,
      'status', j.status
    )
    from nexora.manufacturing_jobs j
    where j.user_id = p_uid and j.status = 'running'
    order by j.created_at desc
    limit 1
  ), 'null'::jsonb);
$$;

create or replace function nexora.manufacture_recipe(p_uid text, p_recipe_id text, p_batches integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_inputs jsonb;
  v_output text;
  v_output_qty integer;
  v_cost integer;
  v_xp integer;
  v_required integer;
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_item record;
  v_qty integer;
  v_discount numeric;
  v_unit_cost integer;
  v_total bigint;
  v_seconds integer;
  v_tx text := 'tx_' || gen_random_uuid()::text;
  v_job text := 'mfg_' || gen_random_uuid()::text;
  v_ends timestamptz;
begin
  if p_batches is null or p_batches < 1 or p_batches > 999 then
    raise exception 'INVALID_QUANTITY';
  end if;

  case p_recipe_id
    when 'rec_microchips' then v_output:='microchips'; v_output_qty:=2; v_cost:=40; v_xp:=8; v_required:=0; v_inputs:='[{"itemId":"silicon_ore","qty":2},{"itemId":"copper_wire","qty":2}]'::jsonb;
    when 'rec_precision_frame' then v_output:='precision_frame'; v_output_qty:=2; v_cost:=50; v_xp:=9; v_required:=0; v_inputs:='[{"itemId":"crude_alloy","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    when 'rec_synth_polymer' then v_output:='synth_polymer'; v_output_qty:=2; v_cost:=60; v_xp:=10; v_required:=1; v_inputs:='[{"itemId":"energy_cells","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb;
    when 'rec_quantum_server' then v_output:='quantum_server'; v_output_qty:=1; v_cost:=90; v_xp:=12; v_required:=1; v_inputs:='[{"itemId":"microchips","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    when 'rec_logistics_drone' then v_output:='logistics_drone'; v_output_qty:=1; v_cost:=110; v_xp:=14; v_required:=2; v_inputs:='[{"itemId":"precision_frame","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    when 'rec_bio_module' then v_output:='bio_module'; v_output_qty:=1; v_cost:=125; v_xp:=15; v_required:=2; v_inputs:='[{"itemId":"synth_polymer","qty":2},{"itemId":"rare_minerals","qty":2}]'::jsonb;
    when 'rec_titanium_frame' then v_output:='precision_frame'; v_output_qty:=2; v_cost:=80; v_xp:=11; v_required:=1; v_inputs:='[{"itemId":"titanium_ore","qty":2},{"itemId":"carbon_fiber","qty":1}]'::jsonb;
    when 'rec_polymer_composite' then v_output:='synth_polymer'; v_output_qty:=2; v_cost:=90; v_xp:=12; v_required:=1; v_inputs:='[{"itemId":"polymer_resin","qty":2},{"itemId":"energy_cells","qty":1}]'::jsonb;
    when 'rec_biotech_module' then v_output:='bio_module'; v_output_qty:=1; v_cost:=320; v_xp:=16; v_required:=2; v_inputs:='[{"itemId":"biotech_gel","qty":2},{"itemId":"rare_minerals","qty":1}]'::jsonb;
    when 'rec_quantum_server_advanced' then v_output:='quantum_server'; v_output_qty:=1; v_cost:=60; v_xp:=18; v_required:=3; v_inputs:='[{"itemId":"quantum_dust","qty":2},{"itemId":"microchips","qty":1}]'::jsonb;
    else raise exception 'INVALID_RECIPE';
  end case;

  select * into v_profile from nexora.player_profiles where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if coalesce((v_profile.skills->>'industry')::integer, 0) < v_required then
    raise exception 'INDUSTRY_SKILL_TOO_LOW';
  end if;

  if exists (
    select 1 from nexora.manufacturing_jobs
    where user_id = p_uid and status = 'running'
  ) then raise exception 'MANUFACTURING_JOB_IN_PROGRESS'; end if;

  select * into v_wallet from nexora.wallets where user_id = p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_discount := least(0.45, greatest(0, coalesce((v_profile.skills->>'industry')::integer, 0)) * 0.06);
  v_unit_cost := greatest(10, round(v_cost * (1 - v_discount))::integer);
  v_total := v_unit_cost * p_batches;
  if v_wallet.balance < v_total then raise exception 'INSUFFICIENT_FUNDS'; end if;

  -- Aggregate repeated recipe inputs before checking and consuming them.
  -- This prevents duplicate item entries from validating against the same stock twice.
  for v_item in
    select value->>'itemId' as item_id, sum((value->>'qty')::integer)::integer as qty
    from jsonb_array_elements(v_inputs)
    group by value->>'itemId'
    order by value->>'itemId'
  loop
    select quantity into v_qty
    from nexora.inventory
    where user_id = p_uid and item_id = v_item.item_id
    for update;
    if not found or v_qty < v_item.qty * p_batches then raise exception 'MISSING_INPUTS'; end if;
  end loop;

  -- Intermediate goods take 30 seconds per output unit; final goods take 60 seconds.
  v_seconds := greatest(15, (case when v_output in ('quantum_server','logistics_drone','bio_module') then 60 else 30 end) * v_output_qty * p_batches);
  v_ends := now() + make_interval(secs => v_seconds);

  update nexora.wallets
  set balance = balance - v_total, total_spent = total_spent + v_total, last_tx_id = v_tx, updated_at = now()
  where user_id = p_uid;

  for v_item in
    select value->>'itemId' as item_id, sum((value->>'qty')::integer)::integer as qty
    from jsonb_array_elements(v_inputs)
    group by value->>'itemId'
    order by value->>'itemId'
  loop
    update nexora.inventory
    set quantity = quantity - v_item.qty * p_batches, updated_at = now()
    where user_id = p_uid and item_id = v_item.item_id;
  end loop;

  insert into nexora.manufacturing_jobs(
    id, user_id, recipe_id, output_item_id, output_qty, xp_reward, started_at, ends_at, status
  ) values (
    v_job, p_uid, p_recipe_id, v_output, v_output_qty * p_batches, v_xp * p_batches, now(), v_ends, 'running'
  );

  insert into nexora.transactions(id, from_uid, to_uid, amount, fee, net_amount, type, reference_id, description, status)
  values (
    v_tx, p_uid, 'SYSTEM', v_total, 0, v_total, 'manufacturing', p_recipe_id,
    'Started manufacturing ' || (v_output_qty * p_batches)::text || 'x ' || v_output || ' (' || p_batches::text || ' batches)',
    'completed'
  );

  return jsonb_build_object(
    'id', v_job, 'recipe_id', p_recipe_id, 'output_item_id', v_output,
    'output_qty', v_output_qty * p_batches, 'started_at', now(), 'ends_at', v_ends,
    'processing_seconds', v_seconds, 'status', 'running'
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

revoke all on function nexora.player_inventory_capacity(integer) from public, anon, authenticated;
grant execute on function nexora.player_inventory_capacity(integer) to service_role;
revoke all on function nexora.enforce_player_inventory_capacity() from public, anon, authenticated;
revoke all on function nexora.get_manufacturing_job(text) from public, anon, authenticated;
revoke all on function nexora.manufacture_recipe(text, text, integer) from public, anon, authenticated;
revoke all on function nexora.complete_manufacturing_job(text, text) from public, anon, authenticated;
grant execute on function nexora.get_manufacturing_job(text) to service_role;
grant execute on function nexora.manufacture_recipe(text, text, integer) to service_role;
grant execute on function nexora.complete_manufacturing_job(text, text) to service_role;
