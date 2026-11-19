-- Notify on expiry only after a player accepted the contract.
CREATE OR REPLACE FUNCTION nexora.settle_dynamic_contracts(p_uid text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_row nexora.contract_offers%rowtype;
  v_count integer:=0;
  v_today date:=(now() at time zone 'UTC')::date;
begin
  -- Ready transitions are persisted on every contract RPC, not inferred by the client.
  for v_row in
    select * from nexora.contract_offers
    where ((scope='personal' and user_id=p_uid) or (scope='organization' and claimed_by=p_uid))
      and status='processing' and ready_at<=now()
    order by id for update
  loop
    update nexora.contract_offers set status='ready',updated_at=now() where id=v_row.id and status='processing';
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'ntf_'||gen_random_uuid()::text,pp.user_id,
      case when pp.language='ar' then 'العقد جاهز للاستلام' else 'Contract ready to claim' end,
      case when pp.language='ar' then 'انتهت معالجة عقدك وأصبحت المكافأة جاهزة.' else 'Your contract has finished processing and its reward is ready.' end,
      'economy',false
    from nexora.player_private pp where pp.user_id=p_uid and pp.notifications_enabled=true;
  end loop;
  for v_row in
    select * from nexora.contract_offers
    where ((scope='personal' and user_id=p_uid) or
      (scope='organization' and (claimed_by=p_uid or org_id=(select org_id from nexora.player_profiles where user_id=p_uid))))
      and ((status='offered' and offer_expires_at<=now())
        or (status='offered' and event_id is not null and not exists(
          select 1 from nexora.world_events e where e.id=contract_offers.event_id
            and e.active=true and e.starts_at<=now() and e.ends_at>now()))
        or (status='accepted' and deadline_at<=now()))
    order by id for update
  loop
    update nexora.contract_offers set status='expired',updated_at=now() where id=v_row.id;
    v_count:=v_count+1;
    if v_row.board_date=v_today and not exists(select 1 from nexora.contract_offers replacement
        where replacement.scope=v_row.scope and replacement.board_date=v_today
          and replacement.slot_no=v_row.slot_no and replacement.status='offered'
          and ((v_row.scope='personal' and replacement.user_id=v_row.user_id)
            or (v_row.scope='organization' and replacement.org_id=v_row.org_id))) and
      (v_row.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_row.event_id
        and e.active=true and e.starts_at<=now() and e.ends_at>now())) then
      perform nexora.generate_dynamic_contract(v_row.scope,v_row.user_id,v_row.org_id,
        v_row.slot_no,v_today,v_row.item_id,v_row.tier,v_row.event_id);
    end if;
    if v_row.status='accepted' and v_row.deadline_at is not null and v_row.deadline_at<=now() and coalesce(v_row.claimed_by,v_row.user_id) is not null then
      insert into nexora.notifications(id,user_id,title,body,type,is_read)
      select 'ntf_'||gen_random_uuid()::text,pp.user_id,
        case when pp.language='ar' then 'انتهت مهلة العقد' else 'Contract expired' end,
        case when pp.language='ar' then 'انتهت المهلة وتم تحديث خانة العقد بعرض جديد.' else 'The deadline expired and the contract slot was refreshed.' end,
        'economy',false
      from nexora.player_private pp
      where pp.user_id=coalesce(v_row.claimed_by,v_row.user_id) and pp.notifications_enabled=true;
    end if;
  end loop;
  return v_count;
end;
$function$
;

-- Refresh the six system raw resources to exactly 250 available units each day.
-- Keep the seed listing IDs so historical market orders remain linked.
create or replace function nexora.restock_system_raw_market()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_today date := (now() at time zone 'UTC')::date;
  v_item record;
  v_refreshed integer := 0;
begin
  insert into nexora.market_system_restock_runs(restock_date)
  values(v_today)
  on conflict(restock_date) do nothing;
  if not found then return 0; end if;

  for v_item in
    select * from (values
      ('silicon_ore'::text,35::bigint),
      ('copper_wire',28),
      ('energy_cells',45),
      ('crude_alloy',40),
      ('carbon_fiber',55),
      ('rare_minerals',70)
    ) as raw(item_id,unit_price)
  loop
    update nexora.market_listings
    set seller_name='NEXORA CITY',
        quantity=250,
        remaining_qty=250,
        unit_price=v_item.unit_price,
        status='active',
        updated_at=now()
    where id='seed_' || v_item.item_id
      and seller_uid='SYSTEM';

    if not found then
      insert into nexora.market_listings(
        id,seller_uid,seller_name,item_id,quantity,remaining_qty,unit_price,status
      ) values (
        'seed_' || v_item.item_id,'SYSTEM','NEXORA CITY',
        v_item.item_id,250,250,v_item.unit_price,'active'
      );
    end if;

    update nexora.market_listings
    set status='cancelled',remaining_qty=0,updated_at=now()
    where seller_uid='SYSTEM'
      and seller_name='NOVA Exchange'
      and id like 'sys_%'
      and item_id=v_item.item_id
      and status='active';

    v_refreshed := v_refreshed + 1;
  end loop;

  return v_refreshed;
end
$function$;

revoke all on function nexora.restock_system_raw_market() from public, anon, authenticated;

-- Rename and replenish today's stock immediately instead of waiting for the next UTC day.
update nexora.market_listings
set seller_name='NEXORA CITY',
    quantity=250,
    remaining_qty=250,
    unit_price=case item_id
      when 'silicon_ore' then 35
      when 'copper_wire' then 28
      when 'energy_cells' then 45
      when 'crude_alloy' then 40
      when 'carbon_fiber' then 55
      when 'rare_minerals' then 70
    end,
    status='active',
    updated_at=now()
where seller_uid='SYSTEM'
  and id in (
    'seed_silicon_ore','seed_copper_wire','seed_energy_cells',
    'seed_crude_alloy','seed_carbon_fiber','seed_rare_minerals'
  );

-- Retire duplicate daily system listings from the previous source, preserving order history.
update nexora.market_listings
set status='cancelled',remaining_qty=0,updated_at=now()
where seller_uid='SYSTEM'
  and seller_name='NOVA Exchange'
  and id like 'sys_%'
  and item_id in (
    'silicon_ore','copper_wire','energy_cells','crude_alloy','carbon_fiber','rare_minerals'
  )
  and status='active';
