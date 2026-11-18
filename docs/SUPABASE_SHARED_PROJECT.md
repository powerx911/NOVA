# NEXORA / NOVA — Supabase isolation contract

**Status (2026-11-18):** The NOVA Supabase project `hmrprnjhyzyefocdmnxf` now contains an isolated `nexora` schema with 23 empty tables. RLS is enabled on all 23 tables. The `anon` and `authenticated` roles have no table privileges; `service_role` is reserved for trusted server operations. No NEXORA player data has been imported.

## Project boundary

- **Supabase project:** `NOVA` (`hmrprnjhyzyefocdmnxf`, region `eu-west-1`).
- **NEXORA application schema:** `nexora`.
- **Legacy NOVA:** all 17 old `public.nova_*` game tables and old `nova_*` functions were removed after verifying that every legacy game table contained zero rows.
- **Platform schemas:** do not modify `auth`, `storage`, `realtime`, `vault`, `extensions`, or Supabase-managed objects as part of game work.

## Mandatory isolation rules

1. Create all NEXORA application objects in `nexora`, never in `public`.
2. Fully qualify every database object (for example, `nexora.player_profiles`).
3. Keep RLS enabled on every NEXORA table.
4. Do not grant direct `anon` or `authenticated` access until a reviewed policy model and security tests exist.
5. Use `service_role` only inside trusted server-side Edge Functions. Never expose it in browser code, public environment variables, GitHub, or chat.
6. Do not change project-wide Auth providers, redirect URLs, API exposure settings, Storage, Realtime, extensions, or global database roles without reviewing the effect on the entire NOVA Supabase project.
7. Do not add permissive RLS policies merely to silence the expected `rls_enabled_no_policy` INFO notices.

## Identity and runtime boundary

The copied NEXORA client currently uses the original Firebase Auth and Firestore implementation. The NOVA Supabase schema is provisioned but is **not yet the live gameplay backend**.

The intended transition is:
- Keep Firebase Auth as the identity provider initially, so existing NEXORA sign-in behavior can be preserved.
- Use Firebase UID strings as the application identity in the `nexora` schema.
- Verify Firebase ID tokens inside trusted Supabase Edge Functions.
- Move game state and authoritative transactions to Supabase/Postgres.
- Do not connect the browser directly to privileged tables or allow client-side wallet, inventory, XP, market escrow, company revenue, or organization treasury mutations.

Do not deploy the copied client as the NOVA production game until the Firebase-to-Supabase data API, security model, and parity tests are complete. Do not import original Firestore player data unless a separate explicit migration plan, counts, integrity checks, and rollback plan have been approved.

## Current schema

The `nexora` schema contains:
`player_profiles`, `player_private`, `wallets`, `transactions`, `inventory`, `market_listings`, `market_orders`, `companies`, `company_logs`, `properties`, `organizations`, `organization_members`, `organization_requests`, `organization_transactions`, `player_missions`, `daily_claims`, `contract_claims`, `player_achievements`, `notifications`, `world_events`, `audit_logs`, `diagnostics_admins`, and `usernames`.

All tables are empty. All have RLS enabled. No client policies or grants have been added.

## Verification checklist before cutover

- Confirm the application uses the NOVA Supabase project only.
- Implement and test trusted operations for character creation, wallet ledger, inventory, market escrow, XP/skills, company/property revenue, organization membership/treasury, claims, and diagnostics.
- Verify authorization, idempotency, concurrency, replay protection, non-negative balances, and immutable records.
- Confirm no privileged key is present in the built frontend bundle.
- Verify the original NEXORA Firebase project is not modified by NOVA workflows.
- Complete a documented rollback and production smoke test before enabling GitHub Pages deployment.
