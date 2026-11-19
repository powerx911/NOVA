-- RECOVERED UNTRACKED SQL EXECUTION — NOT A MIGRATION LEDGER ENTRY
-- PostgreSQL log timestamp: 2026-11-18 17:59:39 UTC
-- Source: postgres_logs client-backend statement event; POST /mcp metadata stripped.
-- Recovered 2026-11-19. SQL body preserved as logged.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create or replace function nexora.fetch_leaderboards()
returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object(
  'players',coalesce((select jsonb_agg(jsonb_build_object(
   'uid',user_id,'username',username,'avatarId',avatar_id,'title',title,'level',level,'xp',xp,
   'reputation',reputation,'influence',influence,'skillPoints',skill_points,'skills',skills,'stats',stats,'orgId',org_id
  ) order by influence desc) from (select * from nexora.player_profiles order by influence desc limit 20) p),'[]'::jsonb),
  'companies',coalesce((select jsonb_agg(jsonb_build_object(
   'id',id,'ownerUid',owner_uid,'ownerName',owner_name,'name',name,'sector',sector,'level',level,'capital',capital,
   'employeesCount',employees_count,'baseRevenuePerHour',base_revenue_per_hour,'expensePerHour',expense_per_hour,
   'totalRevenue',total_revenue,'vaultLevel',vault_level,'vaultBalance',vault_balance,
   'levelUpgradeStartedAt',level_upgrade_started_at,'levelUpgradeEndsAt',level_upgrade_ends_at,
   'levelUpgradeTargetLevel',level_upgrade_target_level,'levelUpgradeCost',level_upgrade_cost,
   'vaultUpgradeStartedAt',vault_upgrade_started_at,'vaultUpgradeEndsAt',vault_upgrade_ends_at,
   'vaultUpgradeTargetLevel',vault_upgrade_target_level,'auctionId',auction_id,'auctionEndsAt',auction_ends_at,
   'auctionStatus',auction_status,'lastCollectedAt',last_collected_at,'createdAt',created_at,'updatedAt',updated_at
  ) order by total_revenue desc) from (select * from nexora.companies order by total_revenue desc limit 20) c),'[]'::jsonb),
  'organizations',coalesce((select jsonb_agg(jsonb_build_object(
   'id',id,'name',name,'tag',tag,'description',description,'leaderUid',leader_uid,'leaderName',leader_name,
   'treasuryBalance',treasury_balance,'memberCount',member_count,'reputation',reputation,'level',level,
   'memberCapacity',member_capacity,'joinMode',join_mode,'research',research,'upgradeStartedAt',upgrade_started_at,
   'upgradeEndsAt',upgrade_ends_at,'upgradeTargetLevel',upgrade_target_level,'createdAt',created_at,'updatedAt',updated_at
  ) order by reputation desc) from (select * from nexora.organizations order by reputation desc limit 20) o),'[]'::jsonb)
 );
$$;
revoke all on function nexora.fetch_leaderboards() from public,anon,authenticated;
grant execute on function nexora.fetch_leaderboards() to service_role;
