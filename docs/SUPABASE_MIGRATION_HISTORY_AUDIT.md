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
- **2** had a punctuation discrepancy in the original local copy: the function body omitted a semicolon immediately before the closing `$` delimiter. This was corrected on the PR branch for `nova_player_presence` and `nova_org_donation_ranking`; the historical replay workflow now reapplies both local files after the recovered chain, which compiles the PL/pgSQL definitions in PostgreSQL.
- **3** contain substantive differences from the applied SQL:
  - `nova_factory_economy_rebalance`: local operating-cost values differ from the applied source.
  - `nova_factory_base_profit_curve`: local production-rate values differ from the applied source.
  - `nova_add_advanced_factory_resources`: local production-rate/config values differ from the applied source.

These are source discrepancies, not proof that production is broken. Do not overwrite them blindly; review whether the local versions represent intended future balance changes or accidental drift.

### 10 local filenames without a same-name remote ledger record

The local file `20261119011000_nova_advanced_resource_recipes.sql` is content-equivalent to remote migration `20261118233707_balance_advanced_resource_recipe_costs` after comment/whitespace normalization, despite the filename mismatch.

The other nine files were subsequently classified in the follow-up reconciliation section below; their correspondence to historical events does not make them interchangeable with applied migrations:

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
- The nine local-only candidates now have a documented classification, and the three factory-economy intermediate differences have later-history context. Remaining work is a source-by-source final-definition review before any deployment plan; the active migration directory is still not certified for production push.
- No production DDL, migration repair, or production data change was performed.
- Keep PR #83 Draft and do not run `supabase db push` until those remaining local-vs-remote differences are reviewed and a final active migration directory is prepared.


## Follow-up: untracked SQL executions and replay ordering

The initial 42-entry archive was extended after a second pass through the PostgreSQL statement logs.

- 13 additional direct `POST /mcp` SQL statement events were recovered. They are **not** migration-ledger rows, so they remain separate under `supabase/recovered-history/untracked/`.
- These statements include core RPC definitions and follow-up functions for companies/properties, market, contracts, organizations, leaderboards, and mission/achievement behavior.
- The original nine local-only migration candidates were not promoted into the 42-entry applied migration history. Seven RPC candidates correspond by function signatures to recovered direct-execution events: two match after comment/whitespace normalization and five have SQL-body differences. The seed-world file has no matching statement event in the inspected log window and its applied status is unknown. The factory-business-auction file is a composite overlapping multiple tracked auction sources, not a one-to-one missing migration; see the detailed follow-up section below.
- The replay workflow now orders all recovered files by the timestamp prefix in the filename (rather than by directory path), which is required because tracked and untracked events are stored in separate directories.
- **The expanded 55-source replay passed** on commit `17f9b86b8b98ce6192bfd975f638ce4a5e554c80`: all 42 tracked migration bodies and all 13 untracked SQL events replayed in timestamp order; all three NOVA hardening migrations then applied; pgTAP passed 29 tests across 2 suites; and the disposable Supabase stack stopped successfully. Run: https://github.com/powerx911/NOVA/actions/runs/44509292564.
- App CI also passed on that commit: https://github.com/powerx911/NOVA/actions/runs/44509292659.
- The expanded replay is strictly disposable/local. No production SQL has been executed.

**Do not infer that untracked direct SQL events are safe to apply to production.** They are forensic evidence of SQL statements sent through the management API, and may depend on earlier state or have since been replaced.

## Follow-up reconciliation — 2026-11-19 (latest branch audit)

### Seven local-only RPC candidates versus untracked SQL events

The seven RPC-oriented local-only files were matched to the seven corresponding recovered direct-SQL events by their function names and signatures. This is a correspondence, **not blanket content equivalence**:

- `nexora_contract_rpc` and `nexora_player_settings_notifications` match their recovered event bodies after comment/whitespace normalization.
- `nexora_economy_rpcs`, `nexora_market_rpcs`, `nexora_manufacturing_rpc`, `nexora_companies_properties`, and `nexora_company_vault_rpcs` contain the same function signatures but differ in SQL content from the recovered event bodies. They must remain classified as divergent local candidates, not as exact copies of the logged executions.
- The recovered events remain forensic records under `supabase/recovered-history/untracked/`; none is promoted into the migration ledger.

### Seed-world candidate

`20261118201000_nexora_seed_world.sql` contains inserts for six starter market listings and three world events. No matching statement event was found in the inspected recovered SQL history. Whether these seed rows were applied through another path or remain pending is **unverified**. Do not apply or remove the file based on the log gap alone.

### Factory/business auction candidate

`20261119003000_nova_factory_business_auctions.sql` is a composite candidate, not a clean one-to-one missing migration. It combines auction schema alterations and several function definitions that overlap with recovered tracked sources, including `nova_factory_auction_support` (factory auction list/bid/settle functions) and `nova_factory_auction_capacity_reservations` (factory capacity logic), plus auction-fetch/settlement helpers already present in the broader auction history. Its combined body is not an exact substitute for a single remote ledger record. Keep it out of any automatic history repair or production push until each DDL/function is mapped to its applied source and final definition.

### Three factory-economy source differences — final-state context

The three same-name differences remain real differences in intermediate historical SQL bodies, but later remote migrations explain much of the apparent value drift:

- The local `nova_factory_economy_rebalance` rates (2.00/2.00/1.50/1.50/1.25/2.00) differ from the earlier recovered remote migration's rates (8.00/7.00/6.00/5.00/4.00/3.00).
- The local `nova_factory_base_profit_curve` rates (1.10/1.03/0.92/0.89/0.88/0.87) differ from the earlier remote `nova_factory_base_profit_curve` rates (2.00/2.00/1.50/1.50/1.25/2.00).
- The local `nova_add_advanced_factory_resources` values for the ten resource tiers use the later lower production curve. The recovered remote `nova_factory_profit_margin_v2` subsequently replaces `factory_resource_config` with that same final lower curve, including the four advanced resources.

Therefore the mismatches are not, by themselves, evidence of a production balance defect: later applied history supersedes the earlier values. However, the local intermediate migration bodies still do not reproduce the exact remote history and must not be substituted into the applied ledger. The final effective function definition should be compared as a whole before preparing a deployment chain.

### Latest branch verification

The branch head before this documentation-only follow-up was `f0f4709584249aff8c6039d035eb43be0b1cf1e4`. All three workflows completed successfully on that exact commit:

- App CI: [44509621372](https://github.com/powerx911/NOVA/actions/runs/44509621372)
- Isolated PostgreSQL/pgTAP: [44509621509](https://github.com/powerx911/NOVA/actions/runs/44509621509)
- Full historical replay: [44509621481](https://github.com/powerx911/NOVA/actions/runs/44509621481)

The PR remains Draft and unmerged. These checks ran on the code/workflow tree immediately before this audit-document update; no application or SQL behavior was changed by this addendum.
## Follow-up: local PL/pgSQL syntax repair and verification

The local `nova_player_presence` and `nova_org_donation_ranking` files were found to omit the required semicolon before the PL/pgSQL dollar-quote terminator. Both local definitions were corrected without changing their logic. The historical replay workflow now compiles these two local files against the fully replayed disposable database before applying the three economy-hardening migrations.

Verification on code/workflow commit `096fc4d6c99e2789cc59578eba4e22ac08edcef2`: SQL validation passed; the 55-source historical replay passed; both corrected local files compiled successfully; pgTAP passed 29 tests across 2 suites; and the disposable Supabase stack stopped successfully.

- App CI: https://github.com/powerx911/NOVA/actions/runs/44510761805
- Isolated PostgreSQL/pgTAP: https://github.com/powerx911/NOVA/actions/runs/44510752960
- Historical replay + local PL/pgSQL compile + pgTAP: https://github.com/powerx911/NOVA/actions/runs/44510752943

The two duplicate in-progress workflow attempts on the same commit are not used as evidence; the links above are completed successful runs.
## Release-readiness boundary — latest 34-file inventory

A fresh tree inventory on this branch contains **34 SQL files** under `supabase/migrations/` (31 carried from `main` plus the three new PR migrations). The successful `database-history-replay` workflow does **not** execute all 34 active migration files as a deployment chain. Its exact scope is:

1. Start a disposable Supabase/PostgreSQL stack with the active migration directory temporarily parked.
2. Replay the 42 recovered ledger SQL bodies and 13 untracked forensic SQL events (55 total) in timestamp order.
3. Compile the two corrected local `nova_player_presence` and `nova_org_donation_ranking` definitions against that recovered state.
4. Apply the three new PR hardening migrations and run the 29 pgTAP tests.

This is strong evidence that the recovered applied history and the new PR changes work in isolation. It is **not** evidence that the current 34-file `supabase/migrations/` directory is safe for `supabase db push`: several existing local files are duplicate, divergent, consolidated, or unresolved relative to the remote 42-version ledger. Replaying every active local file on top of the recovered history would risk duplicate DDL and conflicting definitions; the CI workflow intentionally does not do that.

### Current decision

- Keep PR #83 Draft. Do not merge it as a deployment-ready migration bundle and do not run `supabase db push`.
- Do not use `migration repair` or rename timestamps to force the active local files into alignment.
- A future deployment package must be prepared separately from the forensic archive: map every active local file to its exact remote ledger source/final object state, identify which changes are genuinely new, and include only reviewed pending migrations in a clean release chain.
- The 34-file inventory and the exact CI replay scope were checked on branch head `7118ec2f0c74d39275f252ab433c02393ff65257`. All three workflows succeeded on that exact commit: App CI [44511078361](https://github.com/powerx911/NOVA/actions/runs/44511078361), historical replay [44511078310](https://github.com/powerx911/NOVA/actions/runs/44511078310), and isolated database tests [44511078178](https://github.com/powerx911/NOVA/actions/runs/44511078178).

No production writes, migration pushes, or ledger repairs were performed.
## Read-only production function-state check

On 2026-11-19, the active healthy production project was queried using catalog metadata only (`pg_get_functiondef`/string markers); no player rows or business data were read and no writes were issued. The observed live definitions confirm that PR #83 has **not** been deployed:

| Production function | Live marker result | Meaning for pending PR |
|---|---|---|
| `collect_company_revenue` | Still contains reputation and influence reward references; 30-second cooldown and cumulative-revenue XP logic are present | The PR's reward removal is not live yet |
| `transfer_credits` | Sorted wallet lock is present; level-10 gate, 3% fee, and daily 10,000 cap markers are absent | The PR's transfer limits are not live yet |
| `buy_market_listing` | No reputation/influence reward references; sorted wallet lock marker was not detected by the simple marker check | Its current live body is not the PR version; review lock ordering from the exact function body before release |
| `place_factory_auction_bid` / `settle_factory_auction` | 4% fee and 5-minute extension markers are absent | The PR auction fee/extension changes are not live yet |

This check is a marker-based read of current function definitions, not a full semantic proof of every branch. It establishes the deployment boundary: the hardening changes remain pending in Draft PR #83. Do not tell players or operators that the new economy/transfer/auction rules are active until a separately reviewed deployment has actually succeeded.

Production ledger still reports 42 migration records. No production function was replaced, no migration was pushed or repaired, and no player/business data was accessed.
## Exact production function comparison — lock ordering and pending guards

A read-only `pg_get_functiondef` inspection on the active production database confirmed the following exact live behavior (function definitions only; no player or business rows were queried):

- `nexora.collect_company_revenue(text,text)` still grants a minimum of 10 XP per collection and increments reputation/influence. Its current row-lock sequence is company → wallet → profile. The PR replacement removes reputation/influence, awards XP only when cumulative collected revenue crosses each 15-credit threshold, and uses company → profile → wallet.
- `nexora.transfer_credits(text,text,bigint,text)` currently has a deterministic wallet lock (`ORDER BY user_id`) but no level-10 requirement, transfer fee, or daily cap. The PR replacement adds level 10, 3% fee, and a UTC daily 10,000-credit sender cap while retaining deterministic wallet locks.
- `nexora.buy_market_listing(text,text,integer)` currently locks listing → buyer profile → buyer wallet → seller wallet. Reciprocal trades can therefore acquire the two wallet rows in opposite orders. The PR replacement locks buyer profile → both wallets ordered by `user_id` → listing, rechecks the seller/listing after locks, and does not grant XP/reputation/influence.
- The auction fee and anti-sniping triggers are also new PR behavior and are not present in the live production definitions inspected earlier.

These exact definitions strengthen the reason not to deploy the active migration directory wholesale. The three PR migrations are targeted function/trigger replacements and should be considered for a separately reviewed release only after the full migration-ledger mapping and rollback plan are complete. No production DDL, data writes, or migration-ledger changes were made.

### Current CI status at time of this audit

On branch head `9ff51e68ba75d169fcfb08470af6a382137c41a8`, App CI completed successfully (run 44512233031). The isolated PostgreSQL/pgTAP and 55-source historical replay runs (44512233131 and 44512233105) were still running when this section was recorded; do not treat them as passed until GitHub reports successful conclusions.
## Final verification after auction regression fixture fixes
- Latest verified branch head: `01b73172cbf8c6234c17bc76ed33f71da7c262a3`.
- App CI passed: [44512952167](https://github.com/powerx911/NOVA/actions/runs/44512952167).
- Isolated PostgreSQL 17 + pgTAP passed: [44512952175](https://github.com/powerx911/NOVA/actions/runs/44512952175). The job log reports `Files=2, Tests=33` and `Result: PASS`; `economy_abuse_guards.test.sql` passed all 23 assertions, including the 4% seller debit, `last_tx_id`, `auction_fee` transaction, and anti-sniping extension checks.
- Full recovered-history replay passed: [44512952138](https://github.com/powerx911/NOVA/actions/runs/44512952138). The job replayed 42 tracked migration sources plus 13 untracked SQL events in timestamp order, compiled the local presence/ranking SQL, applied the three PR migrations, ran pgTAP, and stopped the disposable Supabase stack successfully.
- These are disposable CI results only. The live production database remains unchanged; the active migration directory still is not certified for `supabase db push`. PR #83 remains Draft and unmerged pending a separately reconciled clean release chain.

## Release execution update — 2026-11-19 (supersedes prior pending-deployment notes)

The user's explicit release direction was received. After reviewing the exact three PR migration bodies against the live production catalog/schema, the three targeted migrations were applied to the healthy NOVA production project through the Supabase migration operation. The previous statements in this historical audit saying "no production DDL", "not deployed", or "keep Draft pending a release chain" describe the state **before this section** and are superseded for these three migrations only.

### Applied production migration records

| Remote version | Migration | Result |
|---|---|---|
| 20261119112257 | `nova_economy_abuse_guards` | Applied |
| 20261119112311 | `nova_recurring_mission_periods` | Applied |
| 20261119112320 | `nova_market_wallet_lock_order` | Applied |

The three resulting records were confirmed in the remote migration ledger (45 records total). The repository migration filenames and both isolated database workflows were updated to use these exact remote versions, preventing a later CLI push from treating the same changes as pending under their previous local timestamps.

### Post-application production catalog verification

A read-only catalog check after applying the migrations confirmed:

- `collect_company_revenue`: cumulative XP threshold logic is present and the old reputation reward marker is absent.
- `transfer_credits`: level-10 gate, 3% fee, and daily transfer-cap guard are present.
- `buy_market_listing`: post-lock seller/listing recheck is present.
- Both auction triggers are installed on `nexora.company_auctions`.
- `player_missions.period_key` exists and the primary key is now `(user_id, mission_id, period_key)`.

This was metadata/function-definition verification only. No player rows or business records were read or modified as part of the release operation. No seed-world SQL or the unrelated divergent local migration files were applied.

### Remaining release work

- The database hardening migrations are live. The application/UI changes in this PR are **not yet live** until the PR is merged and the frontend deployment completes.
- The local active migration directory still contains inherited historical files with unresolved differences; this release did not run a wholesale `supabase db push`, bulk repair, or replay of those files.
- The three deployed migration filenames now match the exact remote versions. Isolated CI workflows were updated accordingly and must be green again on the new branch head before merging.
- Do not change or deploy the separate agent branch `fix/nova-urgent-economy-quality`.


### Final release verification on branch head `fa44255b97921d4f11b5b3108e3931ad97a86464`

After aligning the three active migration filenames to the exact versions recorded by production, both isolated database workflows were rerun successfully against this branch head:

- App CI: [44514497268](https://github.com/powerx911/NOVA/actions/runs/44514497268) — success.
- Isolated PostgreSQL 17 + pgTAP: [44514506215](https://github.com/powerx911/NOVA/actions/runs/44514506215) — success; logs report `Files=2, Tests=33`, `Result: PASS`, including all 23 economy-abuse assertions.
- Full historical replay: [44514511180](https://github.com/powerx911/NOVA/actions/runs/44514511180) — success; 42 tracked sources + 13 untracked events replayed, both local PL/pgSQL definitions compiled, the three version-aligned PR migrations applied, pgTAP passed, and the disposable stack stopped successfully.

The production ledger and local migration filenames now agree for all three newly applied changes. The PR's app changes remain unpublished until merge; the main-branch GitHub Pages workflow is the repository's configured website deployment path.


### Edge API release update

The `nexora-api` Supabase Edge Function was also deployed from this PR branch after the database migrations. Supabase reports the function as `ACTIVE`, version **31**, with its existing `verify_jwt=false` setting preserved. The deployed source was read back with the Supabase function inspection operation and includes the updated bootstrap payload (recurring mission rows and current-day completed market-purchase count). The unrelated `nova-control` function was not changed.


### Transfer UX/API error follow-up

A final UX review found that the new transfer guard errors were being collapsed to a generic API error, and the confirmation dialog did not preview the 3% fee. Corrected both before publishing the frontend:

- The `nexora-api` transfer handler now preserves `TRANSFER_LEVEL_REQUIRED` and `TRANSFER_DAILY_LIMIT` error codes.
- The market transfer form now explains the exact 3% fee and recipient net amount before confirmation, and displays clear Arabic/English messages for the level-10 gate and daily cap.
- Redeployed `nexora-api`; Supabase reports **ACTIVE version 32**, preserving `verify_jwt=false`.
- These last UI/API changes are included in the current PR branch and are subject to the final App CI run before merge.
