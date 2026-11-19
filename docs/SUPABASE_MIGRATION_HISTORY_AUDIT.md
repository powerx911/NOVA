# Supabase migration history audit (read-only)

**Audit date:** 2026-11-19  
**Project ref:** `hmrprnjhyzyefocdmnxf`  
**Scope:** migration source/history reconciliation only. No production writes were performed.

## Verified facts

- The remote Supabase migration ledger currently contains 42 records.
- The repository default branch `main` contains 31 SQL files under `supabase/migrations/`.
- The current economy-hardening PR adds three new migration files; these are not yet part of the production migration ledger.
- `docs/SUPABASE_SCHEMA_V1.md` documents the 2026-11-18 NEXORA baseline. It says the baseline created 22 domain tables and records these three baseline-era history names: `nexora_core_schema_v1`, `nexora_username_compatibility`, and `nexora_firebase_identity_boundary`.
- That document is descriptive documentation, not executable SQL. It does not contain the original baseline DDL.
- Historical branches contain source files for the earlier NOVA player/competitive migrations, including `20261118151416_nova_player_core.sql`, `20261118151500_harden_player_rpc_schema.sql`, `20261118170000_nova_competitive_core.sql`, `20261118172000_nova_shared_market.sql`, `20261118173000_nova_market_fk_indexes.sql`, and `20261118174000_nova_competitive_duels.sql`.
- The original SQL source for `nexora_core_schema_v1` was not found in the current NOVA repository, its inspected historical branches, or the legacy `luffyk124-del/nexora-game` repository tree.
- The remote history includes additional records whose exact source/version mapping still needs a complete reconciliation. Do not treat the 31-file count or the schema documentation as proof that every historical migration is recovered.

## CI snapshot is not historical source

`supabase/ci/nexora_schema_snapshot.sql` is a data-free snapshot of the current production schema metadata, generated for disposable CI restoration. It represents the current end state, after later migrations. It is **not** the original `nexora_core_schema_v1` migration and must never be copied into the production migration history or applied to production as a replacement baseline.

## Safe next steps

1. Recover the exact original baseline SQL from the original author/workstation, a retained SQL editor export, release artifact, or backup.
2. Recover and map the exact source/version for every remote history record, comparing migration contents and the current schema rather than relying on names alone.
3. Verify that the recovered local migration versions exactly match the remote ledger and that already-applied migrations are byte-for-byte/semantically accounted for.
4. Continue using the disposable GitHub Actions PostgreSQL environment for validation.
5. Only after full reconciliation, prepare a separate reviewed deployment plan. Do not run `supabase db push`, `migration repair`, or any production DDL as part of this audit.

## Explicit safety boundary

- No production migration was applied, repaired, deleted, or renamed.
- No player data was queried or modified.
- No Supabase branch was created.
- No changes were made to the separate agent branch `fix/nova-urgent-economy-quality`.
