-- Per-slot server-authoritative cooldowns. A terminal contract status starts
-- an independent 15-minute cooldown for only that scope/owner/slot.
create table if not exists nexora.contract_slot_cooldowns (
  scope text not null check (scope in ('personal','organization')),
  owner_id text not null,
  slot_no integer not null check (slot_no > 0),
  board_date date not null,
  cooldown_until timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (scope, owner_id, slot_no, board_date)
);

-- The personal board has five independent offers. Organization capacity scales
-- by ten slots per level, capped at one hundred.
update nexora.contract_config
set config_value = jsonb_set(config_value, '{personal_slots}', '5'::jsonb, true),
    updated_at = now()
where config_key = 'progression';

do $do$
declare
  v_definition text;
  v_generator_definition text;
  v_old text := 'v_slots:=v_org_slots_base+floor(v_org.level/v_org_slots_divisor)::integer;';
begin
  select pg_get_functiondef('nexora.get_dynamic_contract_board(text)'::regprocedure)
    into v_definition;
  if position(v_old in v_definition) = 0 then
    raise exception 'CONTRACT_BOARD_SLOT_FORMULA_NOT_FOUND';
  end if;
  v_definition := replace(v_definition, v_old,
    'v_slots:=least(100,greatest(10,v_org.level*10));');
  v_definition := replace(v_definition,
    $old$'organization',coalesce(v_org_board,'[]'::jsonb),'active_personal',v_active,$old$,
    $new$'organization',coalesce(v_org_board,'[]'::jsonb),'organization_slots',coalesce(v_slots,0),'organization_max_slots',100,'active_personal',v_active,$new$);
  if position('organization_max_slots' in v_definition)=0 then
    raise exception 'CONTRACT_BOARD_ORG_SLOT_METADATA_PATCH_FAILED';
  end if;
  execute v_definition;

  select pg_get_functiondef('nexora.generate_dynamic_contract(text,text,text,integer,date,text,text,text)'::regprocedure)
    into v_generator_definition;
  v_generator_definition:=replace(v_generator_definition,
    'if v_item is null then raise exception ''CONTRACT_CATALOG_EMPTY''; end if;',
    'if v_item is null then return null; end if;');
  -- Reuse catalog items across different organization slots so level 10 can
  -- actually fill a 100-slot board even when the catalog has fewer than 100 items.
  v_generator_definition:=replace(v_generator_definition,
    'and o.item_id=item_id and o.tier=v_tier',
    'and o.item_id=item_id and o.tier=v_tier and o.slot_no=p_slot');
  v_generator_definition:=replace(v_generator_definition,
    'and o.item_id=c.item_id and o.tier=c.item_cfg->>''tier''',
    'and o.item_id=c.item_id and o.tier=c.item_cfg->>''tier'' and o.slot_no=p_slot');
  if position('and o.item_id=item_id and o.tier=v_tier and o.slot_no=p_slot' in v_generator_definition)=0
    or position('and o.item_id=c.item_id and o.tier=c.item_cfg->>''tier'' and o.slot_no=p_slot' in v_generator_definition)=0 then
    raise exception 'CONTRACT_BOARD_SLOT_REUSE_PATCH_FAILED';
  end if;
  if position('if v_item is null then return null; end if;' in v_generator_definition)=0 then
    raise exception 'CONTRACT_CATALOG_EMPTY_GUARD_PATCH_FAILED';
  end if;
  execute v_generator_definition;
end;
$do$;

alter table nexora.contract_slot_cooldowns enable row level security;
revoke all on table nexora.contract_slot_cooldowns from public,anon,authenticated;

create table if not exists nexora.contract_slot_refresh_usage (
  scope text not null check (scope in ('personal','organization')),
  owner_id text not null,
  date_key date not null,
  used_count integer not null default 0 check (used_count >= 0),
  updated_at timestamptz not null default now(),
  primary key(scope,owner_id,date_key)
);

create index if not exists contract_slot_cooldowns_until_idx
  on nexora.contract_slot_cooldowns (cooldown_until);

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
    and new.slot_no > 0
  then
    v_owner_id := case when new.scope = 'personal' then new.user_id else new.org_id end;
    if v_owner_id is not null then
      insert into nexora.contract_slot_cooldowns
        (scope, owner_id, slot_no, board_date, cooldown_until, updated_at)
      values
        (new.scope, v_owner_id, new.slot_no, new.board_date, now() + interval '15 minutes', now())
      on conflict (scope, owner_id, slot_no, board_date)
      do update set cooldown_until = greatest(
        nexora.contract_slot_cooldowns.cooldown_until,
        excluded.cooldown_until
      ), updated_at = now();
    end if;
    -- A personal offer is generated immediately after acceptance. When the
    -- accepted contract later ends, expire any still-offered replacement in
    -- the same slot so the full cooldown is visible and enforceable.
    if pg_trigger_depth()=1 then
      update nexora.contract_offers
      set status='expired',updated_at=now()
      where scope=new.scope and slot_no=new.slot_no and board_date=new.board_date
        and id<>new.id and status='offered'
        and ((new.scope='personal' and user_id=v_owner_id)
          or (new.scope='organization' and org_id=v_owner_id));
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists nova_contract_slot_cooldown on nexora.contract_offers;
create trigger nova_contract_slot_cooldown
after update of status on nexora.contract_offers
for each row execute function nexora.start_contract_slot_cooldown();

-- Suppress immediate replacement attempts made by existing lifecycle RPCs.
-- Expired cooldown rows are cleared lazily on the next board refresh, allowing
-- the normal generator to fill that exact slot without affecting other slots.
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
  v_owner_id := case when new.scope = 'personal' then new.user_id else new.org_id end;
  if v_owner_id is null then return new; end if;

  select c.cooldown_until into v_until
  from nexora.contract_slot_cooldowns c
  where c.scope = new.scope and c.owner_id = v_owner_id
    and c.slot_no = new.slot_no
  order by c.cooldown_until desc limit 1
  for update;

  if v_until is not null and v_until > now() then
    return null;
  end if;

  if v_until is not null then
    delete from nexora.contract_slot_cooldowns c
    where c.scope = new.scope and c.owner_id = v_owner_id
      and c.slot_no = new.slot_no and c.cooldown_until <= now();
  end if;
  return new;
end;
$$;

drop trigger if exists nova_contract_slot_cooldown_guard on nexora.contract_offers;
create trigger nova_contract_slot_cooldown_guard
before insert on nexora.contract_offers
for each row execute function nexora.guard_contract_slot_cooldown_insert();

create or replace function nexora.get_contract_slot_cooldowns(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id text;
  v_can_refresh_org boolean := false;
  v_personal_refresh_used integer := 0;
  v_org_refresh_used integer := 0;
begin
  select org_id into v_org_id
  from nexora.player_profiles where user_id = p_uid;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select exists(select 1 from nexora.organization_members where org_id=v_org_id and user_id=p_uid and role in ('leader','deputy')) into v_can_refresh_org;
  select coalesce(used_count,0) into v_personal_refresh_used from nexora.contract_slot_refresh_usage
    where scope='personal' and owner_id=p_uid and date_key=(now() at time zone 'UTC')::date;
  select coalesce(used_count,0) into v_org_refresh_used from nexora.contract_slot_refresh_usage
    where scope='organization' and owner_id=v_org_id and date_key=(now() at time zone 'UTC')::date;

  return jsonb_build_object(
    'server_now', now(),
    'can_refresh_org', v_can_refresh_org,
    'personal_refresh_used', v_personal_refresh_used,
    'personal_refresh_limit', 3,
    'org_refresh_used', v_org_refresh_used,
    'org_refresh_limit', 5,
    'personal', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no', c.slot_no, 'board_date', c.board_date,
        'cooldown_until', c.cooldown_until
      ) order by c.slot_no)
      from (
        select slot_no,max(board_date) as board_date,max(cooldown_until) as cooldown_until
        from nexora.contract_slot_cooldowns
        where scope='personal' and owner_id=p_uid and cooldown_until>now()
        group by slot_no
      ) c
    ), '[]'::jsonb),
    'organization', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_no', c.slot_no, 'board_date', c.board_date,
        'cooldown_until', c.cooldown_until
      ) order by c.slot_no)
      from (
        select slot_no,max(board_date) as board_date,max(cooldown_until) as cooldown_until
        from nexora.contract_slot_cooldowns
        where scope='organization' and owner_id=v_org_id and cooldown_until>now()
        group by slot_no
      ) c
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function nexora.start_contract_slot_cooldown() from public, anon, authenticated;
revoke all on function nexora.guard_contract_slot_cooldown_insert() from public, anon, authenticated;
revoke all on function nexora.get_contract_slot_cooldowns(text) from public, anon, authenticated;
grant execute on function nexora.get_contract_slot_cooldowns(text) to service_role;



-- Rotate the Supabase world_events table itself. The older Firebase scheduler
-- writes to a separate Firestore database and cannot drive NOVA's Supabase UI
-- or economy calculations.
create or replace function nexora.rotate_world_events(p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path = ''
as $rotate$
declare
  v_templates jsonb := jsonb_build_array(
    jsonb_build_object('id','evt_silicon_boom','title_ar','طفرة الطلب على الرقائق','title_en','Silicon & Microchip Demand Surge','description_ar','ارتفاع الطلب العالمي على أشباه الموصلات يرفع تقييم الرقائق (+18%) وعوائد شركات التقنية (+15%).','description_en','Global semiconductor demand boosts Microchip index (+18%) and Tech company yields (+15%).','effect_type','demand_surge','target_item_id','microchips','affected_sectors',jsonb_build_array('tech'),'price_multiplier',1.18,'revenue_multiplier',1.15,'tax_delta',0,'stack_group','sector_tech','duration_hours',24,'event_class','positive'),
    jsonb_build_object('id','evt_raw_shortage','title_ar','شح المعادن والخامات','title_en','Raw Material Supply Squeeze','description_ar','تباطؤ الإمدادات العالمية يرفع قيمة خام السيليكون (+22%) ويضغط على هوامش التصنيع (-6%).','description_en','Global extraction bottleneck elevates Silicon Ore value (+22%) while tightening factory margins (-6%).','effect_type','supply_shortage','target_item_id','silicon_ore','affected_sectors',jsonb_build_array('manufacturing'),'price_multiplier',1.22,'revenue_multiplier',0.94,'tax_delta',0.01,'stack_group','supply_raw','duration_hours',18,'event_class','positive'),
    jsonb_build_object('id','evt_industrial_surge','title_ar','ذروة الطلب الصناعي','title_en','Industrial Compute Expansion','description_ar','موجة توسع في مراكز البيانات ترفع قيمة الخادم الكمومي (+15%) وعائد قطاعي التصنيع والتقنية (+18%).','description_en','Data-center expansion lifts Quantum Server prices (+15%) and Tech/Manufacturing output (+18%).','effect_type','industrial_boom','target_item_id','quantum_server','affected_sectors',jsonb_build_array('manufacturing','tech'),'price_multiplier',1.15,'revenue_multiplier',1.18,'tax_delta',0,'stack_group','sector_industry','duration_hours',24,'event_class','positive'),
    jsonb_build_object('id','evt_service_crisis','title_ar','تباطؤ قطاع الخدمات','title_en','Service Sector Contraction','description_ar','انخفاض مؤقت في الإنفاق المؤسسي يخفض عوائد قطاعي الخدمات والتجارة (-15%) ويرفع الرسوم 1%.','description_en','Temporary corporate spending pullback trims Services & Trade yields (-15%) and nudges fees +1%.','effect_type','service_crisis','target_item_id','','affected_sectors',jsonb_build_array('services','trade'),'price_multiplier',0.92,'revenue_multiplier',0.85,'tax_delta',0.01,'stack_group','macro_demand','duration_hours',12,'event_class','negative'),
    jsonb_build_object('id','evt_tax_holiday','title_ar','حافز التجارة الحرة','title_en','Free Trade Tax Incentive','description_ar','خفض مؤقت لضريبة معاملات السوق بمقدار 1% مع دفعة تشجيعية لقطاع التجارة (+8%).','description_en','Temporary 1% market transaction tax cut with a +8% Trade sector liquidity boost.','effect_type','tax_cut','target_item_id','','affected_sectors',jsonb_build_array('trade'),'price_multiplier',1.0,'revenue_multiplier',1.08,'tax_delta',-0.01,'stack_group','fiscal_policy','duration_hours',24,'event_class','positive'),
    jsonb_build_object('id','evt_logistics_boom','title_ar','ازدهار النقل والإمداد','title_en','Global Logistics & Freight Boom','description_ar','تسارع حركة الشحن العالمية يرفع قيمة طائرات الشحن (+14%) وعوائد النقل والتجارة (+16%).','description_en','Surging freight corridors boost Logistics Drone valuations (+14%) and Logistics/Trade output (+16%).','effect_type','logistics_boom','target_item_id','logistics_drone','affected_sectors',jsonb_build_array('logistics','trade'),'price_multiplier',1.14,'revenue_multiplier',1.16,'tax_delta',0,'stack_group','sector_logistics','duration_hours',24,'event_class','positive'),
    jsonb_build_object('id','evt_global_recession','title_ar','ركود اقتصادي عالمي','title_en','Global Economic Recession','description_ar','انكماش حاد في الطلب العالمي يخفض مؤشر الرقائق إلى 60% ويقلص عوائد قطاعات الاقتصاد.','description_en','A sharp global demand contraction cuts the Microchip market index to 60% and reduces company yields across sectors.','effect_type','economic_recession','target_item_id','microchips','affected_sectors',jsonb_build_array('trade','manufacturing','services','tech','logistics'),'price_multiplier',0.6,'revenue_multiplier',0.72,'tax_delta',0.01,'stack_group','macro_demand','duration_hours',12,'event_class','negative'),
    jsonb_build_object('id','evt_raw_material_glut','title_ar','تخمة المعروض من الخامات','title_en','Raw Material Supply Glut','description_ar','وفرة مفاجئة في المعروض تضغط على أسعار خام السيليكون إلى 70% وتضعف عوائد التصنيع.','description_en','A sudden supply glut pushes Silicon Ore prices to 70% and softens manufacturing yields.','effect_type','supply_glut','target_item_id','silicon_ore','affected_sectors',jsonb_build_array('manufacturing'),'price_multiplier',0.7,'revenue_multiplier',0.88,'tax_delta',0,'stack_group','supply_raw','duration_hours',12,'event_class','negative'),
    jsonb_build_object('id','evt_logistics_disruption','title_ar','تعطل سلاسل الإمداد','title_en','Global Logistics Disruption','description_ar','تعطل الشحن يرفع تكاليف التشغيل ويخفض عوائد قطاعي النقل والتجارة إلى 75%.','description_en','Shipping disruption increases operating pressure and cuts Logistics and Trade yields to 75%.','effect_type','logistics_disruption','target_item_id','logistics_drone','affected_sectors',jsonb_build_array('logistics','trade'),'price_multiplier',0.82,'revenue_multiplier',0.75,'tax_delta',0.01,'stack_group','sector_logistics','duration_hours',10,'event_class','negative')
  );
  v_rotation_index bigint := floor(extract(epoch from p_now) / 21600)::bigint;
  v_negative_window boolean;
  v_negative_count integer;
  v_positive_count integer;
  v_offset integer;
  v_negative_tpl jsonb;
  v_positive_candidates jsonb := '[]'::jsonb;
  v_candidates jsonb := '[]'::jsonb;
  v_tpl jsonb;
  v_event record;
  v_kept_ids text[] := array[]::text[];
  v_kept_groups text[] := array[]::text[];
  v_expired_ids text[] := array[]::text[];
  v_slots_needed integer;
  v_negative_active boolean := false;
  v_activated integer := 0;
  v_deactivated integer := 0;
  v_id text;
  v_group text;
  v_is_negative boolean;
begin
  select coalesce(array_agg(id),array[]::text[]) into v_expired_ids
  from nexora.world_events where active=true and ends_at<=p_now;
  update nexora.world_events set active=false
  where active=true and ends_at<=p_now;
  v_deactivated := cardinality(v_expired_ids);

  for v_event in
    select id,effect_type,coalesce(stack_group,id) as stack_group
    from nexora.world_events
    where active=true and ends_at>p_now
    order by starts_at,id
  loop
    if cardinality(v_kept_ids)<3 and not (v_event.stack_group=any(v_kept_groups)) then
      v_kept_ids:=array_append(v_kept_ids,v_event.id);
      v_kept_groups:=array_append(v_kept_groups,v_event.stack_group);
      if v_event.effect_type in ('service_crisis','economic_recession','supply_glut','logistics_disruption') then
        v_negative_active:=true;
      end if;
    else
      update nexora.world_events set active=false where id=v_event.id and active=true;
      v_deactivated:=v_deactivated+1;
    end if;
  end loop;

  v_slots_needed:=greatest(0,3-cardinality(v_kept_ids));
  v_negative_window:=mod(v_rotation_index,5)=4;

  if v_slots_needed>0 then
    select count(*) into v_positive_count
    from jsonb_array_elements(v_templates) t(value)
    where value->>'event_class'='positive';
    select count(*) into v_negative_count
    from jsonb_array_elements(v_templates) t(value)
    where value->>'event_class'='negative';

    if v_negative_window and not v_negative_active and v_negative_count>0 then
      select value into v_negative_tpl
      from jsonb_array_elements(v_templates) with ordinality as t(value,ordinality)
      where value->>'event_class'='negative'
      order by ordinality
      offset mod((v_rotation_index/5),v_negative_count)::integer
      limit 1;
      if v_negative_tpl is not null then
        if (v_negative_tpl->>'id')=any(v_expired_ids) then
          v_candidates:=v_candidates || '[]'::jsonb;
        else
          v_candidates:=v_candidates || jsonb_build_array(v_negative_tpl);
        end if;
      end if;
    end if;

    v_offset:=mod(v_rotation_index,greatest(1,v_positive_count))::integer;
    select coalesce(jsonb_agg(value order by
      case when (value->>'id')=any(v_expired_ids) then 1 else 0 end,
      mod((ordinality-1-v_offset+v_positive_count),greatest(1,v_positive_count))
    ),'[]'::jsonb) into v_positive_candidates
    from jsonb_array_elements(v_templates) with ordinality as t(value,ordinality)
    where value->>'event_class'='positive';
    v_candidates:=v_candidates || v_positive_candidates;

    if v_negative_window and not v_negative_active and v_negative_tpl is not null
      and (v_negative_tpl->>'id')=any(v_expired_ids) then
      v_candidates:=v_candidates || jsonb_build_array(v_negative_tpl);
    end if;

    for v_tpl in select value from jsonb_array_elements(v_candidates) as c(value)
    loop
      exit when v_activated>=v_slots_needed;
      v_id:=v_tpl->>'id';
      v_group:=v_tpl->>'stack_group';
      v_is_negative:=v_tpl->>'event_class'='negative';
      if v_id=any(v_kept_ids) or v_group=any(v_kept_groups) then continue; end if;
      if v_is_negative and v_negative_active then continue; end if;

      insert into nexora.world_events(
        id,title_ar,title_en,description_ar,description_en,effect_type,target_item_id,
        affected_sectors,price_multiplier,revenue_multiplier,tax_delta,stack_group,
        starts_at,ends_at,active
      ) values (
        v_id,v_tpl->>'title_ar',v_tpl->>'title_en',v_tpl->>'description_ar',v_tpl->>'description_en',
        v_tpl->>'effect_type',coalesce(v_tpl->>'target_item_id',''),
        v_tpl->'affected_sectors',(v_tpl->>'price_multiplier')::numeric,
        (v_tpl->>'revenue_multiplier')::numeric,(v_tpl->>'tax_delta')::numeric,
        v_group,p_now,p_now+make_interval(hours=>(v_tpl->>'duration_hours')::integer),true
      )
      on conflict(id) do update set
        title_ar=excluded.title_ar,title_en=excluded.title_en,
        description_ar=excluded.description_ar,description_en=excluded.description_en,
        effect_type=excluded.effect_type,target_item_id=excluded.target_item_id,
        affected_sectors=excluded.affected_sectors,price_multiplier=excluded.price_multiplier,
        revenue_multiplier=excluded.revenue_multiplier,tax_delta=excluded.tax_delta,
        stack_group=excluded.stack_group,starts_at=excluded.starts_at,
        ends_at=excluded.ends_at,active=true;

      v_kept_ids:=array_append(v_kept_ids,v_id);
      v_kept_groups:=array_append(v_kept_groups,v_group);
      if v_is_negative then v_negative_active:=true; end if;
      v_activated:=v_activated+1;
    end loop;
  end if;

  return jsonb_build_object(
    'active_count',cardinality(v_kept_ids),
    'activated_count',v_activated,
    'deactivated_count',v_deactivated,
    'negative_window',v_negative_window
  );
end;
$rotate$;

revoke all on function nexora.rotate_world_events(timestamptz) from public,anon,authenticated;
grant execute on function nexora.rotate_world_events(timestamptz) to service_role;

do $schedule$
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule(
      'nova-supabase-world-events',
      '0 */6 * * *',
      'select nexora.rotate_world_events();'
    );
  else
    raise notice 'pg_cron is not installed; NOVA world event rotation was not scheduled';
  end if;
end;
$schedule$;
