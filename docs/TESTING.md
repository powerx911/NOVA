# NOVA quality checks

## Local unit and build checks

```sh
npm install
npm test
npm run build
```

## Playwright smoke test

The smoke test in `e2e/nova-smoke.spec.mjs` covers:

1. Email sign-in using a verified, dedicated test account
2. Character creation when the account has no character yet
3. Buying a market listing
4. Founding a company

Use a disposable Firebase Authentication account and an isolated NOVA test backend. The test account must have sufficient starting credits and the isolated market must contain at least one affordable listing owned by another account.

Set these environment variables:

- `NOVA_E2E_BASE_URL`: URL of the isolated NOVA test deployment
- `NOVA_E2E_EMAIL`: verified test-account email
- `NOVA_E2E_PASSWORD`: test-account password

Run:

```sh
npx playwright install chromium
npm run test:e2e
```

The GitHub Actions E2E job skips with a notice when these secrets are absent. Never point the test at production; the test creates a player and company and purchases a listing.

## Database invariant tests

The pgTAP suite is `supabase/tests/database/economy_invariants.test.sql`. It checks:

- Wallet balances never become negative
- Wallet balances reconcile against the transaction ledger
- Pausing a factory settles elapsed operating costs exactly once

Run it only against a genuinely isolated Supabase branch or a local Supabase database:

```sh
supabase test db
```

The current Supabase branch lookup has returned the production project reference rather than a distinct branch reference. Do not run the suite against that endpoint until isolation is confirmed.

## Migration safety

The production migration history is not yet reconciled with the repository. Do not run `supabase db push` or `migration repair` until the documented local/remote migration mapping has been resolved.

## CI workflow

Pull requests targeting `main` run the validation workflow. Feature branches match the `feature/**` push filter, and fix branches match `fix/**`, so validation can run before merge. A zero-job run is not a successful validation; confirm that the `validate` job actually starts and completes. The Playwright job is intentionally gated: without all three isolated-test secrets above, it reports a notice and skips browser mutations rather than touching production.

Maintenance branches use the same full validation job as feature branches; the test must execute on the exact commit tree before merging.
