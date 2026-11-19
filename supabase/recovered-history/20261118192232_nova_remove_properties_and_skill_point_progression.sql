-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118192232
-- Remote migration name: nova_remove_properties_and_skill_point_progression
-- Source: Supabase postgres_logs at 2026-11-18 19:22:32 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

-- NOVA: remove real-estate gameplay and normalize skill-point progression.
-- Existing profiles received 3 starter points; remove that one-time grant.
UPDATE nexora.player_profiles
SET skill_points = GREATEST(skill_points - 3, 0),
    stats = COALESCE(stats, '{}'::jsonb) - 'propertiesOwned',
    updated_at = now();

UPDATE nexora.notifications
SET body = CASE
  WHEN body ILIKE '%skill points%' THEN '$2,500 credited to your wallet. Your journey begins now.'
  WHEN body LIKE '%نقاط مهارة%' THEN 'تم إيداع $2,500 في محفظتك. ابدأ رحلتك الآن.'
  ELSE body
END
WHERE body ILIKE '%skill points%' OR body LIKE '%نقاط مهارة%';

CREATE OR REPLACE FUNCTION nexora.enforce_skill_point_progression()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.skill_points := 0;
  ELSIF NEW.level > OLD.level THEN
    NEW.skill_points := GREATEST(OLD.skill_points, 0) + (NEW.level - OLD.level);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_skill_point_progression ON nexora.player_profiles;
CREATE TRIGGER enforce_skill_point_progression
BEFORE INSERT OR UPDATE ON nexora.player_profiles
FOR EACH ROW
EXECUTE FUNCTION nexora.enforce_skill_point_progression();

CREATE OR REPLACE FUNCTION nexora.create_player_character(
  p_uid text,
  p_email text,
  p_username text,
  p_avatar_id text,
  p_language text DEFAULT 'ar'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_username text := btrim(p_username);
  v_lower text;
  v_title text;
  v_notification_id text := 'ntf_' || gen_random_uuid()::text;
BEGIN
  IF p_uid IS NULL OR length(p_uid) < 1 OR length(p_uid) > 128 THEN
    RAISE EXCEPTION 'INVALID_USER';
  END IF;
  IF v_username !~ '^[a-zA-Z0-9_]{3,24}$' THEN
    RAISE EXCEPTION 'INVALID_USERNAME';
  END IF;
  IF p_language NOT IN ('ar','en') THEN
    RAISE EXCEPTION 'INVALID_LANGUAGE';
  END IF;

  v_lower := lower(v_username);
  v_title := CASE WHEN p_language = 'ar' THEN 'مؤسس طموح' ELSE 'Executive Founder' END;

  IF EXISTS (SELECT 1 FROM nexora.player_profiles WHERE user_id = p_uid) THEN
    RAISE EXCEPTION 'PROFILE_EXISTS';
  END IF;

  INSERT INTO nexora.usernames(username_lower,uid,username)
  VALUES (v_lower,p_uid,v_username);

  INSERT INTO nexora.player_profiles(
    user_id,username,username_lower,avatar_id,title,level,xp,reputation,influence,
    skill_points,skills,stats,org_id
  ) VALUES (
    p_uid,v_username,v_lower,p_avatar_id,v_title,1,0,10,5,0,
    '{"trade":0,"management":0,"industry":0,"negotiation":0,"finance":0,"leadership":0}'::jsonb,
    '{"missionsCompleted":0,"tradesCount":0,"companiesOwned":0,"totalProduced":0}'::jsonb,
    null
  );

  INSERT INTO nexora.player_private(user_id,email,language,notifications_enabled)
  VALUES (p_uid,coalesce(p_email,''),p_language,true);

  INSERT INTO nexora.wallets(user_id,balance,total_earned,total_spent,last_tx_id)
  VALUES (p_uid,2500,2500,0,'init_' || p_uid);

  INSERT INTO nexora.notifications(id,user_id,title,body,type,is_read)
  VALUES (
    v_notification_id,
    p_uid,
    CASE WHEN p_language='ar' THEN 'مرحباً بك في NOVA' ELSE 'Welcome to NOVA' END,
    CASE WHEN p_language='ar' THEN 'تم إيداع $2,500 في محفظتك. ابدأ رحلتك الآن.' ELSE '$2,500 credited to your wallet. Your journey begins now.' END,
    'system',
    false
  );

  RETURN jsonb_build_object('ok',true,'user_id',p_uid,'username',v_username,'starting_credits',2500);
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'USERNAME_TAKEN';
END;
$function$;

-- The properties table was confirmed empty before removal.
DROP FUNCTION IF EXISTS nexora.buy_property(text,text,text);
DROP FUNCTION IF EXISTS nexora.toggle_property_lease(text,text,boolean);
DROP FUNCTION IF EXISTS nexora.upgrade_property(text,text);
DROP FUNCTION IF EXISTS nexora.collect_property_rent(text,text);
DROP TABLE IF EXISTS nexora.properties;
;
