# NEXORA / OneState — Shared Supabase Project Isolation Contract

**Status (2026-11-16):** NEXORA's isolated schema has a baseline of 22 tables. RLS is enabled on all 22 and no `anon` or `authenticated` table grants exist. The schema is not exposed through the Data API. No NEXORA player data has been imported, and the application still uses Firebase as its live source of truth.

This document is mandatory context for any agent, developer, or automation that inspects or changes the shared Supabase project. Read it before running SQL, applying migrations, changing Auth, or editing either application.

## 1. Shared infrastructure, separate application data

Both applications use the same Supabase project:

- **Project name:** `OneState-Trading-DB`
- **Project ref:** `dmeupqmhsyojxlgalxrc`
- **Region:** `eu-west-1`
- **NEXORA schema:** `nexora`
- **OneState schema:** `public`

The existing OneState objects in `public` include these eight tables/views:
`car_image_index`, `cars_catalog`, `cash_ledger`, `current_inventory`, `dashboard_summary`, `inventory`, `settings`, and `trades`.

The NEXORA baseline currently contains 22 tables:
`player_profiles`, `player_private`, `wallets`, `transactions`, `inventory`, `market_listings`, `market_orders`, `companies`, `company_logs`, `properties`, `organizations`, `organization_members`, `organization_requests`, `organization_transactions`, `player_missions`, `daily_claims`, `contract_claims`, `player_achievements`, `notifications`, `world_events`, `audit_logs`, and `diagnostics_admins`.

All 22 NEXORA tables have RLS enabled. The database verification query confirmed zero table grants to `anon` and `authenticated` for every NEXORA table. The schema remains unexposed in Data API settings. No user/player records were imported. The NEXORA migration did not move, rename, copy, or modify any OneState `public` object.

## 2. Mandatory isolation rules

1. Put every NEXORA table, view, sequence, index, trigger, and function in the `nexora` schema unless a reviewed architecture decision explicitly requires a private non-exposed helper schema.
2. Never create NEXORA objects in `public`.
3. Never rename, alter, truncate, delete, or repurpose OneState objects in `public`.
4. Never run broad destructive SQL such as unqualified `DROP`, `TRUNCATE`, or `DELETE` against the shared project.
5. Fully qualify NEXORA SQL object names (for example, `nexora.player_profiles`) in migrations, functions, and administrative queries. Do not rely on a default `search_path`.
6. Use NEXORA-specific table names, constraints, indexes, policies, RPC names, and migration identifiers.
7. Apply RLS to every NEXORA table. Grants determine whether a role can reach an object; RLS determines which rows it can access.
8. Do not expose `nexora` in Data API settings or grant client roles access until the complete RLS/grant model and API surface have been reviewed and tested.
9. Do not change project-wide API settings, Auth providers, redirect URLs, storage buckets, extensions, or global database roles without checking the impact on OneState first.
10. Never put Supabase secret/service-role keys in frontend code, GitHub, public environment variables, or chat.

The current lack of NEXORA RLS policies is deliberate fail-closed protection, not an invitation to grant broad access. Security Advisor's `rls_enabled_no_policy` INFO notices for NEXORA are expected until a reviewed identity model is implemented. Existing Advisor notices on OneState's `public` objects are pre-existing and must not be remediated as part of NEXORA work.

## 3. Important limitation: Supabase Auth is project-wide

PostgreSQL schemas isolate application data; they do **not** create separate Supabase Auth services. The `auth` schema and user directory are project-wide.

Therefore:
- Do not assume that creating `nexora` gives NEXORA a separate Auth user pool.
- If NEXORA uses this project's Supabase Auth, its identities live in the same project-wide Auth service used by any other application configured to use it.
- If fully separate login accounts, provider settings, sessions, or Auth administration are required, keep NEXORA on its existing Firebase Auth until a separate Supabase project or another isolated Auth service is available. Do not silently migrate NEXORA to shared Auth.

## 4. Migration and security requirements

NEXORA's Firestore design contains security invariants that must be reimplemented before switching the application:

- Verified-email enforcement.
- Atomic wallet updates tied to an immutable transaction ledger.
- Server-authoritative XP, progression, and skill-point changes.
- Anti-minting inventory and atomic market escrow.
- Immutable financial ledgers and claim records.
- Owner-only, read-only diagnostics.

The initial Supabase baseline adds typed domain tables, non-negative and relationship constraints, selected query indexes, RLS on all tables, and database triggers preventing UPDATE/DELETE on immutable financial/claim/audit records. It intentionally grants no client table access and exposes no Data API schema yet.

Implement sensitive economy changes through reviewed Postgres transactions/RPC or trusted server-side functions. Never allow a browser client to directly set wallet balances, mint inventory, award progression, or rewrite immutable history. Design RLS from the actual identity and access model; do not use broad authenticated-user policies.

Do not migrate or delete existing Firestore data until an explicit export/import plan, counts, integrity checks, and rollback plan have been completed. Keep Firebase as the source of truth until Supabase implementation has passed parity/security tests and a deliberate cutover is approved.

## 5. Agent handoff checklist

Before working on this shared project, an agent must:

- Identify the target application and schema explicitly.
- Inspect the current schema and object list before writing SQL.
- Confirm every NEXORA migration targets `nexora` only.
- Verify no OneState `public` object was changed.
- Review grants, RLS policies, functions, and Supabase Security Advisor findings.
- Record changes in this repository and state clearly whether they affect only NEXORA or project-wide services.

**Safe mental model:** one Supabase project and one Postgres database, but two separate application namespaces. `public` belongs to OneState; `nexora` belongs to NEXORA. Shared infrastructure does not mean shared application tables or permission to modify the other application's data.
