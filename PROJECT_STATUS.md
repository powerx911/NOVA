# NOVA — Project Status

**Updated:** 2026-11-20 20:42 UTC  
**Repository:** https://github.com/powerx911/NOVA  
**Production URL:** https://powerx911.github.io/NOVA/  
**Production branch:** main  
**Latest merged commit:** 83933e0011126d65b9e53a8bd24a9130179211fa  
**Supabase Edge Function:** nexora-api, active version 45

## Canonical project identity

NOVA is the player-facing game and brand name. The current database schema remains nexora, and the deployed Supabase Edge Function remains nexora-api; these are legacy internal identifiers retained for compatibility. Do not rename either by bulk replacement.

## Live architecture

- Frontend: React, TypeScript and Vite, published as a static build through GitHub Pages and GitHub Actions.
- Identity: Firebase Authentication.
- Game data/economy: Supabase PostgreSQL project hmrprnjhyzyefocdmnxf, schema nexora.
- API boundary: Supabase Edge Function nexora-api; it verifies Firebase ID tokens and uses a server-side service-role client.
- Firestore/Cloud Functions: legacy diagnostics and older server code remain in the repository. They are not the authoritative game economy. Inventory deployed functions and callers before retiring them.
- api/*: legacy serverless endpoint sources remain in the repository. GitHub Pages publishes only the static dist directory; the current Vercel deployment status is not verified.

## Production database inventory — read-only catalog verification, 2026-11-20

| Object | Live count |
|---|---:|
| Tables in nexora | 46 |
| Functions | 151 |
| SECURITY DEFINER functions | 138 |
| Triggers | 40 |
| Indexes | 102 |
| Constraints | 169 |
| Active pg_cron jobs | 8 |
| Applied Supabase migration records | 83 |
| Tables with RLS enabled | 46 |
| Tables with RLS disabled | 0 |

The production migration manifest maps all 83 applied ledger records to source paths and Git blob hashes. The repository currently has 80 tracked migration files; 18 local migration files are unmapped by name to the applied ledger. Those files are classified as unmapped, not assumed to be pending or unapplied. Twenty-one ledger records use recovered-history sources, and 21 have additional historical variants.

## Current production hardening

### Economy and financial safety

- Organization treasury withdrawals are disabled in the UI, Edge API and database RPC. Deposits remain one-way.
- Transfer, market purchase and treasury deposit actions use request IDs and server-side idempotency receipts. The client reuses a pending key across retries.
- Company revenue collection grants at least 10 XP, 2 reputation and 1 influence, applies leadership scaling to reputation/influence, and caps collection XP at 80.
- Factory progression uses resource-specific curves rather than one shared curve.
- Auction settlement refunds reserved escrow before cancelling an auction whose underlying asset is missing.

### Manufacturing and access control

- The canonical biotechnology recipe is restored; the hidden quantum-server recipe remains unavailable.
- manufacturing_jobs has RLS enabled with no direct-access policies or direct read grants. Manufacturing remains behind the existing SECURITY DEFINER RPC boundary.
- company_auctions.company_id and factory_id have supporting partial indexes.
- Factory production is synchronized centrally by the server cron; the client no longer launches a full bootstrap sync per factory.

### Account deletion

- Account deletion uses the authenticated nexora-api action and one transactional Supabase cleanup RPC.
- Financial/audit history is retained and narrowly pseudonymized; gameplay/private state is removed, and unsafe auction/leadership states are rejected.
- The Edge Function enforces a fresh Firebase auth_time (five-minute window) for non-anonymous accounts before any database cleanup. Firebase Auth deletion follows the database transaction; retries are safe.
- nexora-api version 45 is active and was checked after deployment.

## CI, snapshots and branch protection

- The historical supabase/ci/nexora_schema_snapshot.sql remains the starting baseline for replaying the curated migration chain.
- supabase/ci/nexora_production_schema_snapshot.sql is the current data-free production snapshot. CI verifies its catalog counts and explicit treasury, recipe, reward, curve, RLS and auction-index invariants.
- supabase/ci/production_migration_manifest.json currently records 83 applied migration records and the 102-index production inventory.
- CI includes TypeScript/lint/unit/build checks, isolated PostgreSQL + pgTAP, and historical SQL replay in disposable databases.
- Playwright discovery is checked in CI. Browser mutations run only when all three isolated-environment secrets are configured; those secrets are currently absent, so the browser run reports a skip rather than touching production.
- Root dependencies use Bun with the single root lockfile bun.lock; Firebase Functions retain their separate functions/package-lock.json.
- main is protected: one approving review, three required successful CI contexts, strict up-to-date checks, admin enforcement, conversation resolution, and no force-push or deletion.

## Merged hardening PRs in this batch

- [PR #153](https://github.com/powerx911/NOVA/pull/153) — minimum company revenue rewards.
- [PR #155](https://github.com/powerx911/NOVA/pull/155) — Playwright discovery and isolated CI job.
- [PR #156](https://github.com/powerx911/NOVA/pull/156) — manufacturing RLS and auction foreign-key indexes.
- [PR #157](https://github.com/powerx911/NOVA/pull/157) — server-enforced recent authentication for account deletion.
- [PR #158](https://github.com/powerx911/NOVA/pull/158) — production snapshot and migration-manifest parity.

## Remaining work

1. Configure dedicated isolated E2E credentials and expand Playwright coverage for manufacturing, cancellation, transfers, auctions, organization roles and account deletion.
2. Inventory deployed Firebase Functions and any Vercel deployment/callers before removing legacy api/*, Firestore or Cloud Functions paths.
3. Expand functional pgTAP coverage for financial idempotency replays and account-deletion retry behavior.
4. Keep architecture/database documentation synchronized with production catalog changes.
5. Complete release-preparation work only after the game is feature-complete.

Feedback/suggestions delivery and the moderator/admin console remain intentionally deferred until the game is feature-complete and launch preparation begins.

## Safety constraints

- Never delete, reset, or overwrite real player wallets, inventory, ownership or financial history as part of testing.
- Never modify main directly; use a dedicated branch and PR.
- Run database tests only in disposable environments.
- Apply production migrations only after isolated replay, pgTAP and production snapshot parity pass.
- Do not claim a frontend change is live until the GitHub Pages deployment and published version manifest confirm it.
