-- Make retries of a NEXORA merchant sale return the original result.
-- The underlying sale remains one atomic transaction with inventory, wallet,
-- daily-cap and transaction-ledger updates.
create or replace function nexora.sell_to_nexora_idempotent(
  p_uid text,
  p_item_id text,
  p_qty integer,
  p_request_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_hash text;
  v_existing nexora.idempotency_requests%rowtype;
  v_response jsonb;
begin
  if p_qty is null or p_qty < 1 then
    raise exception 'INVALID_QUANTITY';
  end if;
  if p_request_id is null or p_request_id !~ '^[A-Za-z0-9:_-]{16,128}$' then
    raise exception 'INVALID_IDEMPOTENCY_KEY';
  end if;

  v_hash := md5(jsonb_build_object(
    'item_id', p_item_id,
    'quantity', p_qty
  )::text);

  insert into nexora.idempotency_requests(user_id, action, request_id, request_hash)
  values (p_uid, 'sell_to_nexora', p_request_id, v_hash)
  on conflict (user_id, action, request_id) do nothing;

  select *
    into v_existing
    from nexora.idempotency_requests
   where user_id = p_uid
     and action = 'sell_to_nexora'
     and request_id = p_request_id
   for update;

  if v_existing.request_hash is distinct from v_hash then
    raise exception 'IDEMPOTENCY_KEY_REUSED';
  end if;

  if v_existing.response is not null then
    return v_existing.response || jsonb_build_object('idempotent_replay', true);
  end if;

  v_response := nexora.sell_to_nexora(p_uid, p_item_id, p_qty);

  update nexora.idempotency_requests
     set response = v_response
   where user_id = p_uid
     and action = 'sell_to_nexora'
     and request_id = p_request_id;

  return v_response;
end;
$function$;

revoke all on function nexora.sell_to_nexora_idempotent(text, text, integer, text) from public, anon, authenticated;
grant execute on function nexora.sell_to_nexora_idempotent(text, text, integer, text) to service_role;
