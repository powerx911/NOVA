# NOVA Technical Architecture

**Last verified:** 2026-11-20  
**Repository:** https://github.com/powerx911/NOVA  
**Production URL:** https://powerx911.github.io/NOVA/

## 1. Canonical production stack

- **Frontend:** React 19, TypeScript, Vite 8 and Tailwind CSS v4. The static build is published to GitHub Pages by GitHub Actions.
- **Identity:** Firebase Authentication. The browser obtains a Firebase ID token; it does not receive database service credentials.
- **Game database:** Supabase PostgreSQL project `hmrprnjhyzyefocdmnxf`, private schema `nexora`.
- **Game API:** Supabase Edge Function `nexora-api`. It validates Firebase ID tokens (issuer, audience, RS256 signature and verified-email policy) and uses a server-side service-role client for database operations.
- **Legacy Firestore:** Not the authoritative game economy or player-state database. The owner diagnostics workflow still uses Firestore/Cloud Functions; old economy functions also remain in source and must be inventoried before retirement.
- **Deployment:** GitHub Pages only for the player-facing static app. Files under `api/` are not deployed as serverless functions by the Pages workflow.

## 2. Production database inventory

The latest read-only inventory recorded on 2026-11-20:

| Object | Production count |
|---|---:|
| Tables in `nexora` | 45 |
| Functions in `nexora` | 144 |
| SECURITY DEFINER functions | 131 |
| Triggers | 37 |
| Indexes | 97 |
| Constraints | 167 |
| Active pg_cron jobs | 8 |
| Applied Supabase migration records | 74 |

These counts describe the live project at the audit timestamp. They are not a promise that a checked-in SQL snapshot already contains every object.

## 3. Request and trust boundaries

1. Firebase Authentication establishes the player identity.
2. The client calls `/functions/v1/nexora-api` with the Firebase ID token and Supabase publishable key.
3. `supabase/functions/nexora-api/_shared/auth.ts` verifies the Firebase token. The function derives the UID from the verified token; it does not trust a client-supplied UID for authorization.
4. The Edge Function calls `nexora` RPCs and reads through a server-side Supabase client.
5. Wallet, inventory, company, factory, organization, auction, contract and manufacturing invariants belong in PostgreSQL transactions and server-side functions—not in client-only checks.

## 4. Important database invariants

- Wallet changes and their transaction-ledger records must be committed atomically.
- Transaction rows and selected audit/history tables are immutable. Account deletion uses a narrowly scoped server-side deletion context to remove player state while retaining and pseudonymizing financial/legal history.
- Auction bids reserve funds in `company_auction_escrows`; settlement must either release the winning escrow or refund it. An auction must never be marked cancelled while leaving a bidder's reserved escrow stranded.
- Organization treasury funding is one-way. Treasury deposits may count toward reputation and organization goals; withdrawals are disabled so the treasury cannot be used as a player-to-player transfer intermediary.
- Notification events use stable event keys to avoid duplicate rewards and alerts.
- All SECURITY DEFINER functions must pin `search_path` and be callable only through intended server roles.

## 5. Repository and CI layout

- `src/`: Player-facing React application.
- `supabase/functions/nexora-api/`: Authenticated gameplay API.
- `supabase/migrations/`: Canonical local SQL migration sources.
- `supabase/recovered-history/`: Forensic/recovery SQL; not automatically a canonical replacement for a tracked migration with a different checksum.
- `supabase/tests/database/`: pgTAP database regression tests.
- `supabase/ci/nexora_schema_snapshot.sql`: Data-free PostgreSQL baseline used by isolated CI tests.
- `supabase/ci/production_migration_manifest.json`: Source map for the 74 applied production migration records, including Git blob hashes and recovered variants.

## 6. Migration and snapshot status

The production migration ledger contains 74 applied records. The base `main` tree had 70 tracked migration files; the current hardening branch has 73, including the restored production hotfix and two new migrations that are not yet applied in production.

The hotfix at version `20261120132839` was recovered from the read-only `supabase_migrations.schema_migrations.statements` record and restored as `supabase/migrations/20261120132839_nova_production_company_parity_hotfix_20261120.sql`. The manifest maps all 74 production ledger records to source paths. 21 records use recovered-history sources; 21 also have historical variants with different Git blob hashes. Twenty local migration files are not mapped by name to the current ledger; this is not proof that they are unapplied.

Two separate data-free baselines now serve different purposes. `supabase/ci/nexora_schema_snapshot.sql` is the historical starting point for replaying the curated migration chain and running gameplay regression tests. `supabase/ci/nexora_production_schema_snapshot.sql` was exported read-only from production on 2026-11-20 and contains 45 tables, 144 functions (131 SECURITY DEFINER), 37 triggers, 97 indexes and 167 constraints, with 44 tables RLS-enabled and one not enabled. After gameplay tests, CI resets only the disposable `nexora` schema, restores the production snapshot and runs a strict catalog verifier. Historical replay is a separate disposable-database workflow.

Never run `supabase db push`, migration repair, or a production migration merely to make local history match. Validate migration order, SQL sources, schema state and tests in a disposable PostgreSQL environment first.

## 7. Legacy retirement policy

- Do not delete Firebase/Firestore diagnostics or old API code until the owner-only diagnostics capability and any required retention records have a verified replacement.
- Do not treat `api/*` as live Pages endpoints.
- Keep the deployed `nexora-api` name and schema `nexora` until a dedicated compatibility migration is approved.
- Remove old Cloud Functions only after checking the deployed Firebase function list and confirming no production client invokes them.

## 8. Release gates

1. TypeScript, unit tests, SQL grammar validation and production build pass.
2. The production migration source manifest validates against the checked-out Git tree.
3. pgTAP tests run against a disposable PostgreSQL instance with the current snapshot baseline and canonical migration subset.
4. Account deletion, auctions, wallet transfers and organization operations have isolated integration coverage.
5. CI is green before merge.
6. The GitHub Pages deployment workflow succeeds and the published version manifest matches the merged commit.
7. Production database migrations are not considered deployed until an explicitly isolated rollout path and migration-history reconciliation have been verified.
