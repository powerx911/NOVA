# NOVA Technical Architecture

**Last verified:** 2026-11-20  
**Repository:** https://github.com/powerx911/NOVA  
**Production URL:** https://powerx911.github.io/NOVA/

## 1. Canonical production stack

- **Frontend:** React 19, TypeScript, Vite 8 and Tailwind CSS v4. The static build is published to GitHub Pages by GitHub Actions.
- **Identity:** Firebase Authentication. The browser obtains a Firebase ID token; it does not receive database service credentials.
- **Game database:** Supabase PostgreSQL project `hmrprnjhyzyefocdmnxf`, private schema `nexora`.
- **Game API:** Supabase Edge Function `nexora-api`. It validates Firebase ID tokens (issuer, audience, RS256 signature and verified-email policy) and uses a server-side service-role client for database operations.
- **Legacy Firestore:** Not the authoritative game economy or player-state database. Firebase/Firestore Cloud Functions and API files still exist in the repository and must be inventoried before retirement; the owner diagnostics workflow is the remaining documented legacy use.
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
- Transaction rows and selected audit/history tables are immutable. Account deletion must preserve financial/legal history while removing or pseudonymizing personal game data through a narrowly scoped server-side operation.
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

## 6. Migration and snapshot status

The production migration ledger currently contains 74 applied records. The repository contains 70 tracked migration files, and the audit identified one applied production hotfix whose exact SQL is retained in the production migration ledger but has no matching canonical file in the repository. There are also historical/recovered copies with differing Git blob hashes; they must remain explicitly classified rather than silently treated as identical.

The checked-in CI baseline currently contains 34 table definitions and 78 function definitions. It is therefore a historical baseline, not a complete export of the current 45-table / 144-function production schema. CI applies an explicit migration subset on top of that baseline. The migration list must stay synchronized with the latest production migrations, and the baseline must be regenerated from an isolated, verified schema export before it can be called a current production snapshot.

Never run `supabase db push`, migration repair, or a production migration merely to make local history match. Validate migration order, SQL sources, schema state and tests in a disposable PostgreSQL environment first.

## 7. Legacy retirement policy

- Do not delete Firebase/Firestore diagnostics or old API code until the owner-only diagnostics capability and any required retention records have a verified replacement.
- Do not treat `api/*` as live Pages endpoints.
- Keep the deployed `nexora-api` name and schema `nexora` until a dedicated compatibility migration is approved.
- Remove old Cloud Functions only after checking the deployed Firebase function list and confirming no production client invokes them.

## 8. Release gates

1. TypeScript, unit tests, SQL grammar validation and production build pass.
2. pgTAP tests run against a disposable PostgreSQL instance with the current snapshot baseline and selected migrations.
3. Account deletion, auctions, wallet transfers and organization operations have isolated integration coverage.
4. CI is green before merge.
5. The GitHub Pages deployment workflow succeeds and the published version manifest matches the merged commit.
6. Production database migrations are not considered deployed until an explicitly isolated rollout path and migration-history reconciliation have been verified.
