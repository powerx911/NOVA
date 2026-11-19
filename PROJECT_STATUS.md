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

A read-only audit found 42 applied Supabase migration records versus 31 local SQL files: 21 names exist on both sides, 14 of those still have timestamp mismatches, 10 local names are not in the applied history, and 21 applied migrations have no local SQL source. PR #57 corrected the known `nova_skill_reset_and_factories` timestamp mismatch. The complete mapping is still unresolved. **Do not run `supabase db push` or migration repair.** The current Supabase branch listing returns the production project reference itself, so it is not treated as an isolated write-safe test database. Recover missing SQL, map every shared migration to its applied version, and verify a genuinely isolated branch before any database rollout.

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
