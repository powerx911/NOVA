# NOVA Technical Architecture

**Last verified:** 2026-11-20  
**Repository:** https://github.com/powerx911/NOVA  
**Production URL:** https://powerx911.github.io/NOVA/

## 1. Canonical production stack

- **Frontend:** React 19, TypeScript, Vite and Tailwind CSS. The player-facing app is a static build published to GitHub Pages by GitHub Actions.
- **Identity:** Firebase Authentication. The browser obtains a Firebase ID token; it never receives database service credentials.
- **Game database:** Supabase PostgreSQL project hmrprnjhyzyefocdmnxf, private schema nexora.
- **Game API:** Supabase Edge Function nexora-api, active version 45. It verifies Firebase ID tokens and uses a server-side service-role client.
- **Legacy Firestore/Cloud Functions:** Retained for owner diagnostics, world-event rotation and legacy Firestore company-vault operations. The source exports upgradeCompanyProfitVault, collectCompanyRevenueSecure, nexoraDiagnostics and rotateWorldEvents; their deployed inventory and live callers have not yet been verified.
- **Legacy api/* sources:** Still exist in the repository. GitHub Pages publishes only dist; the owner-only diagnostics service currently calls /api/company-vault for a health check; the current Vercel deployment status is not verified. Do not remove these sources until deployed routes and client callers are inventoried.

## 2. Production database inventory

Read-only catalog verification on 2026-11-20:

| Object | Count |
|---|---:|
| Tables in nexora | 46 |
| Functions | 151 |
| SECURITY DEFINER functions | 138 |
| Triggers | 40 |
| Indexes | 102 |
| Constraints | 169 |
| Active pg_cron jobs | 8 |
| Applied Supabase migration records | 83 |
| RLS-enabled tables | 46 |
| RLS-disabled tables | 0 |

The checked-in production schema snapshot is refreshed against the live inventory and migration-sensitive functions; isolated CI verifies catalog counts and selected critical invariants. The historical snapshot remains a separate starting point for migration replay.

## 3. Request and trust boundaries

1. Firebase Authentication establishes the player identity.
2. The client calls /functions/v1/nexora-api with the Firebase ID token and Supabase publishable key.
3. supabase/functions/nexora-api/_shared/auth.ts verifies the Firebase token signature, issuer and audience. The function derives the UID from the verified token.
4. nexora-api calls trusted nexora RPCs and reads through a server-side Supabase client.
5. Non-anonymous account deletion is rejected unless the signed Firebase auth_time is within five minutes. This is enforced server-side before database cleanup.
6. Wallet, inventory, company, factory, organization, auction, contract and manufacturing invariants belong in PostgreSQL transactions and server-side functions.

## 4. Important database invariants

- Wallet changes and transaction-ledger records commit atomically.
- Transfer, market-purchase and treasury-deposit retries reuse an idempotency key. The database returns the stored result for a repeated key/payload and rejects a key reused with different input.
- Organization treasury funding is one-way. Withdrawals are disabled at the UI, API and database layers.
- Auction bids reserve funds in escrow; settlement must release or refund them. Missing assets must not strand reserved bidder funds.
- Manufacturing jobs are protected by RLS with no direct-access policies. The browser uses the existing SECURITY DEFINER RPC boundary.
- Manufacturing recipe inputs, cost, XP and cancellation refunds are server-authoritative.
- Company revenue collection grants the minimum reward policy, applies leadership scaling and caps per-collection XP.
- Factory progression uses distinct curves by resource. Periodic production and operating-cost synchronization is centralized by server cron, not repeated per-factory client bootstrap calls.
- Immutable financial/audit history is retained and pseudonymized during account deletion.

## 5. Repository and CI layout

- src/: Player-facing React application.
- supabase/functions/nexora-api/: Authenticated gameplay API.
- supabase/migrations/: Canonical local SQL migration sources.
- supabase/recovered-history/: Forensic/recovery SQL; not an automatic replacement for a tracked migration with a different checksum.
- supabase/tests/database/: pgTAP database regression tests.
- supabase/ci/nexora_schema_snapshot.sql: Historical baseline for replaying the curated migration chain.
- supabase/ci/nexora_production_schema_snapshot.sql: Current data-free production snapshot used by the strict catalog verifier.
- supabase/ci/production_migration_manifest.json: Source map for the 83 applied production migration records.
- Root dependencies use Bun and the root bun.lock; Firebase Functions are a separate Node package with their own functions/package-lock.json.

## 6. Migration and release safety

The production migration ledger has 83 applied records. The repository has 80 tracked migration files; 18 local files remain unmapped by name. The manifest records the source path and Git blob hash for each applied ledger record. Unmapped local files are not assumed to be pending or unapplied.

CI runs:
1. TypeScript, lint/rules, unit tests and builds.
2. PostgreSQL + pgTAP on a disposable database.
3. Historical SQL replay in a separate disposable database.
4. Production snapshot inventory and critical function assertions.

The Playwright job verifies test discovery. Browser mutations run only when all three isolated test secrets are present; currently the browser mutation step is skipped because those secrets are not configured. Never run mutation tests against production.

Do not run supabase db push or migration repair to force local history into alignment. Production migration application requires disposable replay, pgTAP, snapshot parity and explicit review.

## 7. Main branch protection

The main branch is protected with:

- One approving pull-request review; stale approvals are dismissed after new commits.
- Three required GitHub Actions checks: Typecheck, rules, tests and builds; Replay tracked and untracked SQL on disposable PostgreSQL; and PostgreSQL 17 + pgTAP (isolated).
- Strict up-to-date checks, admin enforcement and required conversation resolution.
- Force-push and branch deletion disabled.

## 8. Legacy retirement policy

- Do not delete Firebase/Firestore diagnostics or old API code until the owner-only diagnostics capability and any retention requirements have a verified replacement.
- Do not treat api/* as GitHub Pages endpoints. Confirm whether any Vercel project is connected and whether those routes receive production traffic before removing them.
- Inventory deployed Firebase Functions and verify client callers before removing old Cloud Functions.
- Keep the deployed nexora-api name and schema nexora until a dedicated compatibility migration is approved.
