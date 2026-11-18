# NOVA — Technical Decision Records

**Last updated:** 2026-11-18
**Decision status:** Initial client architecture selected for the next implementation spike; production deployment and backend architecture remain subject to validation.

This document records durable engineering decisions. A prototype experiment is not automatically a production commitment.

## ADR-001 — Client architecture

**Status:** Accepted for the next vertical-slice implementation and performance validation.

### Decision

Build the player client as a **React + TypeScript application bundled by Vite**, with **Phaser 4 for the interactive 2D world-map and castle-rendering surfaces**.

Responsibilities are deliberately separated:

- **React + TypeScript:** account/onboarding screens, HUD, resource bars, building panels, inventory, dialogs, chat, alliance screens, settings, accessibility, localization, and ordinary application navigation.
- **Phaser:** the interactive 2D kingdom map, tile/region rendering, camera movement and zoom, map markers, pointer/touch interaction, and any scene animation that benefits from a game renderer.
- **Shared typed domain layer:** resource and item display models, map coordinates, player commands, command receipts, and view state. Phaser scenes must not become the source of truth for player balances or world rules.
- **Vite:** fast development and static production builds suitable for GitHub Pages. Configure the repository subpath correctly for powerx911/NOVA; verify asset URLs against the built output.

### Why this fits NOVA

NOVA is a persistent strategy game with dense management UI and a shared 2D strategic map. It is not a high-frequency twitch game. Most interactions are deliberate commands—build, upgrade, train, scout, move, communicate, and coordinate—whose results must survive disconnection and be resolved by trusted server rules.

A UI framework is therefore valuable for the many forms, panels, accessible controls, localization states, and responsive layouts. A dedicated 2D renderer is valuable for the map camera, large tile/marker scenes, touch input, and animated world feedback. Separating those responsibilities avoids forcing every interface screen into a game-engine canvas or forcing a large interactive map into ordinary DOM elements.

Phaser's official documentation describes it as a 2D framework for desktop and mobile browsers, with JavaScript/TypeScript support and integration with front-end frameworks including React. Its input system unifies mouse and touch/pointer events. These capabilities match the map interaction requirements:
- https://phaser.io/oss/docs/
- https://docs.phaser.io/phaser/concepts/input

Vite supports static builds and documents GitHub Pages deployment, including the required base path for repository-hosted sites:
- https://vite.dev/guide/static-deploy
- https://vite.dev/guide/build

### Alternatives considered

| Option | Strengths | Trade-offs for NOVA | Decision |
|---|---|---|---|
| React + TypeScript + Phaser | Strong application UI plus dedicated 2D scenes, cameras, input, tilemaps, animation, and TypeScript | Two rendering layers need a clear boundary; Phaser is more engine than simple UI needs | **Selected for the next spike** |
| React + TypeScript + PixiJS | Flexible GPU-accelerated 2D rendering; modular renderer; strong performance controls | Lower-level rendering layer; more map-camera, scene, interaction, and lifecycle systems must be built and maintained by NOVA | Reserve as fallback if Phaser's scene model or bundle/performance profile proves unsuitable |
| Godot | Full game editor and integrated 2D/3D tooling; useful if NOVA becomes a heavily animated native game | Adds an engine-centric UI workflow and web/native packaging constraints for a product dominated by strategy panels, forms, social systems, and cross-platform web access | Not selected for the current interaction model; reconsider only if visual/gameplay requirements materially change |
| Plain HTML/CSS/JavaScript | No build tool or dependency overhead; useful for the first interaction spike | Becomes harder to maintain as typed game systems, localization, tests, and complex screens grow | Keep only as the current disposable prototype, not the production architecture |

PixiJS remains a credible fallback. Its documentation describes WebGL/WebGL2 as the recommended stable renderer, while WebGPU and Canvas renderer options are still experimental; its performance guide emphasizes profiling on target devices and controlling texture/draw-call complexity:
- https://pixijs.com/8.x/guides/components/renderers
- https://pixijs.com/8.x/guides/concepts/performance-tips

### Validation gate before committing to the full client

The first React/Phaser spike must prove:

1. The 7×7 prototype map can become a larger region map with smooth pan, zoom, tap selection, and a readable overview on Android portrait screens.
2. React panels and Phaser canvas resize correctly together without input conflicts or safe-area clipping.
3. A representative mid-range Android device can sustain responsive interaction without excessive memory, heat, or battery use.
4. Arabic RTL and English LTR layouts remain readable while the world map keeps a stable coordinate/rendering system.
5. The client can reconnect and reconstruct its view from server state instead of trusting stale local state.
6. A static production build works under the GitHub Pages repository path and all assets resolve correctly.

If the spike fails these gates, compare PixiJS or another option before expanding the client. Do not add a native Android wrapper until browser/PWA usability and the core gameplay loop are validated.

## ADR-002 — Backend authority and online state

**Status:** Architecture principles accepted; production schema and game command endpoints not yet implemented.

### Decision

Continue with the existing Supabase project as the initial backend foundation:

- **Supabase Auth:** verified player identity and session lifecycle.
- **Postgres:** canonical durable player, castle, inventory, economy, alliance, message, and world records.
- **Trusted server-side command layer:** validate and authorize every valuable action; perform resource/item ledger changes and world mutations transactionally and idempotently.
- **Supabase Realtime Broadcast:** transient event delivery only, after durable state commits.
- **Presence:** low-frequency online state only.
- **Storage:** player media and approved game assets with strict upload/access rules.

The browser client must never decide or directly write authoritative resource balances, item quantities, castle coordinates, battle outcomes, rewards, alliance permissions, or treasury changes.

For the initial vertical slice, evaluate Postgres transactions and narrowly scoped Edge Functions for command handling. Long-running world simulation, high-volume scheduled resolution, and large-scale fan-out must be load-tested; add a dedicated game service or queue only when evidence requires it. Do not promise global-scale concurrency based on the current project plan.

### Security requirements

- Enable RLS on every exposed application table; default deny and authorize rows by verified identity and membership.
- Never use editable user metadata for authorization.
- Never expose service-role/secret keys in the client.
- Validate ownership, permissions, state version, costs, cooldowns, quotas, and target eligibility on the server.
- Use command IDs and idempotent receipts to prevent duplicate rewards or item consumption on retries.
- Record an auditable ledger for resource and inventory mutations.
- Persist chat and important events in Postgres; use private Realtime channels with membership authorization.
- Reconnect by loading canonical state and durable history, then resume live event subscriptions.

No production tables or migrations are created by this decision record.

## ADR-003 — Source control and delivery

**Status:** Accepted.

- GitHub repository powerx911/NOVA remains the source of truth.
- All changes use feature branches, pull requests, CI checks, and reviewed merges.
- GitHub Actions is the CI and deployment control plane.
- GitHub Pages is the intended static client host; it must be enabled once in repository Settings → Pages → Build and deployment → Source → GitHub Actions. The current deployment attempt is blocked because no Pages site is configured.
- Supabase Edge Functions deploy through the existing GitHub Actions workflow after the backend code and tests are ready.
- **Vercel is not used.**
- No paid hosting, domain, native build service, or purchased asset is introduced without owner approval.

## ADR-004 — First playable vertical slice

**Status:** Next implementation target.

The next end-to-end milestone should replace the current local-only prototype with a small authenticated, server-backed loop:

1. Sign in and load a stable player profile.
2. Load the player's castle and initial resource state from the server.
3. Display castle buildings and the kingdom map as separate connected views.
4. Submit one server-validated building-upgrade command with a command ID.
5. Atomically deduct resources, increase the building level, and store a command receipt.
6. Reconnect/reload and prove the server state is preserved without duplicate deduction.
7. Show clear loading, failure, retry, offline, and success states.

Inventory and relocation remain in the local prototype until the same server-authoritative transaction and map-placement rules are ready. Do not simulate real multiplayer by trusting localStorage.

## Open validation and release gates

- Select and pin exact package versions; commit a lockfile and audit transitive dependencies before adding the production client toolchain.
- Confirm Phaser 4's actual mobile/browser support against the target Android devices.
- Implement and test localization, reduced motion, accessibility, and offline/reconnect behavior.
- Validate Supabase concurrency, database transaction patterns, Edge Function limits, Realtime authorization, backups, and recovery.
- Verify GitHub Pages is enabled and the static build is deployed before sharing a public play URL.
- Native Android packaging, store listing, legal disclosures, privacy policy, and public store release remain separate release decisions.
