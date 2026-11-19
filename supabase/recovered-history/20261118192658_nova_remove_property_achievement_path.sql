-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118192658
-- Remote migration name: nova_remove_property_achievement_path
-- Source: Supabase postgres_logs at 2026-11-18 19:26:58 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

DELETE FROM nexora.player_missions WHERE mission_id = 'weekly_real_estate';
DELETE FROM nexora.player_achievements WHERE achievement_id = 'ach_landlord';

CREATE OR REPLACE FUNCTION nexora.unlock_eligible_achievements(p_uid text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_profile nexora.player_profiles%rowtype;
  v_unlocked text[] := '{}';
BEGIN
  SELECT * INTO v_profile FROM nexora.player_profiles WHERE user_id=p_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_FOUND'; END IF;

  INSERT INTO nexora.player_achievements(user_id,achievement_id)
  SELECT p_uid,a.id
  FROM (VALUES
    ('ach_merchant','trades',5),
    ('ach_industrial_pioneer','produced',5),
    ('ach_tycoon','companies',2),
    ('ach_level_5','level',5),
    ('ach_reputation_100','reputation',100)
  ) AS a(id,metric,threshold)
  WHERE CASE a.metric
    WHEN 'trades' THEN coalesce((v_profile.stats->>'tradesCount')::integer,0)
    WHEN 'produced' THEN coalesce((v_profile.stats->>'totalProduced')::integer,0)
    WHEN 'companies' THEN coalesce((v_profile.stats->>'companiesOwned')::integer,0)
    WHEN 'level' THEN v_profile.level
    ELSE v_profile.reputation
  END >= a.threshold
  ON CONFLICT(user_id,achievement_id) DO NOTHING;

  SELECT coalesce(array_agg(achievement_id),'{}'::text[])
  INTO v_unlocked
  FROM nexora.player_achievements
  WHERE user_id=p_uid;

  RETURN jsonb_build_object('unlocked_ids',v_unlocked);
END;
$function$;
;
