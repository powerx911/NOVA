# Recovered Supabase SQL source archive

**42 / 42 tracked remote migration entries recovered, plus 13 untracked SQL statement events.**

Project: `hmrprnjhyzyefocdmnxf`  
Recovery date: 2026-11-19.

## Tracked migration sources

- 41 SQL bodies were recovered from Supabase `postgres_logs` statement events; their timestamps map to remote migration versions.
- The remaining source, `20261118193136_nova_reconcile_skill_points_to_one_per_level`, was recovered read-only from `supabase_migrations.schema_migrations.statements`.
- The migration metadata table contains 42 rows and no rollback arrays.
- Two additional tracked-style statement events had no matching version in the current remote ledger and were excluded from the 42 applied migration sources.

## Untracked direct SQL events

- 13 additional client-backend SQL statements were logged as direct `POST /mcp` executions, but do not appear as entries in `supabase_migrations.schema_migrations`.
- Their SQL bodies were recovered from PostgreSQL logs and stored under `untracked/`.
- Request metadata and user identifiers were deliberately stripped.
- Several statements define functions that are present in the production catalog but are absent from the 42 tracked migration bodies. Some are later replaced by tracked migrations; the replay workflow preserves their chronological order.

## Isolated replay

The historical replay workflow combines the 42 tracked migration sources and 13 untracked SQL events by their timestamp-prefixed filenames, then applies the three NOVA hardening migrations and runs pgTAP. It runs only on a disposable GitHub Actions Supabase stack.

## Safety

**Do not execute this directory wholesale outside the isolated replay workflow. Do not move these files into `supabase/migrations/` or run `supabase db push` based only on this recovery.**

The archive restores logged SQL bodies, but the current 31 local migration files still contain differences and candidates that need classification. The archive is forensic evidence for reconciliation, not a deployment plan.

## Tracked source files

55 total SQL files are archived: 42 tracked sources in this directory and 13 untracked events in `untracked/`. See the parent folder listing for the full tracked-source inventory.

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
