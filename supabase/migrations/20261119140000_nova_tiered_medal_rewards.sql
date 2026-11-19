-- Tiered NOVA medals. Each newly earned medal is persisted and its reward is
-- granted in the same transaction exactly once.
create or replace function nexora.unlock_eligible_achievements(p_uid text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile nexora.player_profiles%rowtype;
  v_wallet nexora.wallets%rowtype;
  v_new_ids text[] := '{}'::text[];
  v_all_ids text[] := '{}'::text[];
  v_achievement_id text;
  v_reward bigint;
  v_tx text;
begin
  select * into v_profile
  from nexora.player_profiles
  where user_id = p_uid
  for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  select * into v_wallet
  from nexora.wallets
  where user_id = p_uid
  for update;
  if not found then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  with eligible as (
    select a.id
    from (values
      ('ach_merchant', 'trades', 5),
      ('ach_industrial_pioneer', 'produced', 5),
      ('ach_tycoon', 'companies', 2),
      ('ach_landlord', 'properties', 2),
      ('ach_level_5', 'level', 5),
      ('ach_reputation_100', 'reputation', 100),
      ('medal_whale_bronze', 'spent', 10000),
      ('medal_whale_silver', 'spent', 35000),
      ('medal_whale_gold', 'spent', 100000),
      ('medal_whale_platinum', 'spent', 250000),
      ('medal_trader_bronze', 'trades', 25),
      ('medal_trader_silver', 'trades', 100),
      ('medal_trader_gold', 'trades', 500),
      ('medal_trader_platinum', 'trades', 2000),
      ('medal_industrialist_bronze', 'produced', 50),
      ('medal_industrialist_silver', 'produced', 250),
      ('medal_industrialist_gold', 'produced', 1000),
      ('medal_industrialist_platinum', 'produced', 5000)
    ) as a(id, metric, threshold)
    where case a.metric
      when 'trades' then coalesce((v_profile.stats->>'tradesCount')::integer, 0)
      when 'produced' then coalesce((v_profile.stats->>'totalProduced')::integer, 0)
      when 'companies' then coalesce((v_profile.stats->>'companiesOwned')::integer, 0)
      when 'properties' then coalesce((v_profile.stats->>'propertiesOwned')::integer, 0)
      when 'level' then v_profile.level
      when 'reputation' then v_profile.reputation
      when 'spent' then v_wallet.total_spent
      else 0
    end >= a.threshold
  ),
  inserted as (
    insert into nexora.player_achievements(user_id, achievement_id)
    select p_uid, eligible.id
    from eligible
    on conflict (user_id, achievement_id) do nothing
    returning achievement_id
  )
  select coalesce(array_agg(achievement_id), '{}'::text[])
  into v_new_ids
  from inserted;

  foreach v_achievement_id in array v_new_ids loop
    v_reward := case v_achievement_id
      when 'medal_whale_bronze' then 500
      when 'medal_whale_silver' then 1800
      when 'medal_whale_gold' then 6000
      when 'medal_whale_platinum' then 15000
      when 'medal_trader_bronze' then 250
      when 'medal_trader_silver' then 1000
      when 'medal_trader_gold' then 4000
      when 'medal_trader_platinum' then 12000
      when 'medal_industrialist_bronze' then 250
      when 'medal_industrialist_silver' then 1200
      when 'medal_industrialist_gold' then 5000
      when 'medal_industrialist_platinum' then 15000
      else 0
    end;

    if v_reward > 0 then
      v_tx := 'tx_' || gen_random_uuid()::text;
      update nexora.wallets
      set balance = balance + v_reward,
          total_earned = total_earned + v_reward,
          last_tx_id = v_tx,
          updated_at = now()
      where user_id = p_uid;

      insert into nexora.transactions(
        id, from_uid, to_uid, amount, fee, net_amount, type,
        reference_id, description, status
      ) values (
        v_tx, 'SYSTEM', p_uid, v_reward, 0, v_reward, 'mission_reward',
        v_achievement_id, 'NOVA medal reward: ' || v_achievement_id, 'completed'
      );
    end if;
  end loop;

  select coalesce(array_agg(achievement_id), '{}'::text[])
  into v_all_ids
  from nexora.player_achievements
  where user_id = p_uid;

  return jsonb_build_object(
    'unlocked_ids', v_all_ids,
    'newly_unlocked_ids', v_new_ids,
    'new_rewards', coalesce((
      select sum(case achievement_id
        when 'medal_whale_bronze' then 500
        when 'medal_whale_silver' then 1800
        when 'medal_whale_gold' then 6000
        when 'medal_whale_platinum' then 15000
        when 'medal_trader_bronze' then 250
        when 'medal_trader_silver' then 1000
        when 'medal_trader_gold' then 4000
        when 'medal_trader_platinum' then 12000
        when 'medal_industrialist_bronze' then 250
        when 'medal_industrialist_silver' then 1200
        when 'medal_industrialist_gold' then 5000
        when 'medal_industrialist_platinum' then 15000
        else 0
      end)
      from unnest(v_new_ids) as newly(achievement_id)
    ), 0)
  );
end;
$$;

revoke all on function nexora.unlock_eligible_achievements(text) from public, anon, authenticated;
grant execute on function nexora.unlock_eligible_achievements(text) to service_role;
