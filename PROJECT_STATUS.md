# NOVA — Project Status

**Updated:** 2026-11-20  
**Repository:** https://github.com/powerx911/NOVA  
**Production URL:** https://powerx911.github.io/NOVA/  
**Production branch:** `main`  
**Reviewed base commit:** `a12e275750a1882e309aaf2683ec3abbf17b440a`  
**Current stacked work branch:** `fix/nova-account-deletion-20261120`

## Canonical project identity

NOVA is the player-facing game and brand name. The current database schema remains `nexora`, and the deployed Supabase Edge Function remains `nexora-api`; these are legacy internal identifiers retained for compatibility. Do not rename either by bulk replacement.

## Live architecture

- Frontend: React, TypeScript and Vite, published through GitHub Pages and GitHub Actions.
- Identity: Firebase Authentication.
- Game data/economy: Supabase PostgreSQL project `hmrprnjhyzyefocdmnxf`, schema `nexora`.
- API boundary: Supabase Edge Function `nexora-api`; it verifies Firebase ID tokens and uses a server-side service-role client.
- Firestore: legacy owner diagnostics and older server code remain; they are not the authoritative game economy. Audit deployed Firebase Functions before removing them.
- `api/*` files are not deployed by the GitHub Pages workflow, which publishes the static `dist` directory only.

## Production database inventory — read-only audit, 2026-11-20

- 45 tables, 144 functions (131 SECURITY DEFINER), 37 triggers, 97 indexes and 167 constraints in `nexora`.
- 8 active pg_cron jobs.
- 74 applied migration records in Supabase.
- The base `main` tree had 70 tracked migration files. The current stacked branch has 73, including the restored production hotfix and two new hardening migrations that are not yet applied in production.
- The production hotfix `20261120132839` has now been restored verbatim from `supabase_migrations.schema_migrations.statements` into `supabase/migrations/`.
- `supabase/ci/production_migration_manifest.json` maps all 74 production ledger records to source paths and Git blob hashes. 21 records use recovered-history sources, and 21 records have additional historical variants with differing blob hashes.
- 20 local migration files are not mapped by name to the current production ledger. They are classified as unmapped—not assumed to be pending or unapplied.

## Snapshot and test status

- `supabase/ci/nexora_schema_snapshot.sql` currently contains 34 table definitions and 78 function definitions. It is a historical baseline, not a complete snapshot of current production.
- A new pgTAP schema-count parity test checks the isolated result against 45 tables, 144 functions, 37 triggers, 97 indexes and 167 constraints.
- Both database workflows now include the five latest production economy migrations, the restored hotfix and the new hardening migrations in chronological order.
- A manifest validator checks that every mapped production source and historical variant still exists with the recorded Git blob hash.
- The snapshot itself still requires a verified schema-only refresh; do not call it current until the parity test passes against the full canonical replay.
- Do not run `supabase db push`, migration repair, or production DDL to paper over drift.

## Current hardening batches

### PR #125 — treasury and auction hardening
- Disable organization treasury withdrawals at the UI, Edge API and database RPC layers.
- Refund a reserved company/factory auction escrow before cancelling an auction whose underlying asset is missing.
- Add pgTAP regression coverage and production schema-count parity coverage.
- Include the five latest production migrations in isolated database workflows.

### PR #126 — unified account deletion
- Replace the non-deployed Firestore/Vercel account-delete endpoint with an authenticated `nexora-api` action.
- Add one transactional Supabase cleanup RPC, preserving and pseudonymizing financial/audit/moderation history.
- Archive solo-leader organizations, companies and factories; block unsafe deletion while other members need leadership transfer or the player has a live winning bid.
- Delete Firebase Auth identity after the database cleanup; the database operation is idempotent to allow safe retries.
- Remove the obsolete `api/account-delete.ts` endpoint.

Both PRs are work in progress and are not production changes until review, successful CI, merge and deployment.

## Remaining requested work

1. Finish and verify the schema snapshot refresh against the live production catalog in an isolated environment.
2. Add idempotency keys to all retryable financial and commerce operations.
3. Retire obsolete Firestore/Vercel API paths only after diagnostics and retention requirements are migrated and deployed Firebase Functions are inventoried.
4. Add pagination for market listings and activity history, plus short private caching for safe public reads.
5. Consolidate notifications into one event center with stable event keys, deduplication and hierarchical badges.
6. Standardize on one package manager/lockfile and add Dependabot or an equivalent dependency update process.
7. Expand end-to-end coverage for transfers, auctions, organization roles, manufacturing, cancellation and account deletion.

Feedback/suggestions delivery and the moderator/admin console are intentionally deferred until the game is feature-complete and launch preparation begins.

## Safety constraints

- Never delete, reset, or overwrite real player wallets, inventory, ownership or financial history as part of testing.
- Never modify main directly.
- Keep each implementation batch isolated on its own branch/PR and verify CI before merging.
- Do not deploy schema changes directly to production while migration history and snapshot parity remain unresolved.
- Do not claim a change is live until GitHub Pages and the published version manifest confirm it.
