# NOVA

**NOVA** is a portrait-first (Mobile-First) economic, corporate management, and social strategy simulation browser game built with **React 19**, **TypeScript**, **Tailwind CSS v4**, **Firebase Authentication** for identity, and **Supabase Postgres + Edge Functions** for live game data and trusted operations.

Default UI language is **Arabic (`RTL`)** with instant switching to **English (`LTR`)**.

> **NOVA database isolation:** NOVA's new database target is the dedicated Supabase project `NOVA` (`hmrprnjhyzyefocdmnxf`) and its isolated `nexora` schema. The old NOVA game tables and their `nova_*` functions have been removed after verifying that the legacy tables contained zero rows. The new schema is provisioned with RLS enabled and no direct `anon`/`authenticated` table access. The live game client still uses the original Firebase Auth/Firestore runtime until the Supabase game API and identity boundary are completed; do not deploy this source snapshot as a live game yet. Read [docs/SUPABASE_SHARED_PROJECT.md](docs/SUPABASE_SHARED_PROJECT.md) before database or Auth changes.

---

## Core Systems Implemented
- **Authentication & Onboarding**: Google Sign-In through the current Firebase Auth implementation, verified-email enforcement, unique username reservation, avatar selection, and `2,500 $` starting capital.
- **Ambient Soundtrack & UI Audio**: Original adaptive synth ambience and per-control synthesized feedback using one shared Web Audio context; no MP3/WAV files, and audio unlock is tied to the first trusted user gesture.
- **Tactile Interaction**: Responsive pressed states, keyboard-visible focus, and reduced-motion-aware transitions.
- **5-Tab Mobile-First Portrait Shell**: Home, Business, Market, Organization, and Profile, with sticky header and notifications.
- **Character & Skill Tree**: Level/XP progression and six functionally bound skills.
- **Interconnected Economy**: Atomic `$` wallets, append-only ledger, player transfers, market listings/orders, dynamic pricing, tax rates, and world events.
- **Manufacturing Chains**: Three-tier industrial chains and daily trade contracts.
- **Companies & Real Estate**: Five business sectors, staffing, upgrades, independent profit vaults, properties, leases, and hourly revenue. Vault upgrades and collection are handled by the authenticated Supabase Edge API and atomic Postgres RPCs in the NOVA `nexora` schema.
- **Organizations & RBAC**: Organization membership, role permissions, join requests, and shared treasury.
- **NOVA Diagnostics**: Owner-restricted, read-only diagnostics with sanitization and JSON export.

## Current Runtime — Supabase gameplay backend

- Firebase Auth remains the identity provider during this staged cutover. The browser sends its Firebase ID token to the NOVA Edge Function; the function validates the token and derives the UID server-side.
- Supabase project `NOVA` (`hmrprnjhyzyefocdmnxf`), schema `nexora`, is the live source of truth for core gameplay data.
- All core gameplay reads are loaded through the authenticated `bootstrap` Edge Function. Mutations for wallets, market, manufacturing, companies, properties, organizations, missions, achievements, notifications and leaderboards run through trusted Edge Function handlers and server-side Postgres RPCs.
- `service_role` is only used inside the Edge Function. It is never included in the browser bundle. Direct table access for `anon` and `authenticated` remains closed; RLS stays enabled.
- The legacy owner diagnostics screen still contains Firestore/Vercel-only health probes. Those probes are not part of gameplay or economy operations and must be migrated or disabled before claiming that all Firebase/Vercel dependencies are removed.
- No Firestore player data has been imported. Existing accounts remain authenticated by the original Firebase Auth project; a separate identity migration is not part of this staged gameplay cutover.

## Supabase Target — NOVA isolated namespace

- **Project**: `NOVA` (`hmrprnjhyzyefocdmnxf`, `eu-west-1`).
- **NOVA schema**: `nexora`; 23 tables with RLS enabled.
- **Security**: no direct `anon` or `authenticated` table grants. The trusted Edge Function validates Firebase identity and invokes the database with service privileges.
- **Legacy cleanup**: the 17 old `public.nova_*` game tables and old `nova_*` functions were removed only after verifying the legacy game tables were empty. Supabase Auth and platform-managed schemas were not modified.
- **Runtime status**: core gameplay uses Supabase. The GitHub Pages workflow is configured with base path `/NOVA/` and deploys automatically on pushes to `main`. The latest build and deployment completed successfully; an interactive sign-in smoke test has not yet been performed.

## Documentation
- `PROJECT_STATUS.md` — Living project status and verification record.
- `docs/ARCHITECTURE.md` — Technical architecture and atomic workflows.
- `docs/DATABASE.md` — Current Firestore collections and security invariants.
- `docs/SUPABASE_SHARED_PROJECT.md` — Mandatory isolation contract.
- `docs/SUPABASE_SCHEMA_V1.md` — Supabase baseline tables and security state.
- `docs/DIAGNOSTICS.md` — Diagnostics security model.
- `CHANGELOG.md` — Version history.

## Scripts
- `npm run dev` — Start Vite development server on port `3000`.
- `npm run build` — Production build.
- `npm run lint` — TypeScript type checking.
- `npm run lint:rules` — Validate Firestore security rules.
- `npm run test` — Run Vitest suite.
