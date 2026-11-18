# NEXORA

**NEXORA** is a portrait-first (Mobile-First) economic, corporate management, and social strategy simulation browser game built with **React 19**, **TypeScript**, **Tailwind CSS v4**, **Firebase Authentication**, and **Cloud Firestore**. Supabase is currently an isolated future backend target; it is not connected to live gameplay.

Default UI language is **Arabic (`RTL`)** with instant switching to **English (`LTR`)**.

> **Database isolation notice:** NEXORA data belongs only in the dedicated `nexora` schema of the shared Supabase project `OneState-Trading-DB`. OneState's existing data remains in `public`. Never create, read, update, or delete NEXORA application records in OneState's `public` objects, and never alter those objects. Read [docs/SUPABASE_SHARED_PROJECT.md](docs/SUPABASE_SHARED_PROJECT.md) before any database or Auth changes. PostgreSQL schemas isolate application data; Supabase Auth remains project-wide.

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

## Supabase Target — Isolated Namespace
- **Shared project**: `OneState-Trading-DB` (`dmeupqmhsyojxlgalxrc`, `eu-west-1`).
- **NEXORA schema**: `nexora`; baseline schema applied on 2026-11-16.
- **Baseline**: 22 NEXORA tables, RLS enabled on all 22, zero `anon`/`authenticated` table grants, no Data API exposure, and no NEXORA player data imported.
- **Fail-closed state is intentional**: no client RLS policies or table grants have been added yet. The database advisor's `rls_enabled_no_policy` notices for NEXORA are expected until a reviewed identity model and policies are implemented. Do not loosen this state to silence the notice.
- **OneState**: existing `public` tables/views remain outside the NEXORA migration. Do not modify them.
- **Auth boundary**: Supabase Auth is shared at project level. Firebase Auth remains active pending an explicit isolated identity design.

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
