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
- The original SQL source for `nexora_core_schema_v1` was absent from the inspected Git trees, but was subsequently recovered from the production PostgreSQL statement log; see the recovery update below.
- The remote history includes additional records whose exact source/version mapping still needs a complete reconciliation. Do not treat the 31-file count or the schema documentation as proof that every historical migration is recovered.

## Additional source-history evidence

The source-replacement commit `1686aa3995561560cd52eee798401507ba2c8c9e` (“Replace NOVA with NEXORA source”) added six player/competitive migration files to the NOVA repository. Its change set did not include the `nexora_core_schema_v1` baseline SQL. This supports the possibility that the baseline was applied separately through the SQL editor or another external workflow, but does not establish exactly how it was applied.

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


## Exact ledger inventory (2026-11-19 read-only capture)

The following is the exact 42-row remote ledger returned by the Supabase migration-list operation. The source-finding column records the initial Git-only search and is superseded by the recovery update below. “Candidate” means a similarly named local file exists; it is **not** proof that the SQL contents equal the applied remote migration.

| Remote version | Remote name | Repository source finding |
|---|---|---|
| 20261118151416 | `20261118160000_nova_player_core` | Historical branch source: `20261118151416_nova_player_core.sql`; version/name mismatch requires content verification |
| 20261118151655 | `20261118151500_harden_player_rpc_schema` | Historical branch source: `20261118151500_harden_player_rpc_schema.sql`; remote version differs |
| 20261118160528 | `nova_competitive_core` | Historical branch source: `20261118170000_nova_competitive_core.sql`; remote version differs |
| 20261118161142 | `nova_shared_market` | Historical branch source: `20261118172000_nova_shared_market.sql`; remote version differs |
| 20261118161319 | `nova_market_fk_indexes` | Historical branch source: `20261118173000_nova_market_fk_indexes.sql`; remote version differs |
| 20261118162050 | `nova_competitive_duels` | Historical branch source: `20261118174000_nova_competitive_duels.sql`; remote version differs |
| 20261118170627 | `nexora_core_schema_v1` | **Not located in inspected repository refs** |
| 20261118170652 | `nexora_username_compatibility` | Not located in inspected repository refs |
| 20261118170811 | `remove_legacy_nova_functions` | Not located in inspected repository refs |
| 20261118170819 | `remove_legacy_nova_game_tables` | Not located in inspected repository refs |
| 20261118170850 | `nexora_firebase_identity_boundary` | Not located in inspected repository refs |
| 20261118171625 | `nexora_character_creation_rpc` | Not located in inspected repository refs |
| 20261118181814 | `nexora_server_operations` | Local filename matches remote version/name |
| 20261118181827 | `nexora_org_request_pending_unique` | Local filename matches remote version/name |
| 20261118190004 | `nova_character_welcome_branding` | Local filename matches remote version/name |
| 20261118192232 | `nova_remove_properties_and_skill_point_progression` | Local filename matches remote version/name |
| 20261118192618 | `nova_remove_property_mission_path` | Local filename matches remote version/name |
| 20261118192658 | `nova_remove_property_achievement_path` | Not located in inspected repository refs |
| 20261118193136 | `nova_reconcile_skill_points_to_one_per_level` | Candidate local file has same name but different timestamp; verify content |
| 20261118194258 | `nova_fix_company_upgrade_guard_and_indexes` | Candidate local file has same name but different timestamp; verify content |
| 20261118201649 | `nova_social_hub` | Candidate local file has same name but different timestamp; verify content |
| 20261118201750 | `nova_social_conversation_shape` | Candidate local file has same name but different timestamp; verify content |
| 20261118205113 | `nova_player_presence` | Candidate local file has same name but different timestamp; verify content |
| 20261118205409 | `nova_org_donation_ranking` | Candidate local file has same name but different timestamp; verify content |
| 20261118212342 | `nova_company_auction` | Candidate local file has same name but different timestamp; verify content |
| 20261118212718 | `nova_company_auction_immutable_history` | Candidate local file has same name but different timestamp; verify content |
| 20261118212846 | `nova_company_bid_found_guard` | Candidate local file has same name but different timestamp; verify content |
| 20261118222122 | `nova_skill_reset_and_factories` | Local filename matches remote version/name |
| 20261118222810 | `nova_factory_pause_sync_fix` | Local filename matches remote version/name |
| 20261118225248 | `nova_factory_economy_rebalance` | Candidate local file has same name but different timestamp; verify content |
| 20261118225603 | `nova_factory_warehouse_and_level_100` | No same-named local file; nearby warehouse candidate is not assumed equivalent |
| 20261118225737 | `nova_factory_auction_support` | No same-named local file; nearby auction candidate is not assumed equivalent |
| 20261118230011 | `nova_factory_warehouse_capacity_balance` | Candidate local file has same name but different timestamp; verify content |
| 20261118230131 | `nova_factory_auction_capacity_reservations` | Not located in inspected repository refs |
| 20261118230414 | `nova_factory_base_profit_curve` | Candidate local file has same name but different timestamp; verify content |
| 20261118230515 | `nova_add_advanced_factory_resources` | Candidate local file has same name but different timestamp; verify content |
| 20261118232146 | `nova_factory_profit_margin_v2` | Not located in inspected repository refs |
| 20261118233048 | `nova_remove_market_purchase_xp` | Candidate local file has same name but different timestamp; verify content |
| 20261118233344 | `remove_market_purchase_reputation_influence` | Not located in inspected repository refs |
| 20261118233403 | `correct_market_purchase_rewards` | Not located in inspected repository refs |
| 20261118233646 | `add_advanced_resource_manufacturing_recipes` | Candidate local file has a different name; content equivalence unverified |
| 20261118233707 | `balance_advanced_resource_recipe_costs` | Not located in inspected repository refs |

## Local-only migration filenames

These 10 files exist on `main` but have no same-named remote ledger entry in the captured 42 rows. This is a name-level comparison only; some may contain equivalent or consolidated changes, which must be established by diffing their SQL against recovered historical source:

- `20261118180000_nexora_economy_rpcs.sql`
- `20261118183000_nexora_market_rpcs.sql`
- `20261118190000_nexora_manufacturing_rpc.sql`
- `20261118193000_nexora_contract_rpc.sql`
- `20261118200000_nexora_player_settings_notifications.sql`
- `20261118201000_nexora_seed_world.sql`
- `20261118203000_nexora_companies_properties.sql`
- `20261118210000_nexora_company_vault_rpcs.sql`
- `20261119003000_nova_factory_business_auctions.sql`
- `20261119011000_nova_advanced_resource_recipes.sql`

## Interpretation

- Six early player/competitive SQL sources were recovered from historical branches, but their filenames/versions do not match the remote ledger exactly. They are leads for reconciliation, not permission to rewrite migration history.
- Several later remote entries have same-named local candidates under different timestamps. Those must be content-compared before they can be treated as the applied source.
- The 10 local-only names and the missing remote sources show why a blind timestamp rename, bulk migration repair, or replay of all local SQL would be unsafe.
- The 42-row ledger is a history of what Supabase records as applied; it does not contain the SQL bodies. A schema snapshot is insufficient to infer every historical change or its exact ordering.


## Recovery update — all 42 SQL sources recovered

**The original-source blocker is resolved.** The remote ledger has 42 records, and an exact SQL body is now archived for every one:

- 41 bodies were recovered from PostgreSQL `postgres_logs` statement events. Their event timestamps map to the remote migration versions.
- The remaining body, `20261118193136_nova_reconcile_skill_points_to_one_per_level`, was recovered read-only from `supabase_migrations.schema_migrations.statements`.
- Two extra statement events were present in the logs but had no matching version in the current 42-row remote ledger; they were not included as applied migrations.
- The migration metadata table reports **zero rollback arrays** across the 42 rows.
- The archive contains 42 SQL files plus a README under `supabase/recovered-history/`. Every file is outside `supabase/migrations/`; none is pending CLI migration input.

Archive index: [Recovered migration sources](https://github.com/powerx911/NOVA/tree/fix/nova-economy-abuse-guards-20261119/supabase/recovered-history).

## Full-history replay verification

Added `.github/workflows/database-history-replay.yml`. It starts a disposable local Supabase stack, replays all 42 recovered sources in remote-version order, applies the three PR migrations, runs pgTAP, and stops the disposable stack.

<badge color="success">Passed</badge> Run [44507739506 — historical migration replay](https://github.com/powerx911/NOVA/actions/runs/44507739506).

- All 42 recovered SQL files replayed successfully.
- All three NOVA economy-hardening migrations applied successfully after the historical chain.
- pgTAP passed: 29 tests across 2 suites.
- The disposable Supabase stack stopped successfully.
- App CI also passed: [44507739198](https://github.com/powerx911/NOVA/actions/runs/44507739198).
- The existing current-schema snapshot test passed: [44507739566](https://github.com/powerx911/NOVA/actions/runs/44507739566).

## Local-versus-remote content reconciliation

The recovered SQL now allows direct comparison against the 31 SQL files currently on `main`.

### 21 same-name candidates

For the 21 local files whose normalized names match remote ledger names:

- **14** are identical to the applied SQL after trimming outer whitespace.
- **2** become identical after ignoring comments and whitespace:
  - `nova_fix_company_upgrade_guard_and_indexes`
  - `nova_factory_warehouse_capacity_balance`
- **2** have a punctuation discrepancy in the local copy: the local function body omits a semicolon immediately before the closing `$$` delimiter:
  - `nova_player_presence`
  - `nova_org_donation_ranking`
- **3** contain substantive differences from the applied SQL:
  - `nova_factory_economy_rebalance`: local operating-cost values differ from the applied source.
  - `nova_factory_base_profit_curve`: local production-rate values differ from the applied source.
  - `nova_add_advanced_factory_resources`: local production-rate/config values differ from the applied source.

These are source discrepancies, not proof that production is broken. Do not overwrite them blindly; review whether the local versions represent intended future balance changes or accidental drift.

### 10 local filenames without a same-name remote ledger record

The local file `20261119011000_nova_advanced_resource_recipes.sql` is content-equivalent to remote migration `20261118233707_balance_advanced_resource_recipe_costs` after comment/whitespace normalization, despite the filename mismatch.

The other nine files still need explicit classification as pending work, superseded/consolidated SQL, or redundant source:

- `20261118180000_nexora_economy_rpcs.sql`
- `20261118183000_nexora_market_rpcs.sql`
- `20261118190000_nexora_manufacturing_rpc.sql`
- `20261118193000_nexora_contract_rpc.sql`
- `20261118200000_nexora_player_settings_notifications.sql`
- `20261118201000_nexora_seed_world.sql`
- `20261118203000_nexora_companies_properties.sql`
- `20261118210000_nexora_company_vault_rpcs.sql`
- `20261119003000_nova_factory_business_auctions.sql`

## Current safe conclusion

- The full applied migration source sequence is recovered and has replayed successfully in isolation.
- The original `nexora_core_schema_v1` source is no longer missing.
- The remaining reconciliation work is limited to classifying the nine local-only files and resolving the seven same-name local/source discrepancies described above.
- No production DDL, migration repair, or production data change was performed.
- Keep PR #83 Draft and do not run `supabase db push` until those remaining local-vs-remote differences are reviewed and a final active migration directory is prepared.


## Follow-up: untracked SQL executions and replay ordering

The initial 42-entry archive was extended after a second pass through the PostgreSQL statement logs.

- 13 additional direct `POST /mcp` SQL statement events were recovered. They are **not** migration-ledger rows, so they remain separate under `supabase/recovered-history/untracked/`.
- These statements include core RPC definitions and follow-up functions for companies/properties, market, contracts, organizations, leaderboards, and mission/achievement behavior.
- The original nine local-only migration candidates were not automatically promoted into the 42-entry applied migration history. Seven of their SQL bodies are represented by the recovered direct-execution events, not by tracked migration records. The seed-world file has no matching statement event in the inspected log window; the factory-business-auction file still needs content-level classification.
- The replay workflow now orders all recovered files by the timestamp prefix in the filename (rather than by directory path), which is required because tracked and untracked events are stored in separate directories.
- **The expanded 55-source replay passed** on commit `17f9b86b8b98ce6192bfd975f638ce4a5e554c80`: all 42 tracked migration bodies and all 13 untracked SQL events replayed in timestamp order; all three NOVA hardening migrations then applied; pgTAP passed 29 tests across 2 suites; and the disposable Supabase stack stopped successfully. Run: https://github.com/powerx911/NOVA/actions/runs/44509292564.
- App CI also passed on that commit: https://github.com/powerx911/NOVA/actions/runs/44509292659.
- The expanded replay is strictly disposable/local. No production SQL has been executed.

**Do not infer that untracked direct SQL events are safe to apply to production.** They are forensic evidence of SQL statements sent through the management API, and may depend on earlier state or have since been replaced.
