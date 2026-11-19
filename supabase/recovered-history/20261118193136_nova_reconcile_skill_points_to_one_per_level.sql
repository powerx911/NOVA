-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118193136
-- Remote migration name: nova_reconcile_skill_points_to_one_per_level
-- Source: supabase_migrations.schema_migrations.statements (read-only extraction)
-- Recovered 2026-11-19. SQL body preserved as stored; not inferred from current schema.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

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
