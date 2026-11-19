# NOVA — Supabase project contract

**Verified:** 2026-11-19

## Current source of truth

- Product and brand: **NOVA**.
- GitHub repository: `powerx911/NOVA`.
- Production branch: `main`.
- Production URL: https://powerx911.github.io/NOVA/.
- Supabase project reference: `hmrprnjhyzyefocdmnxf`.
- Application schema: `nexora` (legacy internal name retained for compatibility).
- Server API: `nexora-api` (legacy function name retained for compatibility).

## Runtime boundary

- Supabase/Postgres is the authoritative store for gameplay state and all economic operations.
- The browser authenticates through Firebase Authentication and sends a signed Firebase ID token to the Supabase Edge Function.
- The Edge Function verifies the token, derives the player UID from the verified identity, and uses the service-role credential server-side only.
- Firestore is not the gameplay database. It remains in use only for a small owner-only legacy diagnostics screen and Firebase Functions diagnostics. Do not delete `firestore.rules`, `firebase.json` Firestore configuration, or the Firebase app config until that diagnostics path has been migrated.
- The unused `firebase-blueprint.json` and old one-time exporter workflow/script are not part of the active runtime and have been removed.

## Current schema and security

The production schema currently contains 34 tables, all with RLS enabled. The latest read-only audit found no direct table grants to `anon` or `authenticated`. The service-role key must never be placed in browser code, public environment variables, repository files, or chat.

Core tables include `player_profiles`, `player_private`, `wallets`, `transactions`, `inventory`, `market_listings`, `market_orders`, `companies`, `factories`, `organizations`, `world_events`, `notifications`, and social/community tables. See [DATABASE.md](DATABASE.md) for the complete current list and invariants.

## Compatibility rules

1. Keep application objects in the existing `nexora` schema until a dedicated rename migration is designed.
2. Fully qualify schema objects in SQL and Edge Function queries.
3. Keep RLS enabled on every application table.
4. Do not grant direct Data API access to `anon` or `authenticated` without a reviewed policy model.
5. Keep privileged wallet, inventory, market escrow, factory, company and organization mutations inside trusted server-side operations.
6. Do not modify Supabase-managed schemas or project-wide Auth, Storage, Realtime, API exposure or role settings as part of ordinary game work.
7. Never alter the original `luffyk124-del/nexora-game` repository or its Supabase project while working on NOVA.

## Migration release blocker

The live Supabase migration history contains 42 applied records while the repository currently has 31 migration SQL files. Several filenames do not match their recorded remote versions, and some remote records have no corresponding local file. Do not run `supabase db push`, `migration repair`, or production DDL until all records are reconciled and the exact sequence is tested on the isolated `nova-quality-check` branch.
