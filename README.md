# NOVA

NOVA is a mobile-first online economic and corporate strategy game. The player-facing brand and product name is **NOVA**.

## Production architecture

- Frontend: React 19, TypeScript, Vite and Tailwind CSS v4.
- Hosting: GitHub Pages at https://powerx911.github.io/NOVA/, deployed by GitHub Actions from `main`.
- Game database: Supabase project `hmrprnjhyzyefocdmnxf`, application schema `nexora`.
- Trusted game API: Supabase Edge Function `nexora-api`.
- Identity: Firebase Authentication. The browser sends its Firebase ID token to the Edge Function; the service-role credential stays server-side.
- Authoritative game state, wallets, transactions, inventory, market, companies, factories and organizations are stored in Supabase/Postgres.

The schema name `nexora` and Edge Function name `nexora-api` are legacy internal identifiers retained for compatibility. Do not rename them by bulk replacement; use a coordinated compatibility migration.

## Legacy Firebase diagnostics

Firestore is **not** the gameplay database. A small owner-only diagnostics screen still reads a legacy Firestore diagnostics surface and Firebase Cloud Functions. Its rules/configuration are intentionally retained until that diagnostics path is migrated to Supabase. The obsolete `firebase-blueprint.json` and one-time Firestore export workflow/script have been removed from this repository.

## Main systems

- Arabic-first RTL interface with English LTR switching.
- Shared player world, profile progression and skill tree.
- Wallets and transaction ledger with server-authoritative operations.
- Player market, supply/demand reference prices, contracts and manufacturing.
- Companies, profit vaults, factories, warehouses and auctions.
- Organizations, permissions, shared treasury, chat and notifications.
- Version-update notice and mobile-first navigation.

## Development

```bash
npm install
npm run dev
npm test
npm run build
```

Playwright end-to-end smoke test:

```bash
npm run test:e2e
```

The E2E test requires `NOVA_E2E_BASE_URL`, `NOVA_E2E_EMAIL` and `NOVA_E2E_PASSWORD` to point to a dedicated isolated test environment and disposable test account. Do not point it at a real player's account.

## Database safety

Read [docs/DATABASE.md](docs/DATABASE.md) before changing database code. The live migration history and local migration filenames are currently inconsistent; **do not run `supabase db push` or migration repair** until the complete mapping has been reconciled and tested on an isolated branch.

## Release process

1. Work on a feature branch.
2. Pass GitHub Actions CI.
3. Validate SQL/pgTAP changes on an isolated Supabase branch.
4. Merge to `main` only after checks pass.
5. Confirm the GitHub Pages workflow succeeds before describing a change as deployed.
