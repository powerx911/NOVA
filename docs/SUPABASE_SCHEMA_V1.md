# NEXORA Supabase Schema Baseline v1

**Applied:** 2026-11-16  
**Project:** `OneState-Trading-DB` (`dmeupqmhsyojxlgalxrc`)  
**Schema:** `nexora` only  
**Migration history entries:** `nexora_core_schema_v1`, `nexora_fk_indexes_v1`

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

The baseline includes typed columns, primary/unique keys, non-negative/range checks, selected foreign keys, query indexes, and explicit schema-qualified objects. The financial ledger, organization treasury ledger, mission/daily/contract claims, achievements, and audit logs have database triggers that reject UPDATE and DELETE.

## Security posture — intentionally closed

- RLS is enabled on all 22 tables.
- No `anon` or `authenticated` table grants exist on any NEXORA table.
- No NEXORA schema usage grant or Data API exposure has been enabled.
- No browser RLS policies have been added. With RLS enabled and no grants/policies, client access remains denied.
- No NEXORA user data has been imported.
- Firebase Auth and Firestore remain the active application runtime and source of truth.

The Security Advisor reports `rls_enabled_no_policy` INFO notices for the 22 NEXORA tables. These are expected for this closed bootstrap state; do not add permissive policies just to silence the notices. The Advisor also reports existing notices for OneState's `public` tables; they are outside this project's scope and must not be changed.

## Follow-up work before any cutover

1. Decide the identity boundary. Supabase Auth is project-wide and cannot be assumed to be separate from OneState. Keep Firebase Auth until an approved design supports secure server verification.
2. Implement trusted server-side operations (or carefully reviewed RPCs) for character creation, wallet ledger mutations, inventory, market escrow, XP/skills, company/property revenue, organization RBAC/treasury, claims, and diagnostics.
3. Write tests for authorization, idempotency, concurrency, replay, negative balances, minting, and immutable records.
4. Design and test row-level read policies only after the chosen identity model is settled.
5. Prepare export/import with counts, reconciliation, and rollback; do not copy or delete Firestore data before this passes.
6. Keep `nexora` unexposed and client grants absent until all security checks pass.
7. Verify OneState's `public` object inventory before and after each NEXORA database migration.
