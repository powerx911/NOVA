-- NOVA market history, inventory escrow capacity, reliable manufacturing completion,
-- contract board lifecycle corrections, and actionable reward/capacity notifications.

-- Count inventory held directly plus units escrowed in the player's active market offers.
create or replace function nexora.player_inventory_usage(p_uid text)
returns bigint
language sql
volatile
security definer
set search_path = ''
as $function$
  select
    coalesce((select sum(i.quantity) from nexora.inventory i where i.user_id=p_uid),0)
    + coalesce((select sum(l.remaining_qty) from nexora.market_listings l
      where l.seller_uid=p_uid and l.status='active' and l.remaining_qty>0),0);
$function$;

revoke all on function nexora.player_inventory_usage(text) from public,anon,authenticated;
grant execute on function nexora.player_inventory_usage(text) to service_role;

create or replace function nexora.enforce_player_inventory_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_level integer;
  v_capacity bigint;
  v_total bigint;
begin
  if current_setting('nexora.allow_inventory_refund', true) = 'true' then
    return null;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.user_id, 0));
  select level into v_level
  from nexora.player_profiles
  where user_id = new.user_id;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_capacity := nexora.player_inventory_capacity(v_level);
  v_total := nexora.player_inventory_usage(new.user_id);

  if v_total > v_capacity then
    if tg_op='INSERT' then
      raise exception 'INVENTORY_CAPACITY_EXCEEDED'
        using detail = format('Inventory capacity is %s units including active market offers; attempted total is %s units.',v_capacity,v_total);
    elsif new.quantity > old.quantity then
      raise exception 'INVENTORY_CAPACITY_EXCEEDED'
        using detail = format('Inventory capacity is %s units including active market offers; attempted total is %s units.',v_capacity,v_total);
    end if;
  end if;
  return null;
end;
$function$;

-- A second guard protects the combined capacity if a listing is inserted or edited
-- through a future server path that does not first move inventory into escrow.
create or replace function nexora.enforce_market_listing_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_level integer;
  v_capacity bigint;
  v_total bigint;
  v_previous_total bigint;
  v_new_contribution bigint;
  v_old_contribution bigint;
begin
  if new.seller_uid='SYSTEM' or current_setting('nexora.market_listing_transfer',true)='true'
    or new.status <> 'active' or new.remaining_qty <= 0 then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.seller_uid,0));
  select level into v_level from nexora.player_profiles where user_id=new.seller_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  v_capacity:=nexora.player_inventory_capacity(v_level);
  v_total:=nexora.player_inventory_usage(new.seller_uid);
  if v_total>v_capacity then
    if tg_op='INSERT' then
      raise exception 'INVENTORY_CAPACITY_EXCEEDED'
        using detail=format('Inventory capacity is %s units including active market offers; attempted total is %s units.',v_capacity,v_total);
    else
      v_new_contribution:=case when new.status='active' then greatest(0,new.remaining_qty) else 0 end;
      v_old_contribution:=case when old.status='active' then greatest(0,old.remaining_qty) else 0 end;
      v_previous_total:=v_total-v_new_contribution+v_old_contribution;
      if v_total>v_previous_total then
        raise exception 'INVENTORY_CAPACITY_EXCEEDED'
          using detail=format('Inventory capacity is %s units including active market offers; attempted total is %s units.',v_capacity,v_total);
      end if;
    end if;
  end if;
  return null;
end;
$function$;

drop trigger if exists market_listing_capacity_guard on nexora.market_listings;
create trigger market_listing_capacity_guard
after insert or update of remaining_qty,status on nexora.market_listings
for each row execute function nexora.enforce_market_listing_capacity();

revoke all on function nexora.enforce_market_listing_capacity() from public,anon,authenticated;

-- Durable deduplication for ready-reward and capacity notifications.
create table if not exists nexora.notification_events (
  user_id text not null,
  event_key text not null,
  created_at timestamptz not null default now(),
  primary key(user_id,event_key)
);
alter table nexora.notification_events enable row level security;
revoke all on table nexora.notification_events from public,anon,authenticated;

create or replace function nexora.emit_notification_once(
  p_uid text,p_event_key text,p_title_ar text,p_title_en text,
  p_body_ar text,p_body_en text,p_type text default 'economy'
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_language text;
  v_enabled boolean;
  v_inserted text;
begin
  select language,notifications_enabled into v_language,v_enabled
  from nexora.player_private where user_id=p_uid;
  if not found or not coalesce(v_enabled,false) then return; end if;

  insert into nexora.notification_events(user_id,event_key)
  values(p_uid,p_event_key)
  on conflict(user_id,event_key) do nothing
  returning event_key into v_inserted;
  if v_inserted is null then return; end if;

  insert into nexora.notifications(id,user_id,title,body,type,is_read)
  values(
    'ntf_'||gen_random_uuid()::text,p_uid,
    case when v_language='ar' then p_title_ar else p_title_en end,
    case when v_language='ar' then p_body_ar else p_body_en end,
    p_type,false
  );
end;
$function$;

revoke all on function nexora.emit_notification_once(text,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function nexora.emit_notification_once(text,text,text,text,text,text,text) to service_role;


-- Creating a listing is an escrow transfer, not additional storage. The RPC
-- debits inventory first, then marks the insert as that same transfer so legacy
-- over-capacity players can list stock and sell down without creating more units.
do $do$
declare
  v_def text;
begin
  select pg_get_functiondef('nexora.create_market_listing(text,text,integer,bigint)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    'v_id text := ''lst_'' || gen_random_uuid()::text;',
    'v_id text := ''lst_'' || gen_random_uuid()::text; v_previous_transfer_setting text;');
  v_def:=replace(v_def,
    '  update nexora.inventory set quantity=quantity-p_qty,updated_at=now() where user_id=p_uid and item_id=p_item_id;' || chr(10) ||
    '  insert into nexora.market_listings',
    '  update nexora.inventory set quantity=quantity-p_qty,updated_at=now() where user_id=p_uid and item_id=p_item_id;' || chr(10) ||
    '  v_previous_transfer_setting:=coalesce(current_setting(''nexora.market_listing_transfer'',true),''false'');' || chr(10) ||
    '  perform set_config(''nexora.market_listing_transfer'',''true'',true);' || chr(10) ||
    '  insert into nexora.market_listings');
  v_def:=replace(v_def,
    '  values(v_id,p_uid,v_username,p_item_id,p_qty,p_qty,p_unit_price,''active'');' || chr(10) ||
    '  return jsonb_build_object',
    '  values(v_id,p_uid,v_username,p_item_id,p_qty,p_qty,p_unit_price,''active'');' || chr(10) ||
    '  perform set_config(''nexora.market_listing_transfer'',v_previous_transfer_setting,true);' || chr(10) ||
    '  return jsonb_build_object');
  if position('v_previous_transfer_setting' in v_def)=0
    or position('perform set_config(''nexora.market_listing_transfer'',''true'',true)' in v_def)=0
    or position('perform set_config(''nexora.market_listing_transfer'',v_previous_transfer_setting,true)' in v_def)=0 then
    raise exception 'MARKET_LISTING_ESCROW_TRANSFER_PATCH_FAILED';
  end if;
  execute v_def;
end;
$do$;

-- Cancelling a listing returns the same escrowed units to inventory; allow this
-- transfer even for legacy accounts that are already over the new combined cap.
do $do$
declare
  v_def text;
begin
  select pg_get_functiondef('nexora.cancel_market_listing(text,text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    'declare' || chr(10) || '  v_listing nexora.market_listings%rowtype;',
    'declare' || chr(10) || '  v_listing nexora.market_listings%rowtype;' || chr(10) || '  v_previous_refund_setting text;');
  v_def:=replace(v_def,
    '  update nexora.market_listings set remaining_qty=0,status=''cancelled'',updated_at=now() where id=p_listing_id;' || chr(10) ||
    '  insert into nexora.inventory(user_id,item_id,quantity,last_listing_id)',
    '  update nexora.market_listings set remaining_qty=0,status=''cancelled'',updated_at=now() where id=p_listing_id;' || chr(10) ||
    '  v_previous_refund_setting:=coalesce(current_setting(''nexora.allow_inventory_refund'',true),''false'');' || chr(10) ||
    '  perform set_config(''nexora.allow_inventory_refund'',''true'',true);' || chr(10) ||
    '  insert into nexora.inventory(user_id,item_id,quantity,last_listing_id)');
  v_def:=replace(v_def,
    '    set quantity=nexora.inventory.quantity+excluded.quantity,last_listing_id=excluded.last_listing_id,updated_at=now();' || chr(10) ||
    '  return jsonb_build_object',
    '    set quantity=nexora.inventory.quantity+excluded.quantity,last_listing_id=excluded.last_listing_id,updated_at=now();' || chr(10) ||
    '  perform set_config(''nexora.allow_inventory_refund'',v_previous_refund_setting,true);' || chr(10) ||
    '  return jsonb_build_object');
  if position('v_previous_refund_setting' in v_def)=0
    or position('perform set_config(''nexora.allow_inventory_refund'',''true'',true)' in v_def)=0
    or position('perform set_config(''nexora.allow_inventory_refund'',v_previous_refund_setting,true)' in v_def)=0 then
    raise exception 'MARKET_LISTING_CANCEL_REFUND_PATCH_FAILED';
  end if;
  execute v_def;
end;
$do$;

-- Keep the manufacturing completion path server-authoritative and include market escrow
-- when checking whether the finished output fits in the player's capacity.
do $do$
declare
  v_def text;
begin
  select pg_get_functiondef('nexora.complete_manufacturing_job(text,text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    'select coalesce(sum(quantity), 0) into v_total from nexora.inventory where user_id = p_uid;',
    'v_total := nexora.player_inventory_usage(p_uid);');
  v_def:=replace(v_def,
    $old$update nexora.manufacturing_jobs
  set status = 'completed', completed_at = now()
  where id = p_job_id;

  return jsonb_build_object('ok', true, 'output_item', v_job.output_item_id, 'output_qty', v_job.output_qty);$old$,
    $new$update nexora.manufacturing_jobs
  set status = 'completed', completed_at = now()
  where id = p_job_id;

  perform nexora.emit_notification_once(
    p_uid,'manufacturing-complete:'||p_job_id,
    'اكتمل التصنيع','Manufacturing completed',
    'اكتمل التصنيع وأُضيف الإنتاج إلى مخزونك.','Your production finished and the output was added to inventory.','economy'
  );

  return jsonb_build_object('ok', true, 'output_item', v_job.output_item_id, 'output_qty', v_job.output_qty);$new$);
  if position('nexora.player_inventory_usage(p_uid)' in v_def)=0
    or position('manufacturing-complete:' in v_def)=0 then
    raise exception 'MANUFACTURING_COMPLETION_PATCH_FAILED';
  end if;
  execute v_def;
end;
$do$;

-- Process finished jobs independently of an open browser tab or an online player.
create or replace function nexora.settle_finished_manufacturing_jobs()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_job record;
  v_completed integer:=0;
begin
  for v_job in
    select id,user_id
    from nexora.manufacturing_jobs
    where status='running' and ends_at<=now()
    order by ends_at,id
    for update skip locked
  loop
    begin
      perform nexora.complete_manufacturing_job(v_job.user_id,v_job.id);
      v_completed:=v_completed+1;
    exception when others then
      if sqlerrm='INVENTORY_CAPACITY_EXCEEDED' then
        perform nexora.emit_notification_once(
          v_job.user_id,'manufacturing-capacity:'||v_job.id,
          'الإنتاج جاهز لكن المخزون ممتلئ','Production ready — inventory full',
          'اكتمل وقت التصنيع، لكن سعة المخزون لا تكفي لاستلام الإنتاج. أفرغ مساحة وسيُضاف تلقائيًا.',
          'The production timer ended, but your inventory has no room. Free capacity and the output will be added automatically.','economy'
        );
      else
        raise warning 'Could not settle manufacturing job %: %',v_job.id,sqlerrm;
      end if;
    end;
  end loop;
  return v_completed;
end;
$function$;

revoke all on function nexora.settle_finished_manufacturing_jobs() from public,anon,authenticated;
grant execute on function nexora.settle_finished_manufacturing_jobs() to service_role;
revoke all on function nexora.notify_full_company_vaults() from public,anon,authenticated;
revoke all on function nexora.sync_all_factory_production() from public,anon,authenticated;
revoke all on function nexora.notify_full_factory_warehouses() from public,anon,authenticated;
grant execute on function nexora.notify_full_company_vaults() to service_role;
grant execute on function nexora.sync_all_factory_production() to service_role;
grant execute on function nexora.notify_full_factory_warehouses() to service_role;

-- Notify when a mission first becomes claimable. The event key includes the mission period,
-- so a daily/weekly/seasonal mission can notify again in its next period.
create or replace function nexora.notify_ready_missions(p_uid text)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile nexora.player_profiles%rowtype;
  v_progress jsonb;
  v_mission record;
  v_period text;
  v_value bigint;
  v_notified integer:=0;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid;
  if not found then return 0; end if;
  v_progress:=nexora.get_mission_progress(p_uid);

  for v_mission in
    select * from (values
      ('tut_first_trade','tutorial','trades',1::bigint,'دخول السوق','Enter the Market'),
      ('tut_first_production','tutorial','produced',1::bigint,'بداية الإنتاج','First Production'),
      ('tut_first_company','tutorial','companies',1::bigint,'تأسيس الشركة','Found Your Company'),
      ('daily_market_orders','daily','dailyTradesCount',5::bigint,'نشاط السوق','Market Activity'),
      ('daily_factory_shift','daily','dailyManufacturingCount',3::bigint,'وردية إنتاج','Production Shift'),
      ('daily_market_volume','daily','dailyMarketSpend',2500::bigint,'حركة رأس المال','Capital in Motion'),
      ('daily_company_cycle','daily','dailyCompanyCollectionsCount',2::bigint,'دورة تشغيل','Operating Cycle'),
      ('weekly_market_network','weekly','weeklyTradesCount',35::bigint,'شبكة التوريد','Supply Network'),
      ('weekly_industrial_output','weekly','weeklyManufacturingCount',25::bigint,'إنتاج متواصل','Sustained Output'),
      ('weekly_capital_flow','weekly','weeklyMarketSpend',30000::bigint,'تدفق استثماري','Investment Flow'),
      ('weekly_corporate_returns','weekly','weeklyCompanyCollectionsCount',12::bigint,'عوائد مؤسسية','Corporate Returns'),
      ('seasonal_market_leadership','seasonal','seasonalMarketBuys',250::bigint,'قيادة السوق','Market Leadership'),
      ('seasonal_industry_scale','seasonal','seasonalManufacturingCount',180::bigint,'توسع صناعي','Industrial Scale'),
      ('seasonal_capital_commitment','seasonal','seasonalMarketSpend',500000::bigint,'التزام رأسمالي','Capital Commitment'),
      ('seasonal_corporate_scale','seasonal','seasonalCompanyCollectionsCount',75::bigint,'إدارة المحافظ','Portfolio Management')
    ) as missions(mission_id,category,metric,target,title_ar,title_en)
  loop
    v_period:=case v_mission.category
      when 'daily' then to_char(now() at time zone 'UTC','YYYY-MM-DD')
      when 'weekly' then to_char(now() at time zone 'UTC','IYYY-"W"IW')
      when 'seasonal' then to_char(now() at time zone 'UTC','YYYY')||'-Q'||extract(quarter from now() at time zone 'UTC')::integer::text
      else 'lifetime'
    end;

    v_value:=case v_mission.metric
      when 'trades' then coalesce((v_profile.stats->>'tradesCount')::bigint,0)
      when 'produced' then coalesce((v_profile.stats->>'totalProduced')::bigint,0)
      when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::bigint,0)
      when 'org' then case when v_profile.org_id is null then 0 else 1 end
      else coalesce((v_progress->>v_mission.metric)::bigint,0)
    end;

    if v_value>=v_mission.target and not exists(
      select 1 from nexora.player_missions pm
      where pm.user_id=p_uid and pm.mission_id=v_mission.mission_id and pm.period_key=v_period
    ) then
      perform nexora.emit_notification_once(
        p_uid,'mission-ready:'||v_mission.mission_id||':'||v_period,
        'مكافأة مهمة جاهزة','Mission reward ready',
        'أكملت مهمة «'||v_mission.title_ar||'» ويمكنك استلام مكافأتها الآن.',
        'You completed "'||v_mission.title_en||'". Its reward is ready to claim.','mission'
      );
      v_notified:=v_notified+1;
    end if;
  end loop;
  return v_notified;
end;
$function$;

create or replace function nexora.notify_ready_missions_after_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text;
begin
  if new.status<>'completed' then return new; end if;
  v_uid:=case when new.type='company_collect' then new.to_uid else new.from_uid end;
  if v_uid is not null and v_uid<>'SYSTEM' and new.type in ('market_buy','manufacturing','company_collect') then
    perform nexora.notify_ready_missions(v_uid);
  end if;
  return new;
end;
$function$;

drop trigger if exists nova_notify_ready_missions_transaction on nexora.transactions;
create trigger nova_notify_ready_missions_transaction
after insert on nexora.transactions
for each row execute function nexora.notify_ready_missions_after_transaction();

create or replace function nexora.notify_ready_missions_after_profile_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.stats is distinct from old.stats or new.org_id is distinct from old.org_id then
    perform nexora.notify_ready_missions(new.user_id);
  end if;
  return new;
end;
$function$;

drop trigger if exists nova_notify_ready_missions_profile on nexora.player_profiles;
create trigger nova_notify_ready_missions_profile
after update of stats,org_id on nexora.player_profiles
for each row execute function nexora.notify_ready_missions_after_profile_update();

-- Capacity alerts fire only on the transition from below capacity to full.
create or replace function nexora.notify_company_vault_full()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_caps bigint[]:=array[3500,7000,14000,25000,40000];
  v_capacity bigint;
begin
  v_capacity:=v_caps[greatest(1,least(5,coalesce(new.vault_level,1)))];
  if coalesce(old.vault_balance,0)<v_capacity and coalesce(new.vault_balance,0)>=v_capacity then
    perform nexora.emit_notification_once(
      new.owner_uid,'company-vault-full:'||new.id||':'||new.vault_level||':'||coalesce(new.last_collected_at,new.created_at,now())::text,
      'خزنة الشركة ممتلئة','Company vault is full',
      'وصلت خزنة أرباح شركة «'||new.name||'» إلى سعتها القصوى. حصّل الإيرادات لتجنب ضياع الدخل القادم.',
      'The profit vault for "'||new.name||'" is full. Collect revenue so future income is not lost.','economy'
    );
  end if;
  return new;
end;
$function$;

drop trigger if exists nova_company_vault_full_notification on nexora.companies;
create trigger nova_company_vault_full_notification
after update of vault_balance on nexora.companies
for each row execute function nexora.notify_company_vault_full();

create or replace function nexora.notify_factory_warehouse_full()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_capacity bigint;
  v_event_key text;
begin
  v_capacity:=nexora.factory_warehouse_capacity(new.resource_id,new.warehouse_level);
  v_event_key:='factory-warehouse-full:'||new.id||':'||new.warehouse_level;
  if coalesce(new.warehouse_qty,0)<v_capacity then
    delete from nexora.notification_events
    where user_id=new.owner_uid and event_key=v_event_key;
  elsif coalesce(old.warehouse_qty,0)<v_capacity and coalesce(new.warehouse_qty,0)>=v_capacity then
    perform nexora.emit_notification_once(
      new.owner_uid,v_event_key,
      'مستودع المصنع ممتلئ','Factory warehouse is full',
      'امتلأ مستودع مصنع «'||new.name||'». اسحب الموارد إلى مخزونك أو وسّع المستودع لاستئناف الإنتاج.',
      'The warehouse for "'||new.name||'" is full. Withdraw resources or expand the warehouse to resume production.','economy'
    );
  end if;
  return new;
end;
$function$;

drop trigger if exists nova_factory_warehouse_full_notification on nexora.factories;
create trigger nova_factory_warehouse_full_notification
after update of warehouse_qty on nexora.factories
for each row execute function nexora.notify_factory_warehouse_full();


-- Only personal standard slots use the 15-minute completion/expiry cooldown.
-- Organization slots remain consumed for the rest of the UTC day; manual refreshes
-- still receive their own explicit cooldown in refresh_dynamic_contract().
create or replace function nexora.start_contract_slot_cooldown()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_id text;
begin
  if old.status is distinct from new.status
    and new.status in ('completed','abandoned','expired')
    and new.scope='personal'
    and new.slot_no between 1 and 5
  then
    v_owner_id:=new.user_id;
    if v_owner_id is not null then
      insert into nexora.contract_slot_cooldowns
        (scope,owner_id,slot_no,board_date,cooldown_until,updated_at)
      values
        ('personal',v_owner_id,new.slot_no,new.board_date,now()+interval '15 minutes',now())
      on conflict(scope,owner_id,slot_no,board_date)
      do update set cooldown_until=greatest(
        nexora.contract_slot_cooldowns.cooldown_until,excluded.cooldown_until
      ),updated_at=now();

      if pg_trigger_depth()=1 then
        update nexora.contract_offers
        set status='expired',updated_at=now()
        where scope='personal' and user_id=v_owner_id and slot_no=new.slot_no
          and board_date=new.board_date and id<>new.id and status='offered';
      end if;
    end if;
  end if;
  return new;
end;
$$;

create or replace function nexora.guard_contract_slot_cooldown_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_id text;
  v_until timestamptz;
begin
  v_owner_id:=case when new.scope='personal' then new.user_id else new.org_id end;
  if v_owner_id is null then return new; end if;

  select c.cooldown_until into v_until
  from nexora.contract_slot_cooldowns c
  where c.scope=new.scope and c.owner_id=v_owner_id
    and c.slot_no=new.slot_no and c.board_date=new.board_date
  order by c.cooldown_until desc limit 1
  for update;

  if v_until is not null and v_until>now() then return null; end if;

  if v_until is not null then
    delete from nexora.contract_slot_cooldowns c
    where c.scope=new.scope and c.owner_id=v_owner_id
      and c.slot_no=new.slot_no and c.board_date=new.board_date
      and c.cooldown_until<=now();
  end if;
  return new;
end;
$$;

-- Remove old event-slot cooldown cards (e.g. 1005/1006) and obsolete org
-- completion cooldowns. Preserve cooldowns belonging to a manually refreshed
-- offered organization contract.
delete from nexora.contract_slot_cooldowns c
where c.scope='personal' and c.slot_no not between 1 and 5;

delete from nexora.contract_slot_cooldowns c
where c.scope='organization'
  and not exists(
    select 1 from nexora.contract_offers o
    where o.scope='organization' and o.org_id=c.owner_id
      and o.slot_no=c.slot_no and o.board_date=c.board_date
      and o.status='abandoned' and o.accepted_at is null
  );

-- Keep cooldown payloads limited to the five real personal slots.
create or replace function nexora.get_contract_slot_cooldowns(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id text;
  v_can_refresh_org boolean:=false;
  v_personal_refresh_used integer:=0;
  v_org_refresh_used integer:=0;
begin
  select org_id into v_org_id from nexora.player_profiles where user_id=p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select exists(select 1 from nexora.organization_members
    where org_id=v_org_id and user_id=p_uid and role in ('leader','deputy'))
    into v_can_refresh_org;
  select coalesce(used_count,0) into v_personal_refresh_used
    from nexora.contract_slot_refresh_usage
    where scope='personal' and owner_id=p_uid and date_key=(now() at time zone 'UTC')::date;
  select coalesce(used_count,0) into v_org_refresh_used
    from nexora.contract_slot_refresh_usage
    where scope='organization' and owner_id=v_org_id and date_key=(now() at time zone 'UTC')::date;

  return jsonb_build_object(
    'server_now',now(),
    'can_refresh_org',v_can_refresh_org,
    'personal_refresh_used',v_personal_refresh_used,
    'personal_refresh_limit',3,
    'org_refresh_used',v_org_refresh_used,
    'org_refresh_limit',5,
    'personal',coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no',c.slot_no,'board_date',c.board_date,'cooldown_until',c.cooldown_until
      ) order by c.slot_no)
      from (
        select slot_no,max(board_date) as board_date,max(cooldown_until) as cooldown_until
        from nexora.contract_slot_cooldowns
        where scope='personal' and owner_id=p_uid and slot_no between 1 and 5
          and board_date=(now() at time zone 'UTC')::date and cooldown_until>now()
        group by slot_no
      ) c
    ),'[]'::jsonb),
    'organization',coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no',c.slot_no,'board_date',c.board_date,'cooldown_until',c.cooldown_until
      ) order by c.slot_no)
      from (
        select slot_no,max(board_date) as board_date,max(cooldown_until) as cooldown_until
        from nexora.contract_slot_cooldowns
        where scope='organization' and owner_id=v_org_id
          and board_date=(now() at time zone 'UTC')::date and cooldown_until>now()
        group by slot_no
      ) c
    ),'[]'::jsonb)
  );
end;
$$;

-- Patch the organization board so a completed/expired/abandoned slot is not
-- silently replenished during the same UTC day. An explicitly refreshed offer
-- can return after its own 15-minute cooldown.
do $do$
declare
  v_def text;
begin
  select pg_get_functiondef('nexora.get_dynamic_contract_board(text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    $old$if not exists(select 1 from nexora.contract_offers where scope='organization' and org_id=v_org.id
          and board_date=v_today and slot_no=v_slot and status in ('offered','accepted','processing','ready')) then$old$,
    $new$if not exists(select 1 from nexora.contract_offers where scope='organization' and org_id=v_org.id
          and board_date=v_today and slot_no=v_slot and status in ('offered','accepted','processing','ready'))
          and (
            not exists(select 1 from nexora.contract_offers where scope='organization' and org_id=v_org.id
              and board_date=v_today and slot_no=v_slot)
            or exists(select 1 from nexora.contract_slot_cooldowns c
              where c.scope='organization' and c.owner_id=v_org.id and c.slot_no=v_slot
                and c.board_date=v_today and c.cooldown_until<=now())
          ) then$new$);
  if position('c.cooldown_until<=now()' in v_def)=0 then
    raise exception 'ORG_CONTRACT_DAILY_SLOT_GUARD_PATCH_FAILED';
  end if;
  execute v_def;
end;
$do$;

-- Completion and expiry never replenish organization contracts. Personal contracts
-- retain their independent per-slot 15-minute cooldown.
do $do$
declare
  v_def text;
begin
  select pg_get_functiondef('nexora.claim_dynamic_contract(text,text)'::regprocedure) into v_def;
  v_def:=replace(v_def,'if v_contract.board_date=v_today and',
    'if v_contract.scope=''personal'' and v_contract.board_date=v_today and');
  if position('v_contract.scope=''personal'' and v_contract.board_date=v_today and' in v_def)=0 then
    raise exception 'CONTRACT_CLAIM_SCOPE_PATCH_FAILED';
  end if;
  execute v_def;

  select pg_get_functiondef('nexora.settle_dynamic_contracts(text)'::regprocedure) into v_def;
  v_def:=replace(v_def,'if v_row.board_date=v_today and not exists',
    'if v_row.scope=''personal'' and v_row.board_date=v_today and not exists');
  if position('v_row.scope=''personal'' and v_row.board_date=v_today and not exists' in v_def)=0 then
    raise exception 'CONTRACT_SETTLEMENT_SCOPE_PATCH_FAILED';
  end if;
  execute v_def;

  select pg_get_functiondef('nexora.abandon_dynamic_contract(text,text)'::regprocedure) into v_def;
  v_def:=replace(v_def,'if v_contract.board_date=v_today and',
    'if v_contract.scope=''personal'' and v_contract.board_date=v_today and');
  if position('v_contract.scope=''personal'' and v_contract.board_date=v_today and' in v_def)=0 then
    raise exception 'CONTRACT_ABANDON_SCOPE_PATCH_FAILED';
  end if;
  execute v_def;

  select pg_get_functiondef('nexora.deliver_dynamic_contract(text,text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    'if v_contract.board_date=(v_now at time zone ''UTC'')::date and',
    'if v_contract.scope=''personal'' and v_contract.board_date=(v_now at time zone ''UTC'')::date and');
  if position('v_contract.scope=''personal'' and v_contract.board_date=(v_now at time zone ''UTC'')::date and' in v_def)=0 then
    raise exception 'CONTRACT_DELIVER_SCOPE_PATCH_FAILED';
  end if;
  execute v_def;
end;
$do$;

-- Backfill notifications for contracts that were already ready when this migration
-- is deployed, and re-check them during bootstrap after settlement.
create or replace function nexora.notify_ready_contracts(p_uid text)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_contract record;
  v_count integer:=0;
begin
  for v_contract in
    select id from nexora.contract_offers
    where status='ready'
      and ((scope='personal' and user_id=p_uid)
        or (scope='organization' and claimed_by=p_uid))
    order by created_at,id
  loop
    perform nexora.emit_notification_once(
      p_uid,'contract-ready:'||v_contract.id,
      'العقد جاهز للاستلام','Contract ready to claim',
      'أصبحت مكافأة أحد عقودك جاهزة للاستلام.','A contract reward is ready to claim.','economy'
    );
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$function$;

-- Manual organization refreshes are still permitted for authorized officers;
-- record their cooldown explicitly because automatic completion cooldowns are personal-only.
do $do$
declare
  v_def text;
begin
  select pg_get_functiondef('nexora.refresh_dynamic_contract(text,text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    $old$update nexora.contract_offers
  set status='abandoned',completed_at=now(),updated_at=now()
  where id=p_contract_id;

  return jsonb_build_object($old$,
    $new$update nexora.contract_offers
  set status='abandoned',completed_at=now(),updated_at=now()
  where id=p_contract_id;

  if v_contract.scope='organization' then
    insert into nexora.contract_slot_cooldowns(scope,owner_id,slot_no,board_date,cooldown_until,updated_at)
    values('organization',v_contract.org_id,v_contract.slot_no,v_contract.board_date,v_until,now())
    on conflict(scope,owner_id,slot_no,board_date)
    do update set cooldown_until=greatest(nexora.contract_slot_cooldowns.cooldown_until,excluded.cooldown_until),
      updated_at=now();
  end if;

  return jsonb_build_object($new$);
  if position('values(''organization'',v_contract.org_id,v_contract.slot_no,v_contract.board_date,v_until,now())' in v_def)=0 then
    raise exception 'ORG_MANUAL_REFRESH_COOLDOWN_PATCH_FAILED';
  end if;
  execute v_def;
end;
$do$;

-- Ready-contract notifications are localized and deduplicated.
do $do$
declare
  v_def text;
begin
  select pg_get_functiondef('nexora.settle_dynamic_contracts(text)'::regprocedure) into v_def;
  v_def:=replace(v_def,
    $old$insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'ntf_'||gen_random_uuid()::text,pp.user_id,
      case when pp.language='ar' then 'العقد جاهز للاستلام' else 'Contract ready to claim' end,
      case when pp.language='ar' then 'انتهت معالجة عقدك وأصبحت المكافأة جاهزة.' else 'Your contract has finished processing and its reward is ready.' end,
      'economy',false
    from nexora.player_private pp where pp.user_id=p_uid and pp.notifications_enabled=true;$old$,
    $new$perform nexora.emit_notification_once(
      p_uid,'contract-ready:'||v_row.id,
      'العقد جاهز للاستلام','Contract ready to claim',
      'انتهت معالجة عقدك وأصبحت المكافأة جاهزة للاستلام.','Your contract has finished processing and its reward is ready to claim.','economy'
    );$new$);
  if position('contract-ready:' in v_def)=0 then
    raise exception 'CONTRACT_READY_NOTIFICATION_PATCH_FAILED';
  end if;
  execute v_def;
end;
$do$;

-- Company vaults accrue while the player is offline. Calculate the displayed capped
-- balance without mutating revenue timestamps, and notify once per collection cycle.
create or replace function nexora.notify_full_company_vaults()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_company record;
  v_caps bigint[]:=array[3500,7000,14000,25000,40000];
  v_capacity bigint;
  v_elapsed numeric;
  v_hourly bigint;
  v_balance bigint;
  v_count integer:=0;
begin
  for v_company in
    select id,owner_uid,name,vault_level,vault_balance,last_collected_at,created_at
    from nexora.companies
    where is_deleted=false
    order by id
  loop
    v_capacity:=v_caps[greatest(1,least(5,coalesce(v_company.vault_level,1)))];
    v_elapsed:=least(12,greatest(0,extract(epoch from (now()-coalesce(v_company.last_collected_at,v_company.created_at)))/3600));
    v_hourly:=greatest(0,nexora.company_net_hourly(v_company.id));
    v_balance:=least(v_capacity,coalesce(v_company.vault_balance,0)
      + floor(v_hourly*v_elapsed)::bigint);
    if v_balance>=v_capacity then
      perform nexora.emit_notification_once(
        v_company.owner_uid,
        'company-vault-full:'||v_company.id||':'||v_company.vault_level||':'||coalesce(v_company.last_collected_at,v_company.created_at,now())::text,
        'خزنة الشركة ممتلئة','Company vault is full',
        'وصلت خزنة أرباح شركة «'||v_company.name||'» إلى سعتها القصوى. حصّل الإيرادات لتجنب ضياع الدخل القادم.',
        'The profit vault for "'||v_company.name||'" is full. Collect revenue so future income is not lost.','economy'
      );
      v_count:=v_count+1;
    end if;
  end loop;
  return v_count;
end;
$function$;

-- Also detect warehouses that were already full before this migration.
create or replace function nexora.notify_full_factory_warehouses()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_factory record;
  v_count integer:=0;
begin
  for v_factory in
    select id,owner_uid,name,resource_id,warehouse_level,warehouse_qty
    from nexora.factories
    where warehouse_qty>=nexora.factory_warehouse_capacity(resource_id,warehouse_level)
    order by id
  loop
    perform nexora.emit_notification_once(
      v_factory.owner_uid,'factory-warehouse-full:'||v_factory.id||':'||v_factory.warehouse_level,
      'مستودع المصنع ممتلئ','Factory warehouse is full',
      'امتلأ مستودع مصنع «'||v_factory.name||'». اسحب الموارد إلى مخزونك أو وسّع المستودع لاستئناف الإنتاج.',
      'The warehouse for "'||v_factory.name||'" is full. Withdraw resources or expand the warehouse to resume production.','economy'
    );
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$function$;

-- Keep factory production synchronized on the server even when no player has
-- the factories screen open. The existing RPC locks each factory and wallet.
create or replace function nexora.sync_all_factory_production()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_factory record;
  v_count integer:=0;
begin
  for v_factory in select id,owner_uid from nexora.factories order by id
  loop
    begin
      perform nexora.sync_factory_production(v_factory.owner_uid,v_factory.id);
      v_count:=v_count+1;
    exception when others then
      raise warning 'Could not synchronize factory %: %',v_factory.id,sqlerrm;
    end;
  end loop;
  perform nexora.notify_full_factory_warehouses();
  return v_count;
end;
$function$;

-- Register the server-side manufacturing settlement worker (pg_cron is enabled
-- on production; keep migration replay portable when the extension is absent).
do $do$
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule(
      'nova-manufacturing-auto-completion',
      '15 seconds',
      'select nexora.settle_finished_manufacturing_jobs();'
    );
    perform cron.schedule(
      'nova-factory-auto-production',
      '* * * * *',
      'select nexora.sync_all_factory_production();'
    );
    perform cron.schedule(
      'nova-company-vault-full-alerts',
      '* * * * *',
      'select nexora.notify_full_company_vaults();'
    );
  end if;
end;
$do$;

revoke all on function nexora.notify_ready_missions(text) from public,anon,authenticated;
revoke all on function nexora.notify_ready_missions_after_transaction() from public,anon,authenticated;
revoke all on function nexora.notify_ready_missions_after_profile_update() from public,anon,authenticated;
revoke all on function nexora.notify_company_vault_full() from public,anon,authenticated;
revoke all on function nexora.notify_factory_warehouse_full() from public,anon,authenticated;
grant execute on function nexora.notify_ready_missions(text) to service_role;
revoke all on function nexora.notify_ready_contracts(text) from public,anon,authenticated;
grant execute on function nexora.notify_ready_contracts(text) to service_role;
grant execute on function nexora.settle_dynamic_contracts(text) to service_role;
revoke all on function nexora.enforce_player_inventory_capacity() from public,anon,authenticated;
revoke all on function nexora.start_contract_slot_cooldown() from public,anon,authenticated;
revoke all on function nexora.guard_contract_slot_cooldown_insert() from public,anon,authenticated;
revoke all on function nexora.notify_full_company_vaults() from public,anon,authenticated;
revoke all on function nexora.notify_full_factory_warehouses() from public,anon,authenticated;
revoke all on function nexora.sync_all_factory_production() from public,anon,authenticated;
grant execute on function nexora.notify_full_company_vaults() to service_role;
grant execute on function nexora.notify_full_factory_warehouses() to service_role;
grant execute on function nexora.sync_all_factory_production() to service_role;
