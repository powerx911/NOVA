# NOVA quality checks

## Root dependencies and local checks

The root app uses Bun and the committed root lockfile bun.lock. The Firebase Functions package is separate and uses functions/package-lock.json.

~~~sh
bun install --frozen-lockfile
bun run test
bun run test:contract-economy
bun run build
~~~

## Playwright smoke test

The smoke test in e2e/nova-smoke.spec.mjs currently covers:

1. Email sign-in with a verified dedicated test account
2. Character creation when the account has no character
3. Buying a market listing
4. Founding a company

Use a disposable Firebase Authentication account and an isolated NOVA test backend. The test creates a player and company and purchases a listing; never point it at production.

Required environment variables:

- NOVA_E2E_BASE_URL: URL of the isolated NOVA test deployment
- NOVA_E2E_EMAIL: verified test-account email
- NOVA_E2E_PASSWORD: test-account password

Run:

~~~sh
bunx playwright install chromium
bun run test:e2e
~~~

CI always runs Playwright test discovery with npx playwright test --list. It runs browser mutations only when all three isolated-environment secrets are configured. Those secrets are currently absent, so the browser mutation step is intentionally skipped with a notice. Do not add production credentials or use production as the E2E target.

The next E2E expansion should cover manufacturing and cancellation, transfers, auctions, organization roles and account deletion.

## Database invariant tests

pgTAP suites live under supabase/tests/database. The CI workflow starts disposable PostgreSQL, restores the historical schema baseline, applies the curated migrations, runs the suites and verifies the current production snapshot separately.

Key suites include:

- financial_idempotency.test.sql
- biotech_recipe_integrity.test.sql
- company_revenue_minimum_rewards.test.sql
- manufacturing_rls_auction_fk_indexes.test.sql
- unified_account_deletion.test.sql
- factory_resource_progression.test.sql

Run database tests only against local/disposable PostgreSQL or a confirmed isolated Supabase branch. A branch reference equal to the production project reference is not isolated. Never run destructive account deletion, wallet, auction or purchase tests against real players.

## CI workflows

Pull requests targeting main require all three contexts:

- Typecheck, rules, tests and builds
- Replay tracked and untracked SQL on disposable PostgreSQL
- PostgreSQL 17 + pgTAP (isolated)

The separate Playwright job checks discovery and conditionally executes browser tests when the isolated secrets are configured. A skipped browser mutation step is not evidence that the browser flow itself passed.

## Migration safety

The production ledger contains 83 applied records and the checked-in manifest maps each record to a source path and Git blob hash. The historical snapshot and current production snapshot serve different purposes; do not replace the replay baseline with the production snapshot.

Do not run supabase db push or migration repair to paper over history drift. Preserve migration timestamps and source hashes, and require disposable replay, pgTAP and production snapshot parity before applying production changes.
