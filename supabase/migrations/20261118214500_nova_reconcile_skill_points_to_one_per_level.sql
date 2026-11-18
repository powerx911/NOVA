-- Reconcile balances earned under the old two-points-per-level rules.
-- Under NOVA's current rules, each profile has earned exactly level - 1 points,
-- and each skill level consumes one point.
UPDATE nexora.player_profiles AS profile
SET skill_points = GREATEST(
  profile.level - 1 - COALESCE((
    SELECT SUM(value::integer)
    FROM jsonb_each_text(COALESCE(profile.skills, '{}'::jsonb))
  ), 0),
  0
),
updated_at = now();
