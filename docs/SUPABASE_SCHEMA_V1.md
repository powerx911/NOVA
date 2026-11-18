# NEXORA Supabase Schema Baseline v1

**Applied:** 2026-11-18  
**Project:** `NOVA` (`hmrprnjhyzyefocdmnxf`)  
**Schema:** `nexora` only  
**Migration history entries:** `nexora_core_schema_v1`, `nexora_username_compatibility`, `nexora_firebase_identity_boundary`

## Scope

This baseline creates the following 22 domain tables inside `nexora`:

| Area | Tables |
|---|---|
| Identity and profiles | `player_profiles`, `player_private` |
| Economy | `wallets`, `transactions` |
| Items and market | `inventory`, `market_listings`, `market_orders` |
| Businesses and properties | `companies`, `company_logs`, `properties` |
| Organizations | `organizations`, `organization_members`, `organization_requests`, `organization_transactions` |
| Progression and claims | `player_missions`, `daily_claims`, `contract_claims`, `player_achievements` |
| Platform | `notifications`, `world_events`, `audit_logs`, `diagnostics_admins` |

The baseline includes typed columns, primary/unique keys, non-negative/range checks, selected foreign keys, query indexes, and explicit schema-qualified objects. Firebase UID fields are stored as text so the initial identity provider can remain Firebase Auth while gameplay state moves to Supabase. The financial ledger, company logs, organization treasury ledger, mission/daily/contract claims, achievements, and audit logs have database triggers that reject UPDATE and DELETE.

## Security posture — intentionally closed

- RLS is enabled on all 22 tables.
- No `anon` or `authenticated` table grants exist on any NEXORA table.
- No NEXORA schema usage grant or Data API exposure has been enabled.
- No browser RLS policies have been added. With RLS enabled and no grants/policies, client access remains denied.
- No NEXORA player data has been imported.
- The legacy NOVA public game tables and `nova_*` functions were removed after confirming that the legacy tables contained zero rows.
- Firebase Auth remains the identity provider during the staged cutover. Core gameplay state and the migrated economy/company/property operations now use the trusted Supabase Edge API; unported organization/mission/achievement flows remain transitional and must not be treated as production-ready.

The Security Advisor reports `rls_enabled_no_policy` INFO notices for the 22 NEXORA tables. These are expected for this closed bootstrap state; do not add permissive policies just to silence the notices. The Advisor also reports existing notices for OneState's `public` tables; they are outside this project's scope and must not be changed.

## Follow-up work before production release

1. Decide the identity boundary. Supabase Auth is project-wide and cannot be assumed to be separate from OneState. Keep Firebase Auth until an approved design supports secure server verification.
2. Finish trusted server-side operations for organization RBAC/treasury, missions, achievements, diagnostics, and any remaining legacy client actions.
3. Expand tests for authorization, idempotency, concurrency, replay, negative balances, minting, and immutable records across every migrated RPC.
4. Design and test row-level read policies only after the chosen identity model is settled.
5. Prepare export/import with counts, reconciliation, and rollback; do not copy or delete Firestore data before this passes.
6. Keep `nexora` unexposed and client grants absent until all security checks pass.
7. Verify OneState's `public` object inventory before and after each NEXORA database migration.
