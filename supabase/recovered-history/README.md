# Recovered Supabase migration sources

**42 / 42 remote migration history entries have a recovered SQL body.**

Project: `hmrprnjhyzyefocdmnxf`  
Recovery date: 2026-11-19.

## Provenance
- 41 migration SQL bodies were extracted from Supabase `postgres_logs` statement records; each log timestamp maps to its remote migration version.
- The remaining source, `20261118193136_nova_reconcile_skill_points_to_one_per_level`, was recovered read-only from `supabase_migrations.schema_migrations.statements`.
- The SQL bodies are preserved; the Supabase API wrapper that inserts migration metadata is intentionally excluded.
- Two extra logged statement attempts had no corresponding version in the current remote ledger and were excluded.
- Every archive file is stored outside `supabase/migrations/`, so Supabase CLI will not treat it as pending migration work.

## Safety
**Do not execute this directory wholesale, move these files into `supabase/migrations/`, or run `supabase db push` based only on this recovery.**

This restores the historical SQL source bodies. It does not yet prove the current 31 local migration files match those bodies or establish a safe production deployment sequence. Content-level comparison and a separate reviewed reconciliation plan remain necessary.

## Recovered files
- `20261118151416_nova_player_core.sql`
- `20261118151655_harden_player_rpc_schema.sql`
- `20261118160528_nova_competitive_core.sql`
- `20261118161142_nova_shared_market.sql`
- `20261118161319_nova_market_fk_indexes.sql`
- `20261118162050_nova_competitive_duels.sql`
- `20261118170627_nexora_core_schema_v1.sql`
- `20261118170652_nexora_username_compatibility.sql`
- `20261118170811_remove_legacy_nova_functions.sql`
- `20261118170819_remove_legacy_nova_game_tables.sql`
- `20261118170850_nexora_firebase_identity_boundary.sql`
- `20261118171625_nexora_character_creation_rpc.sql`
- `20261118181814_nexora_server_operations.sql`
- `20261118181827_nexora_org_request_pending_unique.sql`
- `20261118190004_nova_character_welcome_branding.sql`
- `20261118192232_nova_remove_properties_and_skill_point_progression.sql`
- `20261118192618_nova_remove_property_mission_path.sql`
- `20261118192658_nova_remove_property_achievement_path.sql`
- `20261118193136_nova_reconcile_skill_points_to_one_per_level.sql`
- `20261118194258_nova_fix_company_upgrade_guard_and_indexes.sql`
- `20261118201649_nova_social_hub.sql`
- `20261118201750_nova_social_conversation_shape.sql`
- `20261118205113_nova_player_presence.sql`
- `20261118205409_nova_org_donation_ranking.sql`
- `20261118212342_nova_company_auction.sql`
- `20261118212718_nova_company_auction_immutable_history.sql`
- `20261118212846_nova_company_bid_found_guard.sql`
- `20261118222122_nova_skill_reset_and_factories.sql`
- `20261118222810_nova_factory_pause_sync_fix.sql`
- `20261118225248_nova_factory_economy_rebalance.sql`
- `20261118225603_nova_factory_warehouse_and_level_100.sql`
- `20261118225737_nova_factory_auction_support.sql`
- `20261118230011_nova_factory_warehouse_capacity_balance.sql`
- `20261118230131_nova_factory_auction_capacity_reservations.sql`
- `20261118230414_nova_factory_base_profit_curve.sql`
- `20261118230515_nova_add_advanced_factory_resources.sql`
- `20261118232146_nova_factory_profit_margin_v2.sql`
- `20261118233048_nova_remove_market_purchase_xp.sql`
- `20261118233344_remove_market_purchase_reputation_influence.sql`
- `20261118233403_correct_market_purchase_rewards.sql`
- `20261118233646_add_advanced_resource_manufacturing_recipes.sql`
- `20261118233707_balance_advanced_resource_recipe_costs.sql`
