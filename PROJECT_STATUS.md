# NOVA — Project Status

**Updated:** 2026-11-19  
**Repository:** https://github.com/powerx911/NOVA  
**Production URL:** https://powerx911.github.io/NOVA/  
**Production branch:** `main`  
**Current work branch:** `fix/nova-urgent-economy-quality`

## Canonical project identity

NOVA is the player-facing game and brand name. The current database schema remains `nexora`, and the deployed Supabase Edge Function remains `nexora-api`; these are legacy internal identifiers retained for compatibility. Do not rename the schema or function by bulk replacement. A future rename requires a dedicated migration plan, compatibility window, and coordinated updates to all RPCs and server queries.

## Live architecture

- Frontend: React, TypeScript and Vite, published through GitHub Pages and GitHub Actions.
- Game data and economy: Supabase project `hmrprnjhyzyefocdmnxf`, schema `nexora`.
- API boundary: Supabase Edge Function `nexora-api`; it verifies Firebase ID tokens and uses the service-role key server-side only.
- Identity: Firebase Authentication. Game state/economy use Supabase; Firestore remains only for the owner-only legacy diagnostics screen and is not the gameplay data store.
- Database snapshot: 34 tables in `nexora`, all with RLS enabled; no direct table grants to `anon` or `authenticated` were found in the latest read-only audit.

## Latest verified production deployment

- Main commit: `c4f6495dda08eec6bdd42d88907d38365696a3a7`.
- GitHub CI: successful.
- GitHub Pages workflow: successful.
- Production URL: https://powerx911.github.io/NOVA/

## Current work

The current feature branch is isolated from `main`. The active improvement batch covers:
- Company revenue collection button contrast and press/focus behavior.
- Market pulse resource-name wrapping.
- Continuous supply-based market pricing and regression tests.
- Playwright onboarding → market purchase → company founding smoke coverage.
- pgTAP tests for non-negative wallets, ledger reconciliation, and factory pause charging.
- Accurate Supabase/database documentation.

The inventory screen already renders the shared `ResourceIcon` for each resource card. Keep that shared mapping in use rather than introducing a second icon system.

## Verified economic state

- The live wallet table currently has no negative balances.
- The current ledger reconstruction matched all three existing wallet balances in the latest read-only check.
- The live `set_factory_active` function calls `sync_factory_production` before pausing an active factory. This ensures elapsed production and operating cost are accounted for before `is_active` becomes false. A pgTAP regression test is being added to guard this behavior.
- No production database writes were made during the latest audit.

## Migration safety blocker

The live Supabase migration history contains 42 applied records, while the repository currently contains 31 migration SQL files. Several filenames do not match the version recorded remotely, and some applied records have no corresponding local migration file. **Do not run `supabase db push` or migration repair until the full mapping is reconciled and tested on the isolated branch.** This is a release blocker, not a documentation-only issue.

## Test and release gates

1. TypeScript, unit tests, Deno checks and Vite builds must pass in GitHub Actions.
2. Database migrations and pgTAP tests must be validated on an isolated branch/local database before any production migration.
3. Playwright requires a dedicated, disposable test account and isolated application/database endpoint. It is intentionally skipped until the GitHub secrets `NOVA_E2E_BASE_URL`, `NOVA_E2E_EMAIL`, and `NOVA_E2E_PASSWORD` are configured.
4. Merge only after CI is green. Production is updated through the GitHub Pages workflow; never claim deployment before that workflow succeeds.

## Safety constraints

- Never delete, reset, or overwrite player accounts, profiles, wallets, inventory, company ownership, or financial history.
- Never modify the original NEXORA repository or its Supabase project.
- Do not deploy schema changes directly to production while migration history is inconsistent.
- Do not purchase domains or spend external credits without explicit approval.
- Army/combat systems remain out of scope until explicitly requested.
