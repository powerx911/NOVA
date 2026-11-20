# Recovered Supabase SQL source archive

**Original recovery snapshot:** 42 / 42 remote migration sources recovered, plus 13 untracked SQL statement events (2026-11-19).  
**Current production ledger:** 78 applied migration records (read-only inventory, 2026-11-20).

Project: `hmrprnjhyzyefocdmnxf`

## Current source reconciliation

- The current production ledger contains 78 rows in `supabase_migrations.schema_migrations`.
- The source manifest at `supabase/ci/production_migration_manifest.json` maps all 78 records to source paths and Git blob hashes.
- 21 records currently use recovered-history files as their canonical available source.
- 21 records have additional historical variants with different Git blob hashes. These variants are forensic evidence; do not overwrite one with another without a reviewed SQL diff.
- The applied production hotfix `20261120132839_nova_production_company_parity_hotfix_20261120` was recovered directly from its `statements` array and restored to `supabase/migrations/20261120132839_nova_production_company_parity_hotfix_20261120.sql`.
- The current `main` branch contains 75 tracked migration files. The three hardening migrations were applied to production on 2026-11-20 and are included in the 77-row ledger.
- Eighteen local migration files are not mapped by name to the current ledger. This is a name-mapping gap, not proof that they are pending or unapplied.

## Original recovered migration sources

- 42 tracked migration sources were recovered during the 2026-11-19 recovery.
- 41 SQL bodies were recovered from Supabase `postgres_logs` statement events; the remaining source was recovered read-only from `supabase_migrations.schema_migrations.statements`.
- The 13 untracked SQL statement events were logged as direct `POST /mcp` executions and do not appear as rows in `supabase_migrations.schema_migrations`.
- Their SQL bodies were recovered from PostgreSQL logs and stored under `untracked/`.
- Request metadata and user identifiers were deliberately stripped.
- Some recovered SQL bodies are later replaced by tracked migrations; replay order is maintained by timestamp-prefixed filenames.

## Isolated replay

The historical replay workflow replays the recovered SQL archive on a disposable GitHub Actions Supabase stack, then applies a curated set of canonical migrations and runs pgTAP. Both database workflows validate the production migration source manifest before replay.

The workflow's curated migration list is not a substitute for a complete fresh-project replay. The repository keeps two data-free baselines: `supabase/ci/nexora_schema_snapshot.sql` for historical migration replay and gameplay tests, and `supabase/ci/nexora_production_schema_snapshot.sql` exported read-only from production on 2026-11-20. The production snapshot contains 46 tables, 149 functions (136 SECURITY DEFINER), 38 triggers, 100 indexes and 169 constraints. CI verifies it separately after running the historical migration chain.

## Safety

**Do not execute this directory wholesale outside the isolated replay workflow. Do not move recovered files into `supabase/migrations/` or run `supabase db push` based only on this recovery.**

The archive restores logged SQL bodies, but some tracked/recovered variants differ. The manifest preserves source paths and Git blob hashes so reconciliation can be done explicitly. Never infer deployment status from a filename alone.

## Archive inventory

55 total SQL files are archived: 42 tracked sources in this directory and 13 untracked events in `untracked/`. See the parent folder listing for the full inventory.

## Untracked source files

- `untracked/20261118172839_untracked_nexora_economy_rpcs.sql`
- `untracked/20261118173226_untracked_nexora_market_rpcs.sql`
- `untracked/20261118173428_untracked_nexora_manufacturing_rpc.sql`
- `untracked/20261118173620_untracked_nexora_contract_rpc.sql`
- `untracked/20261118173755_untracked_nexora_player_settings_notifications.sql`
- `untracked/20261118174139_untracked_nexora_companies_properties.sql`
- `untracked/20261118174450_untracked_nexora_company_vault_rpcs.sql`
- `untracked/20261118174935_untracked_nexora_mission_achievement_rpcs.sql`
- `untracked/20261118175142_untracked_nexora_organization_rpcs.sql`
- `untracked/20261118175749_untracked_nexora_org_join_request.sql`
- `untracked/20261118175939_untracked_nexora_leaderboards.sql`
- `untracked/20261118180144_untracked_nexora_org_membership_sync.sql`
- `untracked/20261118233352_untracked_nexora_market_purchase_update.sql`
