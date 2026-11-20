# NOVA — Project Status

**Updated:** 2026-11-20  
**Repository:** https://github.com/powerx911/NOVA  
**Production URL:** https://powerx911.github.io/NOVA/  
**Production branch:** `main`  
**Reviewed base commit:** `a12e275750a1882e309aaf2683ec3abbf17b440a`  
**Current work branch:** `fix/nova-account-treasury-auction-hardening-20261120`

## Canonical project identity

NOVA is the player-facing game and brand name. The current database schema remains `nexora`, and the deployed Supabase Edge Function remains `nexora-api`; these are legacy internal identifiers retained for compatibility. Do not rename either by bulk replacement.

## Live architecture

- Frontend: React, TypeScript and Vite, published through GitHub Pages and GitHub Actions.
- Identity: Firebase Authentication.
- Game data/economy: Supabase PostgreSQL project `hmrprnjhyzyefocdmnxf`, schema `nexora`.
- API boundary: Supabase Edge Function `nexora-api`; it verifies Firebase ID tokens and uses a server-side service-role client.
- Firestore: legacy diagnostics and older server code remain in the repository; they are not the authoritative game economy. Audit deployed Firebase Functions before removing them.
- `api/*` files are not deployed by the GitHub Pages workflow, which publishes the static `dist` directory only.

## Production database inventory — read-only audit, 2026-11-20

- 45 tables, 144 functions (131 SECURITY DEFINER), 37 triggers, 97 indexes and 167 constraints in `nexora`.
- 8 active pg_cron jobs.
- 74 applied migration records in Supabase.
- The tracked repository has 70 SQL migration files.
- One applied production hotfix has no matching canonical migration file in the repository; its SQL remains available in the production migration ledger.
- 21 historical migration names have differing tracked/recovered copies and require checksum-based source classification.

## Snapshot and test status

- `supabase/ci/nexora_schema_snapshot.sql` currently contains 34 table definitions and 78 function definitions. It is a historical baseline, not a complete snapshot of current production.
- Isolated database workflows restore this baseline and apply a curated subset of migrations. The subset must be kept synchronized with all five latest production economy migrations and any new hardening migrations.
- Do not run `supabase db push`, migration repair, or production DDL to paper over this drift.
- A complete snapshot refresh requires a verified schema-only export and a disposable PostgreSQL replay, followed by pgTAP and schema-count parity checks.

## Current hardening batch

Branch: `fix/nova-account-treasury-auction-hardening-20261120`

- Disable organization treasury withdrawals at the UI, Edge API and database RPC layers.
- Refund a reserved company/factory auction escrow before cancelling an auction whose underlying asset is missing.
- Add pgTAP regression coverage for the withdrawal lock and missing-asset auction refunds.
- Include the five latest production economy migrations and the new hardening migration in both isolated database workflows.

These changes are on a work branch and are not production changes until reviewed, merged and deployed through the normal release process.

## Remaining requested work

1. Rebuild account deletion around Firebase Auth + Supabase, retaining/pseudonymizing legal and financial history.
2. Reconcile the missing production hotfix and create a canonical migration manifest with checksums.
3. Refresh the SQL snapshot from a verified schema-only export; expand replay to cover the full canonical migration set.
4. Add idempotency keys to all retryable financial and commerce operations.
5. Retire obsolete Firestore/Vercel API paths only after diagnostics and retention requirements are migrated.
6. Add cursor pagination for market listings/activity and short caching for safe public reads.
7. Consolidate notifications into a single event center with stable event keys and hierarchical badges.
8. Add a single package manager/lockfile and automated dependency updates.

Feedback and suggestions delivery plus the moderator/admin console are intentionally deferred until the game is feature-complete and launch preparation begins.

## Safety constraints

- Never delete, reset, or overwrite real player wallets, inventory, ownership or financial history as part of testing.
- Never modify main directly.
- Keep each implementation batch isolated on its own branch/PR and verify CI before merging.
- Do not deploy schema changes directly to production while migration history and snapshot parity remain unresolved.
- Do not claim a change is live until GitHub Pages and the published version manifest confirm it.
