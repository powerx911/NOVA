-- NOVA dynamic personal / organization contracts and ISO weekly organization goals.
-- Config is stored as data so balancing does not require another migration.

create table if not exists nexora.contract_config (
  config_key text primary key,
  config_value jsonb not null,
  updated_at timestamptz not null default now()
);

insert into nexora.contract_config(config_key, config_value) values
('catalog_prices', '{
  "silicon_ore":{"price":35,"tier":"common"},
  "copper_wire":{"price":28,"tier":"common"},
  "energy_cells":{"price":45,"tier":"common"},
  "crude_alloy":{"price":40,"tier":"common"},
  "carbon_fiber":{"price":55,"tier":"common"},
  "rare_minerals":{"price":70,"tier":"common"},
  "titanium_ore":{"price":85,"tier":"common"},
  "polymer_resin":{"price":95,"tier":"common"},
  "biotech_gel":{"price":120,"tier":"common"},
  "quantum_dust":{"price":160,"tier":"common"},
  "microchips":{"price":145,"tier":"uncommon"},
  "precision_frame":{"price":175,"tier":"uncommon"},
  "synth_polymer":{"price":190,"tier":"uncommon"},
  "quantum_server":{"price":560,"tier":"rare"},
  "logistics_drone":{"price":620,"tier":"rare"},
  "bio_module":{"price":680,"tier":"rare"}
}'::jsonb),
('tier_rules', '{
  "common":{"min_qty":4,"max_qty":8,"multiplier":1.12,"min_hours":3,"max_hours":4,"reputation":8,"org_reputation":5},
  "uncommon":{"min_qty":2,"max_qty":4,"multiplier":1.18,"min_hours":4,"max_hours":5,"reputation":14,"org_reputation":10},
  "rare":{"min_qty":1,"max_qty":2,"multiplier":1.25,"min_hours":5,"max_hours":6,"reputation":24,"org_reputation":20},
  "epic":{"min_qty":2,"max_qty":4,"multiplier":1.35,"min_hours":6,"max_hours":6,"reputation":40,"org_reputation":40}
}'::jsonb),
('personal_tier_weights', '{"common":90,"uncommon":9,"rare":1}'::jsonb),
('item_selection', '{"price_exponent":0.30}'::jsonb),
('org_tier_weights', '{"1-2":{"common":80,"uncommon":20,"rare":0,"epic":0},"3-5":{"common":50,"uncommon":35,"rare":15,"epic":0},"6-8":{"common":25,"uncommon":35,"rare":30,"epic":10},"9-10":{"common":10,"uncommon":30,"rare":35,"epic":25}}'::jsonb),
('progression', '{"uncommon_level":3,"rare_level":8,"personal_slots":6,"daily_claim_limit":5,"active_personal_limit":3,"org_join_hours":8,"fee_rate":0.04,"xp_rate":0.17,"xp_cap":400,"payout_cap":2500,"processing_divisor":12,"processing_min_minutes":10,"processing_max_minutes":120}'::jsonb),
('weekly_goal_bases', '{"produce_units":250,"trade_volume":5000,"contracts_completed":8,"treasury_donations":2500}'::jsonb),
('weekly_goal_rewards', '{"easy":50,"medium":100,"hard":200}'::jsonb)
on conflict (config_key) do nothing;

create table if not exists nexora.contract_offers (
  id text primary key,
  scope text not null check (scope in ('personal','organization')),
  user_id text,
  org_id text,
  slot_no integer not null,
  slot_generation integer not null default 1,
  board_date date not null,
  event_id text,
  item_id text not null,
  tier text not null check (tier in ('common','uncommon','rare','epic')),
  quantity integer not null check (quantity > 0),
  base_price bigint not null check (base_price > 0),
  payout bigint not null check (payout > 0 and payout <= 2500),
  reputation_reward integer not null check (reputation_reward >= 0),
  org_reputation_reward integer not null default 0 check (org_reputation_reward >= 0),
  processing_minutes integer not null check (processing_minutes between 10 and 120),
  event_premium numeric(6,4) not null default 0,
  status text not null default 'offered'
    check (status in ('offered','accepted','processing','ready','completed','expired','abandoned')),
  offered_at timestamptz not null default now(),
  offer_expires_at timestamptz not null,
  accepted_at timestamptz,
  deadline_at timestamptz,
  deadline_remaining_secs integer,
  processing_started_at timestamptz,
  ready_at timestamptz,
  delivered_at timestamptz,
  completed_at timestamptz,
  claimed_by text,
  fee_paid bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((scope='personal' and user_id is not null and org_id is null)
      or (scope='organization' and org_id is not null and user_id is null))
);

create unique index if not exists contract_offers_personal_slot_generation_uq
  on nexora.contract_offers(user_id, board_date, slot_no, slot_generation)
  where scope='personal';
create unique index if not exists contract_offers_org_slot_generation_uq
  on nexora.contract_offers(org_id, board_date, slot_no, slot_generation)
  where scope='organization';
create index if not exists contract_offers_personal_board_idx
  on nexora.contract_offers(user_id, board_date, status, slot_no);
create index if not exists contract_offers_org_board_idx
  on nexora.contract_offers(org_id, board_date, status, slot_no);
create index if not exists contract_offers_expiry_idx
  on nexora.contract_offers(status, deadline_at, offer_expires_at);
create unique index if not exists contract_one_active_org_per_member_uq
  on nexora.contract_offers(claimed_by)
  where scope='organization' and status in ('accepted','processing','ready') and claimed_by is not null;

create table if not exists nexora.contract_daily_limits (
  user_id text not null,
  date_key date not null,
  used_count integer not null default 0 check (used_count between 0 and 5),
  updated_at timestamptz not null default now(),
  primary key (user_id,date_key)
);

create table if not exists nexora.org_weekly_goals (
  id text primary key,
  org_id text not null references nexora.organizations(id) on delete cascade,
  week_start date not null,
  goal_type text not null check (goal_type in ('produce_units','trade_volume','contracts_completed','treasury_donations')),
  difficulty text not null check (difficulty in ('easy','medium','hard')),
  target_amount numeric(18,2) not null check (target_amount > 0),
  current_amount numeric(18,2) not null default 0 check (current_amount >= 0),
  reward_reputation bigint not null check (reward_reputation in (50,100,200)),
  status text not null default 'active' check (status in ('active','completed')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(org_id,week_start,goal_type)
);
create index if not exists org_weekly_goals_week_idx on nexora.org_weekly_goals(org_id,week_start,status);

create table if not exists nexora.org_goal_contributions (
  id text primary key,
  goal_id text not null references nexora.org_weekly_goals(id) on delete cascade,
  org_id text not null references nexora.organizations(id) on delete cascade,
  user_id text not null,
  amount numeric(18,2) not null default 0 check (amount >= 0),
  updated_at timestamptz not null default now(),
  unique(goal_id,user_id)
);
create index if not exists org_goal_contributions_ranking_idx
  on nexora.org_goal_contributions(goal_id,amount desc,updated_at);

alter table nexora.contract_config enable row level security;
alter table nexora.contract_offers enable row level security;
alter table nexora.contract_daily_limits enable row level security;
alter table nexora.org_weekly_goals enable row level security;
alter table nexora.org_goal_contributions enable row level security;
revoke all on nexora.contract_config,nexora.contract_offers,nexora.contract_daily_limits,
  nexora.org_weekly_goals,nexora.org_goal_contributions from public,anon,authenticated;
grant select,insert,update,delete on nexora.contract_config,nexora.contract_offers,
  nexora.contract_daily_limits,nexora.org_weekly_goals,nexora.org_goal_contributions to service_role;

create or replace function nexora.ensure_org_weekly_goals(p_org_id text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_org nexora.organizations%rowtype;
  v_week date := date_trunc('week',timezone('UTC',now()))::date;
  v_bases jsonb;
  v_rewards jsonb;
  v_types text[] := array['produce_units','trade_volume','contracts_completed','treasury_donations'];
  v_type text;
  v_difficulty text;
  v_target numeric;
  v_reward bigint;
  v_id text;
  v_count integer;
begin
  select * into v_org from nexora.organizations where id=p_org_id for update;
  if not found then raise exception 'ORG_NOT_FOUND'; end if;
  if exists(select 1 from nexora.org_weekly_goals where org_id=p_org_id and week_start=v_week) then return; end if;
  select config_value into v_bases from nexora.contract_config where config_key='weekly_goal_bases';
  select config_value into v_rewards from nexora.contract_config where config_key='weekly_goal_rewards';
  -- Three distinct goals are generated for each ISO week in UTC.
  for v_count in 1..3 loop
    v_type:=v_types[1+floor(random()*cardinality(v_types))::integer];
    v_types:=array_remove(v_types,v_type);
    v_difficulty:=case v_type when 'produce_units' then 'easy' when 'trade_volume' then 'medium'
      when 'contracts_completed' then 'hard' else 'medium' end;
    v_target:=round((coalesce((v_bases->>v_type)::numeric,100)
      * (1+0.15*greatest(1,v_org.level))
      * power(greatest(1,v_org.member_count)::numeric,0.7))::numeric,0);
    v_reward:=coalesce((v_rewards->>v_difficulty)::bigint,100);
    v_id:='og_'||gen_random_uuid()::text;
    insert into nexora.org_weekly_goals(id,org_id,week_start,goal_type,difficulty,target_amount,reward_reputation)
    values(v_id,p_org_id,v_week,v_type,v_difficulty,v_target,v_reward)
    on conflict(org_id,week_start,goal_type) do nothing;
  end loop;
end;
$$;

create or replace function nexora.record_org_goal_progress(p_uid text,p_type text,p_amount numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_org_id text;
  v_org nexora.organizations%rowtype;
  v_week date := date_trunc('week',timezone('UTC',now()))::date;
  v_goal nexora.org_weekly_goals%rowtype;
  v_new numeric;
  v_completed integer:=0;
begin
  if p_type not in ('produce_units','trade_volume','contracts_completed','treasury_donations')
     or p_amount is null or p_amount<=0 then
    return jsonb_build_object('ok',true,'recorded',false);
  end if;
  select org_id into v_org_id from nexora.player_profiles where user_id=p_uid;
  if v_org_id is null then return jsonb_build_object('ok',true,'recorded',false); end if;
  select * into v_org from nexora.organizations where id=v_org_id for update;
  if not found then return jsonb_build_object('ok',true,'recorded',false); end if;
  perform nexora.ensure_org_weekly_goals(v_org_id);
  for v_goal in
    select * from nexora.org_weekly_goals
    where org_id=v_org_id and week_start=v_week and goal_type=p_type and status='active'
    for update
  loop
    insert into nexora.org_goal_contributions(id,goal_id,org_id,user_id,amount)
    values('ogc_'||gen_random_uuid()::text,v_goal.id,v_org_id,p_uid,p_amount)
    on conflict(goal_id,user_id) do update
      set amount=nexora.org_goal_contributions.amount+excluded.amount,updated_at=now();
    v_new:=least(v_goal.target_amount,v_goal.current_amount+p_amount);
    update nexora.org_weekly_goals set current_amount=v_new,
      status=case when v_new>=target_amount then 'completed' else 'active' end,
      completed_at=case when v_new>=target_amount then now() else null end
    where id=v_goal.id and status='active';
    if v_new>=v_goal.target_amount then
      update nexora.organizations set reputation=reputation+v_goal.reward_reputation,updated_at=now()
      where id=v_org_id;
      v_completed:=v_completed+1;
    end if;
  end loop;
  return jsonb_build_object('ok',true,'completed',v_completed);
end;
$$;

create or replace function nexora.generate_dynamic_contract(
  p_scope text,p_uid text,p_org_id text,p_slot integer,p_board_date date,
  p_previous_item text default null,p_previous_tier text default null,p_event_id text default null
)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_org nexora.organizations%rowtype;
  v_catalog jsonb;
  v_rules jsonb;
  v_progression jsonb;
  v_weights jsonb;
  v_tier text;
  v_item text;
  v_base bigint;
  v_qty integer;
  v_multiplier numeric;
  v_min_hours integer;
  v_max_hours integer;
  v_rep integer;
  v_org_rep integer;
  v_premium numeric:=0;
  v_event_multiplier numeric:=1;
  v_event_end timestamptz;
  v_payout bigint;
  v_processing integer;
  v_id text:='ctr_'||gen_random_uuid()::text;
  v_generation integer;
  v_roll numeric:=random()*100;
  v_acc numeric:=0;
  v_key text;
  v_value jsonb;
  v_min_level integer;
  v_item_weight_exponent numeric:=0.30;
  v_level integer:=1;
  v_board_end timestamptz;
begin
  select config_value into v_catalog from nexora.contract_config where config_key='catalog_prices';
  select config_value into v_rules from nexora.contract_config where config_key='tier_rules';
  select config_value into v_progression from nexora.contract_config where config_key='progression';
  select coalesce((config_value->>'price_exponent')::numeric,0.30) into v_item_weight_exponent
    from nexora.contract_config where config_key='item_selection';
  if p_scope='personal' then
    select * into v_profile from nexora.player_profiles where user_id=p_uid;
    if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
    v_level:=v_profile.level;
    v_weights:= (select config_value from nexora.contract_config where config_key='personal_tier_weights');
    v_min_level:=1;
  else
    select * into v_org from nexora.organizations where id=p_org_id;
    if not found then raise exception 'ORG_NOT_FOUND'; end if;
    v_level:=v_org.level;
    v_weights:= (select config_value from nexora.contract_config where config_key='org_tier_weights')
      -> case when v_level<=2 then '1-2' when v_level<=5 then '3-5' when v_level<=8 then '6-8' else '9-10' end;
  end if;

  if p_event_id is not null then
    select target_item_id,price_multiplier,ends_at into v_item,v_event_multiplier,v_event_end
    from nexora.world_events where id=p_event_id and active=true
      and starts_at<=now() and ends_at>now() and target_item_id is not null and price_multiplier>1;
    if v_item is null then raise exception 'EVENT_NOT_ACTIVE'; end if;
    v_tier:=coalesce(v_catalog->v_item->>'tier','common');
    v_premium:=least(0.10,greatest(0,(v_event_multiplier-1)*0.5));
  else
    for v_key,v_value in select key,value from jsonb_each(v_weights) loop
      if v_key='uncommon' and p_scope='personal' and v_level<coalesce((v_progression->>'uncommon_level')::integer,3) then continue; end if;
      if v_key='rare' and p_scope='personal' and v_level<coalesce((v_progression->>'rare_level')::integer,8) then continue; end if;
      if v_key='epic' and p_scope='personal' then continue; end if;
      v_acc:=v_acc+coalesce((v_value#>>'{}')::numeric,0);
      if v_roll<=v_acc then v_tier:=v_key; exit; end if;
    end loop;
    v_tier:=coalesce(v_tier,'common');
    select item_id into v_item
    from jsonb_each(v_catalog) c(item_id,item_cfg)
    where ((v_tier='epic' and item_cfg->>'tier'='rare') or item_cfg->>'tier'=v_tier)
      and (p_previous_item is null or item_id<>p_previous_item or v_tier<>coalesce(p_previous_tier,''))
      and not exists (
        select 1 from nexora.contract_offers o
        where o.board_date=p_board_date and o.status in ('offered','accepted','processing','ready')
          and o.item_id=item_id and o.tier=v_tier
          and ((p_scope='personal' and o.scope='personal' and o.user_id=p_uid)
            or (p_scope='organization' and o.scope='organization' and o.org_id=p_org_id))
      )
    order by random()/power((item_cfg->>'price')::numeric,-v_item_weight_exponent) limit 1;
    if v_item is null then
      select item_id into v_item from jsonb_each(v_catalog) c(item_id,item_cfg)
      where ((v_tier='epic' and item_cfg->>'tier'='rare') or item_cfg->>'tier'=v_tier) and (p_previous_item is null or item_id<>p_previous_item)
      order by random()/power((item_cfg->>'price')::numeric,-v_item_weight_exponent) limit 1;
    end if;
  end if;
  if v_item is null then raise exception 'CONTRACT_CATALOG_EMPTY'; end if;
  v_base:=(v_catalog->v_item->>'price')::bigint;
  select value into v_value from jsonb_each(v_rules) where key=v_tier;
  v_qty:=coalesce((v_value->>'min_qty')::integer,1)
    +floor(random()*(coalesce((v_value->>'max_qty')::integer,1)-coalesce((v_value->>'min_qty')::integer,1)+1))::integer;
  if p_scope='organization' then v_qty:=ceil(v_qty*1.5)::integer; end if;
  v_multiplier:=(v_value->>'multiplier')::numeric;
  v_min_hours:=(v_value->>'min_hours')::integer;
  v_max_hours:=(v_value->>'max_hours')::integer;
  v_rep:=(v_value->>'reputation')::integer;
  v_org_rep:=(v_value->>'org_reputation')::integer;
  v_payout:=least(coalesce((v_progression->>'payout_cap')::bigint,2500),
    round(v_qty*v_base*v_multiplier*(0.95+random()*0.10)*(1+v_premium))::bigint);
  v_processing:=greatest(coalesce((v_progression->>'processing_min_minutes')::integer,10),
    least(coalesce((v_progression->>'processing_max_minutes')::integer,120),
      round(v_payout/coalesce((v_progression->>'processing_divisor')::numeric,12))::integer));
  v_board_end:=((p_board_date+1)::timestamp at time zone 'UTC');
  if p_event_id is not null then
    v_board_end:=least(v_board_end,coalesce(v_event_end,v_board_end));
  end if;
  select coalesce(max(slot_generation),0)+1 into v_generation
  from nexora.contract_offers
  where scope=p_scope and slot_no=p_slot and board_date=p_board_date
    and ((p_scope='personal' and user_id=p_uid) or (p_scope='organization' and org_id=p_org_id));
  insert into nexora.contract_offers(
    id,scope,user_id,org_id,slot_no,slot_generation,board_date,event_id,item_id,tier,quantity,
    base_price,payout,reputation_reward,org_reputation_reward,processing_minutes,event_premium,
    offer_expires_at
  ) values (
    v_id,p_scope,case when p_scope='personal' then p_uid end,
    case when p_scope='organization' then p_org_id end,p_slot,greatest(1,v_generation),
    p_board_date,p_event_id,v_item,v_tier,v_qty,v_base,v_payout,v_rep,
    case when p_scope='organization' then v_org_rep else 0 end,
    v_processing,v_premium,v_board_end
  );
  return v_id;
end;
$$;

create or replace function nexora.settle_dynamic_contracts(p_uid text)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_row nexora.contract_offers%rowtype;
  v_count integer:=0;
  v_today date:=(now() at time zone 'UTC')::date;
begin
  for v_row in
    select * from nexora.contract_offers
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
    if v_row.board_date=v_today and
      (v_row.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_row.event_id
        and e.active=true and e.starts_at<=now() and e.ends_at>now())) then
      perform nexora.generate_dynamic_contract(v_row.scope,v_row.user_id,v_row.org_id,
        v_row.slot_no,v_today,v_row.item_id,v_row.tier,v_row.event_id);
    end if;
    if coalesce(v_row.claimed_by,v_row.user_id) is not null then
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
$$;

create or replace function nexora.get_dynamic_contract_board(p_uid text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_org nexora.organizations%rowtype;
  v_today date:=(now() at time zone 'UTC')::date;
  v_end timestamptz:=((date_trunc('day',timezone('UTC',now()))+interval '1 day') at time zone 'UTC');
  v_personal jsonb;
  v_org_board jsonb:='[]'::jsonb;
  v_active integer;
  v_slots integer;
  v_slot integer;
  v_event record;
  v_event_slot integer;
  v_event_offer_count integer;
  v_event_index integer;
  v_claims integer;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if v_profile.org_id is not null then
    select * into v_org from nexora.organizations where id=v_profile.org_id for update;
  end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  for v_slot in 1..6 loop
    if not exists(select 1 from nexora.contract_offers where scope='personal' and user_id=p_uid
      and board_date=v_today and slot_no=v_slot and status in ('offered','accepted','processing','ready')) then
      perform nexora.generate_dynamic_contract('personal',p_uid,null,v_slot,v_today,null,null,null);
    end if;
  end loop;
  -- One or two event offers per active targeted event, outside the six standard slots.
  for v_event in
    select id from nexora.world_events where active=true and starts_at<=now() and ends_at>now()
      and target_item_id is not null and price_multiplier>1
      and exists(select 1 from nexora.contract_config c where c.config_key='catalog_prices'
        and c.config_value ? nexora.world_events.target_item_id)
    order by starts_at,id
  loop
    select coalesce(max(slot_no),0) into v_event_slot from nexora.contract_offers
      where scope='personal' and user_id=p_uid and board_date=v_today and event_id=v_event.id;
    if v_event_slot=0 then
      v_event_offer_count:=1+floor(random()*2)::integer;
      for v_event_index in 1..v_event_offer_count loop
        perform nexora.generate_dynamic_contract('personal',p_uid,null,
          1000+((select count(*) from nexora.world_events e2 where e2.id<=v_event.id)-1)*2+v_event_index,
          v_today,null,null,v_event.id);
      end loop;
    end if;
  end loop;
  select coalesce(jsonb_agg(to_jsonb(o) order by o.slot_no,o.slot_generation),'[]'::jsonb)
    into v_personal from nexora.contract_offers o
    where o.scope='personal' and o.user_id=p_uid and o.board_date=v_today
      and o.status in ('offered','accepted','processing','ready');
  select count(*) into v_active from nexora.contract_offers
    where scope='personal' and user_id=p_uid and status in ('accepted','processing','ready');
  select coalesce(used_count,0) into v_claims from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today;
  if v_profile.org_id is not null then
    select * into v_org from nexora.organizations where id=v_profile.org_id for update;
    if found then
      perform nexora.ensure_org_weekly_goals(v_org.id);
      v_slots:=2+floor(v_org.level/2)::integer;
      for v_slot in 1..v_slots loop
        if not exists(select 1 from nexora.contract_offers where scope='organization' and org_id=v_org.id
          and board_date=v_today and slot_no=v_slot and status in ('offered','accepted','processing','ready')) then
          perform nexora.generate_dynamic_contract('organization',null,v_org.id,v_slot,v_today,null,null,null);
        end if;
      end loop;
      select coalesce(jsonb_agg(to_jsonb(o) order by o.slot_no,o.slot_generation),'[]'::jsonb)
      into v_org_board from nexora.contract_offers o
      where o.scope='organization' and o.org_id=v_org.id and o.board_date=v_today
        and o.status in ('offered','accepted','processing','ready');
    end if;
  end if;
  return jsonb_build_object('personal',coalesce(v_personal,'[]'::jsonb),
    'organization',coalesce(v_org_board,'[]'::jsonb),'active_personal',v_active,
    'daily_used',coalesce(v_claims,0),'daily_limit',5,'offer_expires_at',v_end);
end;
$$;

create or replace function nexora.accept_dynamic_contract(p_uid text,p_contract_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_active integer;
  v_today date:=(now() at time zone 'UTC')::date;
  v_used integer;
  v_now timestamptz:=now();
  v_hours integer;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  if coalesce(v_contract.org_id,v_profile.org_id) is not null then
    select * into v_org from nexora.organizations
      where id=coalesce(v_contract.org_id,v_profile.org_id) for update;
  end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.status<>'offered' then raise exception 'CONTRACT_NOT_AVAILABLE'; end if;
  if v_contract.offer_expires_at<=v_now then
    update nexora.contract_offers set status='expired',updated_at=v_now where id=p_contract_id;
    if v_contract.board_date=(v_now at time zone 'UTC')::date and
      (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
        and e.active=true and e.starts_at<=v_now and e.ends_at>v_now)) then
      perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
        v_contract.slot_no,(v_now at time zone 'UTC')::date,v_contract.item_id,v_contract.tier,v_contract.event_id);
    end if;
    return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED');
  end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' then
    if v_profile.org_id is distinct from v_contract.org_id then raise exception 'UNAUTHORIZED'; end if;
    select extract(epoch from (v_now-joined_at))/3600 into v_hours
      from nexora.organization_members where org_id=v_contract.org_id and user_id=p_uid;
    if not found then raise exception 'UNAUTHORIZED'; end if;
    if v_hours<8 then raise exception 'ORG_MEMBERSHIP_TOO_NEW'; end if;
    if v_contract.claimed_by is not null then raise exception 'CONTRACT_ALREADY_CLAIMED'; end if;
    if exists(select 1 from nexora.contract_offers where scope='organization' and claimed_by=p_uid
      and status in ('accepted','processing','ready')) then raise exception 'ORG_ACTIVE_CONTRACT_LIMIT'; end if;
  else
    select count(*) into v_active from nexora.contract_offers
      where scope='personal' and user_id=p_uid and status in ('accepted','processing','ready');
    if v_active>=3 then raise exception 'ACTIVE_CONTRACT_LIMIT'; end if;
  end if;
  insert into nexora.contract_daily_limits(user_id,date_key,used_count) values(p_uid,v_today,0)
    on conflict(user_id,date_key) do nothing;
  select used_count into v_used from nexora.contract_daily_limits
    where user_id=p_uid and date_key=v_today for update;
  if v_used>=5 then raise exception 'DAILY_CONTRACT_LIMIT_REACHED'; end if;
  update nexora.contract_daily_limits set used_count=used_count+1,updated_at=v_now
    where user_id=p_uid and date_key=v_today;
  update nexora.contract_offers set status='accepted',accepted_at=v_now,
    deadline_at=v_now+make_interval(hours=>(
      (select (config_value->'tier_rules'->v_contract.tier->>'min_hours')::integer
       from nexora.contract_config where config_key='tier_rules')
      +floor(random()*(
        (select (config_value->'tier_rules'->v_contract.tier->>'max_hours')::integer
         from nexora.contract_config where config_key='tier_rules')
        -(select (config_value->'tier_rules'->v_contract.tier->>'min_hours')::integer
         from nexora.contract_config where config_key='tier_rules')+1))::integer),
    claimed_by=case when v_contract.scope='organization' then p_uid else null end,
    updated_at=v_now where id=p_contract_id;
  return jsonb_build_object('ok',true,'deadline_at',(
    select deadline_at from nexora.contract_offers where id=p_contract_id),'daily_used',v_used+1);
end;
$$;

create or replace function nexora.deliver_dynamic_contract(p_uid text,p_contract_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_inventory nexora.inventory%rowtype;
  v_fee bigint;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_now timestamptz:=now();
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  insert into nexora.inventory(user_id,item_id,quantity) values(p_uid,v_contract.item_id,0)
    on conflict(user_id,item_id) do nothing;
  select * into v_inventory from nexora.inventory where user_id=p_uid and item_id=v_contract.item_id for update;
  if coalesce(v_contract.org_id,v_profile.org_id) is not null then
    select * into v_org from nexora.organizations
      where id=coalesce(v_contract.org_id,v_profile.org_id) for update;
  end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' and v_contract.claimed_by<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.status<>'accepted' then raise exception 'CONTRACT_NOT_ACCEPTED'; end if;
  if v_contract.deadline_at<=v_now then
    update nexora.contract_offers set status='expired',updated_at=v_now where id=p_contract_id;
    if v_contract.board_date=(v_now at time zone 'UTC')::date and
      (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
        and e.active=true and e.starts_at<=v_now and e.ends_at>v_now)) then
      perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
        v_contract.slot_no,(v_now at time zone 'UTC')::date,v_contract.item_id,v_contract.tier,v_contract.event_id);
    end if;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'ntf_'||gen_random_uuid()::text,p_uid,'CONTRACT_EXPIRED','Contract deadline expired','economy',false
    where exists(select 1 from nexora.player_private pp where pp.user_id=p_uid and pp.notifications_enabled=true);
    return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED');
  end if;
  if v_inventory.quantity<v_contract.quantity then raise exception 'MISSING_INPUTS'; end if;
  v_fee:=round(v_contract.payout*0.04)::bigint;
  if v_wallet.balance<v_fee then raise exception 'INSUFFICIENT_FUNDS'; end if;
  update nexora.inventory set quantity=quantity-v_contract.quantity,updated_at=v_now
    where user_id=p_uid and item_id=v_contract.item_id;
  update nexora.wallets set balance=balance-v_fee,total_spent=total_spent+v_fee,last_tx_id=v_tx,updated_at=v_now
    where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,p_uid,'SYSTEM',v_fee,v_fee,0,'contract_fee',p_contract_id,'Contract processing fee','completed');
  update nexora.contract_offers set status='processing',deadline_remaining_secs=greatest(0,ceil(extract(epoch from (deadline_at-v_now)))::integer),
    deadline_at=null,processing_started_at=v_now,ready_at=v_now+make_interval(mins=>v_contract.processing_minutes),
    delivered_at=v_now,fee_paid=v_fee,updated_at=v_now where id=p_contract_id;
  return jsonb_build_object('ok',true,'ready_at',v_now+make_interval(mins=>v_contract.processing_minutes),
    'fee',v_fee,'remaining_secs',v_contract.deadline_remaining_secs);
end;
$$;

create or replace function nexora.abandon_dynamic_contract(p_uid text,p_contract_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_today date:=(now() at time zone 'UTC')::date;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  if coalesce(v_contract.org_id,v_profile.org_id) is not null then
    select * into v_org from nexora.organizations
      where id=coalesce(v_contract.org_id,v_profile.org_id) for update;
  end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' and v_contract.claimed_by<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.status<>'accepted' then raise exception 'CONTRACT_CANNOT_BE_ABANDONED'; end if;
  if v_contract.deadline_at<=now() then
    update nexora.contract_offers set status='expired',updated_at=now() where id=p_contract_id;
    if v_contract.board_date=v_today and
      (v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
        and e.active=true and e.starts_at<=now() and e.ends_at>now())) then
      perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
        v_contract.slot_no,v_today,v_contract.item_id,v_contract.tier,v_contract.event_id);
    end if;
    return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED');
  end if;
  update nexora.contract_offers set status='abandoned',completed_at=now(),updated_at=now() where id=p_contract_id;
  if v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
    and e.active=true and e.starts_at<=now() and e.ends_at>now()) then
    perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
      v_contract.slot_no,v_today,v_contract.item_id,v_contract.tier,v_contract.event_id);
  end if;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function nexora.claim_dynamic_contract(p_uid text,p_contract_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_contract nexora.contract_offers%rowtype;
  v_org nexora.organizations%rowtype;
  v_today date:=(now() at time zone 'UTC')::date;
  v_xp integer;
  v_level integer:=1;
  v_remaining bigint;
  v_step bigint;
  v_leadership numeric;
  v_tx text:='tx_'||gen_random_uuid()::text;
  v_new_xp bigint;
begin
  select * into v_profile from nexora.player_profiles where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_wallet from nexora.wallets where user_id=p_uid for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  select * into v_contract from nexora.contract_offers where id=p_contract_id;
  if not found then raise exception 'CONTRACT_NOT_FOUND'; end if;
  if coalesce(v_contract.org_id,v_profile.org_id) is not null then
    select * into v_org from nexora.organizations
      where id=coalesce(v_contract.org_id,v_profile.org_id) for update;
  end if;
  perform nexora.settle_dynamic_contracts(p_uid);
  select * into v_contract from nexora.contract_offers where id=p_contract_id for update;
  if v_contract.status='expired' then return jsonb_build_object('ok',false,'error','CONTRACT_EXPIRED'); end if;
  if v_contract.scope='personal' and v_contract.user_id<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.scope='organization' and v_contract.claimed_by<>p_uid then raise exception 'UNAUTHORIZED'; end if;
  if v_contract.status='processing' and v_contract.ready_at<=now() then
    update nexora.contract_offers set status='ready',updated_at=now() where id=p_contract_id;
    insert into nexora.notifications(id,user_id,title,body,type,is_read)
    select 'ntf_'||gen_random_uuid()::text,p_uid,'CONTRACT_READY','Your contract is ready to claim','economy',false
    where exists(select 1 from nexora.player_private pp where pp.user_id=p_uid and pp.notifications_enabled=true);
    v_contract.status:='ready';
  end if;
  if v_contract.status<>'ready' then
    if v_contract.status='processing' then raise exception 'CONTRACT_NOT_READY'; end if;
    raise exception 'CONTRACT_NOT_CLAIMABLE';
  end if;
  if v_contract.ready_at>now() then raise exception 'CONTRACT_NOT_READY'; end if;
  v_xp:=least(400,round(v_contract.payout*0.17)::integer);
  v_new_xp:=v_profile.xp+v_xp;
  v_remaining:=v_new_xp;
  while v_level<200 loop
    v_step:=200+(v_level-1)*120;
    exit when v_remaining<v_step;
    v_remaining:=v_remaining-v_step;
    v_level:=v_level+1;
  end loop;
  v_leadership:=1+coalesce((v_profile.skills->>'leadership')::numeric,0)*0.1;
  update nexora.wallets set balance=balance+v_contract.payout,total_earned=total_earned+v_contract.payout,
    last_tx_id=v_tx,updated_at=now() where user_id=p_uid;
  insert into nexora.transactions(id,from_uid,to_uid,amount,fee,net_amount,type,reference_id,description,status)
  values(v_tx,'SYSTEM',p_uid,v_contract.payout,0,v_contract.payout,'contract_reward',p_contract_id,
    'Dynamic contract reward: '||v_contract.item_id,'completed');
  update nexora.player_profiles set xp=v_new_xp,level=v_level,
    reputation=reputation+round(v_contract.reputation_reward*v_leadership)::bigint,
    updated_at=now() where user_id=p_uid;
  if v_contract.scope='organization' then
    update nexora.organizations set reputation=reputation+v_contract.org_reputation_reward,updated_at=now()
      where id=v_contract.org_id;
  end if;
  update nexora.contract_offers set status='completed',completed_at=now(),updated_at=now() where id=p_contract_id;
  perform nexora.record_org_goal_progress(p_uid,'contracts_completed',1);
  if v_contract.event_id is null or exists(select 1 from nexora.world_events e where e.id=v_contract.event_id
    and e.active=true and e.starts_at<=now() and e.ends_at>now()) then
    perform nexora.generate_dynamic_contract(v_contract.scope,v_contract.user_id,v_contract.org_id,
      v_contract.slot_no,v_today,v_contract.item_id,v_contract.tier,v_contract.event_id);
  end if;
  return jsonb_build_object('ok',true,'payout',v_contract.payout,'xp',v_xp,
    'reputation',round(v_contract.reputation_reward*v_leadership));
end;
$$;

create or replace function nexora.get_org_weekly_goals(p_uid text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_org_id text;
  v_goals jsonb;
begin
  select org_id into v_org_id from nexora.player_profiles where user_id=p_uid;
  if v_org_id is null then raise exception 'NOT_IN_ORG'; end if;
  if not exists(select 1 from nexora.organization_members where org_id=v_org_id and user_id=p_uid) then
    raise exception 'UNAUTHORIZED';
  end if;
  perform nexora.ensure_org_weekly_goals(v_org_id);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',g.id,'type',g.goal_type,'difficulty',g.difficulty,'target',g.target_amount,
    'current',g.current_amount,'rewardReputation',g.reward_reputation,'status',g.status,
    'weekStart',g.week_start,'completedAt',g.completed_at,
    'contributions',coalesce((
      select jsonb_agg(jsonb_build_object('uid',c.user_id,'username',m.username,'amount',c.amount)
        order by c.amount desc,m.username)
      from nexora.org_goal_contributions c
      left join nexora.organization_members m on m.org_id=c.org_id and m.user_id=c.user_id
      where c.goal_id=g.id
    ),'[]'::jsonb)
  ) order by g.goal_type),'[]'::jsonb) into v_goals
  from nexora.org_weekly_goals g
  where g.org_id=v_org_id and g.week_start=date_trunc('week',timezone('UTC',now()))::date;
  return jsonb_build_object('weekStart',date_trunc('week',timezone('UTC',now()))::date,'goals',v_goals);
end;
$$;

-- Goal progress hooks are transaction-local and run only after the original operation succeeds.
create or replace function nexora.record_org_goal_from_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_delta numeric;
begin
  v_delta:=coalesce((new.stats->>'totalProduced')::numeric,0)-coalesce((old.stats->>'totalProduced')::numeric,0);
  if v_delta>0 then perform nexora.record_org_goal_progress(new.user_id,'produce_units',v_delta); end if;
  return new;
end;
$$;
drop trigger if exists nova_org_goal_profile_production on nexora.player_profiles;
create trigger nova_org_goal_profile_production after update of stats on nexora.player_profiles
for each row when (coalesce((new.stats->>'totalProduced')::numeric,0)>coalesce((old.stats->>'totalProduced')::numeric,0))
execute function nexora.record_org_goal_from_profile();

create or replace function nexora.record_org_goal_from_factory()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_delta numeric;
begin
  v_delta:=new.warehouse_qty-old.warehouse_qty;
  if v_delta>0 then perform nexora.record_org_goal_progress(new.owner_uid,'produce_units',v_delta); end if;
  return new;
end;
$$;
drop trigger if exists nova_org_goal_factory_production on nexora.factories;
create trigger nova_org_goal_factory_production after update of warehouse_qty on nexora.factories
for each row when (new.warehouse_qty>old.warehouse_qty)
execute function nexora.record_org_goal_from_factory();

create or replace function nexora.record_org_goal_from_market_order()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform nexora.record_org_goal_progress(new.buyer_uid,'trade_volume',new.total_price);
  return new;
end;
$$;
drop trigger if exists nova_org_goal_market_volume on nexora.market_orders;
create trigger nova_org_goal_market_volume after insert on nexora.market_orders
for each row execute function nexora.record_org_goal_from_market_order();

create or replace function nexora.record_org_goal_from_org_transaction()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.type='deposit' then
    perform nexora.record_org_goal_progress(new.user_id,'treasury_donations',new.amount);
  end if;
  return new;
end;
$$;
drop trigger if exists nova_org_goal_treasury_donation on nexora.organization_transactions;
create trigger nova_org_goal_treasury_donation after insert on nexora.organization_transactions
for each row execute function nexora.record_org_goal_from_org_transaction();

-- The old fixed contract RPC and ledger remain intact for historical compatibility.
comment on function nexora.fulfill_trade_contract(text,text) is
  'DEPRECATED: retained for legacy clients/history. NOVA UI uses dynamic contract RPCs.';
comment on table nexora.contract_claims is
  'DEPRECATED: retained for legacy contract claims/history. Dynamic contracts use contract_offers.';

revoke all on function nexora.ensure_org_weekly_goals(text) from public,anon,authenticated;
revoke all on function nexora.record_org_goal_progress(text,text,numeric) from public,anon,authenticated;
revoke all on function nexora.generate_dynamic_contract(text,text,text,integer,date,text,text,text) from public,anon,authenticated;
revoke all on function nexora.settle_dynamic_contracts(text) from public,anon,authenticated;
revoke all on function nexora.get_dynamic_contract_board(text) from public,anon,authenticated;
revoke all on function nexora.accept_dynamic_contract(text,text) from public,anon,authenticated;
revoke all on function nexora.deliver_dynamic_contract(text,text) from public,anon,authenticated;
revoke all on function nexora.abandon_dynamic_contract(text,text) from public,anon,authenticated;
revoke all on function nexora.claim_dynamic_contract(text,text) from public,anon,authenticated;
revoke all on function nexora.get_org_weekly_goals(text) from public,anon,authenticated;
revoke all on function nexora.record_org_goal_from_profile() from public,anon,authenticated;
revoke all on function nexora.record_org_goal_from_factory() from public,anon,authenticated;
revoke all on function nexora.record_org_goal_from_market_order() from public,anon,authenticated;
revoke all on function nexora.record_org_goal_from_org_transaction() from public,anon,authenticated;

grant execute on function nexora.get_dynamic_contract_board(text) to service_role;
grant execute on function nexora.accept_dynamic_contract(text,text) to service_role;
grant execute on function nexora.deliver_dynamic_contract(text,text) to service_role;
grant execute on function nexora.abandon_dynamic_contract(text,text) to service_role;
grant execute on function nexora.claim_dynamic_contract(text,text) to service_role;
grant execute on function nexora.get_org_weekly_goals(text) to service_role;
grant execute on function nexora.record_org_goal_progress(text,text,numeric) to service_role;
