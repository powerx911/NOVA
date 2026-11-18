# NEXORA

**NEXORA** is a portrait-first (Mobile-First) economic, corporate management, and social strategy simulation browser game built with **React 19**, **TypeScript**, **Tailwind CSS v4**, **Firebase Authentication**, and **Cloud Firestore**. The NOVA Supabase schema is provisioned; the live gameplay client is still on Firebase pending the secure API cutover.

Default UI language is **Arabic (`RTL`)** with instant switching to **English (`LTR`)**.

> **NOVA database isolation:** NEXORA's new database target is the dedicated Supabase project `NOVA` (`hmrprnjhyzyefocdmnxf`) and its isolated `nexora` schema. The old NOVA game tables and their `nova_*` functions have been removed after verifying that the legacy tables contained zero rows. The new schema is provisioned with RLS enabled and no direct `anon`/`authenticated` table access. The live game client still uses the original Firebase Auth/Firestore runtime until the Supabase game API and identity boundary are completed; do not deploy this source snapshot as a live game yet. Read [docs/SUPABASE_SHARED_PROJECT.md](docs/SUPABASE_SHARED_PROJECT.md) before database or Auth changes.

---

## Core Systems Implemented
- **Authentication & Onboarding**: Google Sign-In through the current Firebase Auth implementation, verified-email enforcement, unique username reservation, avatar selection, and `2,500 $` starting capital.
- **Ambient Soundtrack & UI Audio**: Original adaptive synth ambience and per-control synthesized feedback using one shared Web Audio context; no MP3/WAV files, and audio unlock is tied to the first trusted user gesture.
- **Tactile Interaction**: Responsive pressed states, keyboard-visible focus, and reduced-motion-aware transitions.
- **5-Tab Mobile-First Portrait Shell**: Home, Business, Market, Organization, and Profile, with sticky header and notifications.
- **Character & Skill Tree**: Level/XP progression and six functionally bound skills.
- **Interconnected Economy**: Atomic `$` wallets, append-only ledger, player transfers, market listings/orders, dynamic pricing, tax rates, and world events.
- **Manufacturing Chains**: Three-tier industrial chains and daily trade contracts.
- **Companies & Real Estate**: Five business sectors, staffing, upgrades, independent profit vaults, properties, leases, and hourly revenue. Vault upgrades and collection are handled by authenticated Vercel API routes using Google Workload Identity Federation; live deployment and transaction testing are pending.
- **Organizations & RBAC**: Organization membership, role permissions, join requests, and shared treasury.
- **NEXORA Diagnostics**: Owner-restricted, read-only diagnostics with sanitization and JSON export.

## Current Runtime — Firebase (Active Source of Truth)
- Firebase Auth (Google provider) is still the active login.
- Cloud Firestore remains the source of truth for live game data.
- Firebase Cloud Functions Gen 2 remain the read-only diagnostics backend.
- Company profit-vault operations are now routed through a Vercel server-side API. The API verifies Firebase ID tokens, obtains short-lived Google credentials through Vercel OIDC/WIF, and uses Firestore REST transactions against the named database. Build and live transaction verification are pending.
- Do not remove Firebase or switch live writes until Supabase auth strategy, trusted server operations, RLS, migration, parity tests, and rollback are complete.

## Supabase Target — NOVA isolated namespace
- **Project**: `NOVA` (`hmrprnjhyzyefocdmnxf`, `eu-west-1`).
- **NEXORA schema**: `nexora`; provisioned on 2026-11-18 with 23 tables (22 domain tables plus username reservations).
- **Security**: RLS enabled on all 23 tables; no `anon` or `authenticated` table access; `service_role` reserved for trusted server operations. No player data has been imported.
- **Fail-closed state**: no browser policies or grants have been added. The `rls_enabled_no_policy` INFO notices are expected until the trusted game API and authorization model are implemented.
- **Legacy cleanup**: all 17 old `public.nova_*` game tables and the old `nova_*` functions were removed after verifying zero rows in every legacy game table. Supabase Auth and platform schemas were not modified.
- **Runtime status**: Firebase Auth remains for identity only. Core gameplay state and migrated operations use the NOVA Supabase `nexora` schema; some remaining organization/mission/achievement flows are not yet cut over. Do not publish this source snapshot as production until the backend cutover and security tests are complete.

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
