# NOVA — Project Status & Engineering Log

> **Purpose:** This is the handover source of truth for any developer or AI agent continuing NOVA. Read this file before making changes, then inspect the repository and GitHub Actions for the live state. Update this file in the same change as every project change.

**Last verified/updated:** 2026-11-18 (Pages deployment verified; player foundation PR in progress)
**Repository:** https://github.com/powerx911/NOVA
**Default branch:** `main`
**Project name:** NOVA

---

## 1. Operating rules (mandatory)

1. **Never implement a requested feature or fix directly on `main`.**
2. For every requested addition, change, fix, refactor, or infrastructure update, create a dedicated branch from the latest `main`.
3. Keep the change isolated to that branch. Finish implementation and run all relevant checks before opening a pull request.
4. Review the diff and test results. Fix failures before merging. If a check cannot be run, record exactly what could not be verified and why; do not describe it as passed.
5. Open a pull request targeting `main`. Merge only after checks and review are complete. Do not bypass failing checks or unresolved blockers.
6. After merge, verify the deployment workflow and the deployed service/site itself. A successful merge is **not** proof of a successful deployment.
7. Update this file in the same branch/PR for every project change. Record what changed, why, files affected, checks and their results, merge/commit identifiers, deployment result, and any remaining issues.
8. Record bugs and incomplete work here as soon as discovered. Keep unresolved items visible until they are fixed and verified; never silently erase history.
9. Do not commit credentials, access tokens, private keys, or secret values. Record secret **names and locations only**, never their values.
10. Keep a chronological activity log. The latest state summary should reflect reality, not intended or assumed behavior.

### Standard change lifecycle

`latest main → dedicated branch → implement + update this log → run checks → inspect diff → PR → verify checks/review → merge → verify deployment → update status`

If deployment fails after merge, record the failure and create a separate fix branch when a code/configuration change is needed.

---

## 2. Project architecture and services

| Area | Current configuration |
|---|---|
| Source control | GitHub repository `powerx911/NOVA` |
| Production branch | `main` |
| Static hosting target | GitHub Pages; latest deployment workflow completed successfully (run 44330786982); live URL emitted by deployment: https://powerx911.github.io/NOVA/ |
| Backend platform | Supabase |
| Supabase project | `NOVA` |
| Supabase project ref | `hmrprnjhyzyefocdmnxf` |
| Supabase URL | `https://hmrprnjhyzyefocdmnxf.supabase.co` |
| Supabase region | `eu-west-1` |
| Control service | Supabase Edge Function `nova-control` (deployment pending verification) |
| Vercel | **Not used.** The project owner explicitly requires GitHub-based source control, integration, and deployment; do not introduce Vercel. |

NOVA is an Android-first persistent online strategy game in development. The first local playable prototype is deployed to GitHub Pages; it is not yet a multiplayer game. React + TypeScript + Vite and Phaser 4 are selected for the next implementation spike.

---

## 3. Current repository inventory

Known files on `main` as of this baseline:

- `README.md` — project overview and current online multiplayer scope.
- `.gitignore` — ignored files.
- `index.html`, `styles.css`, `app.js` — local interactive castle/map/inventory prototype (browser-local state only).
- `.github/workflows/pages.yml` — GitHub Pages deployment workflow; latest deployment succeeded in run 44330786982.
- `supabase/functions/nova-control/index.ts` — NOVA Control MCP Edge Function implementation.
- `supabase/config.toml` — Supabase function configuration; `nova-control` has `verify_jwt = false` because the function performs its own bearer-token check.
- `docs/NOVA-CONTROL-MCP.md` — MCP service documentation.
- `.github/workflows/deploy-nova-control.yml` — GitHub Actions workflow for deploying the Supabase Edge Function.

This inventory is a known baseline, not a guarantee that no other files exist. Inspect the actual tree before future work.

---

## 4. NOVA Control MCP

**Purpose:** Provide a controlled MCP interface for managing the NOVA GitHub Pages deployment through GitHub APIs.

**Supabase function endpoint:**
`https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/nova-control`

**Health endpoint:**
`https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/nova-control/health`

**Known tools implemented:**

- `get_pages_status`
- `enable_pages` — requires explicit `confirm: true`.
- `dispatch_pages_workflow` — requires explicit `confirm: true`.
- `list_pages_workflow_runs`
- `get_pages_workflow_run_jobs`

The function is configured to target repository `powerx911/NOVA`, workflow `pages.yml`, branch `main`. It authenticates requests using `NOVA_MCP_ACCESS_TOKEN` and uses `NOVA_GITHUB_TOKEN` for GitHub API access. Secret values must remain in Supabase/GitHub secret storage and must never be printed or committed.

Implementation details and tool contract: `docs/NOVA-CONTROL-MCP.md`.

---

## 5. GitHub Actions and required secret names

### Supabase function deployment workflow

File: `.github/workflows/deploy-nova-control.yml`

Known behavior:
- Runs manually via `workflow_dispatch`.
- Runs automatically on pushes to `main` affecting:
  - `supabase/functions/nova-control/**`
  - `supabase/config.toml`
  - `.github/workflows/deploy-nova-control.yml`
- Uses Supabase CLI version `2.117.0`.
- Sets the function secrets in the existing Supabase project and deploys `nova-control`.

Expected GitHub Actions repository secrets (names only):
- `SUPABASE_ACCESS_TOKEN`
- `NOVA_GITHUB_TOKEN`
- `NOVA_MCP_ACCESS_TOKEN`

The user reported adding all three secrets to the repository's Actions secrets. Their current validity and permissions still need to be confirmed by a successful workflow run. Never ask the user to paste secret values into chat.

### Pages workflow

File: `.github/workflows/pages.yml`

GitHub Pages is enabled with GitHub Actions as its source. Deployment run 44330786982 completed successfully; the deployment job emitted https://powerx911.github.io/NOVA/ as its environment URL. Independent HTTP/browser/device verification remains outstanding.

---

## 6. Git history and completed changes

### PR #1 — NOVA Control MCP infrastructure

- PR: https://github.com/powerx911/NOVA/pull/1
- Head branch: `infra/nova-control-mcp`
- Base branch: `main`
- Result: **Merged** (squash).
- Merge commit: `a51571dbe122cd6a581f1478c085b680fb10ff4f`
- GitHub reported `merged: true`.

Files introduced/updated by this PR:
- `supabase/functions/nova-control/index.ts`
- `supabase/config.toml`
- `docs/NOVA-CONTROL-MCP.md`
- `.github/workflows/deploy-nova-control.yml`

### PR #2 — Project status and handover baseline

- PR: https://github.com/powerx911/NOVA/pull/2
- Head branch: `docs/project-state-baseline`
- Result: **Merged** (squash).
- Merge commit: `a7a1786f6bedb9f66bf2ffa648b1c4c3e1dd9361`
- Added `PROJECT_STATUS.md` as the durable project handover record.
- Checks: documentation consistency review; no application code changed. Runtime tests were not applicable to this documentation-only PR.
- Deployment: no deployment behavior was changed or triggered by this documentation-only PR.

Important: PR merge success confirms source integration only. It does not confirm that the Edge Function deployed, the endpoint is healthy, or MCP calls work.

---

## 7. Current status and unresolved work

Statuses below distinguish completed source changes from verified live behavior.

| Item | Status | Notes / next verification |
|---|---|---|
| GitHub repository connected and writable | Reported working | GitHub connector has repository access; verify if permissions change. |
| NOVA Control MCP source merged | **Done** | PR #1 merged to `main`. |
| Project handover document | **Done** | `PROJECT_STATUS.md` is present on `main`; keep it current with every change. |
| Three Actions secrets added | User-reported done | Workflow must prove they are valid and sufficiently scoped. |
| First `deploy-nova-control.yml` run | **Unverified** | This is separate from the Pages workflow; confirm the Edge Function deployment run. |
| Supabase Edge Function deployment | **Unverified** | Check GitHub Actions run and Supabase function list/deployed version. |
| MCP health endpoint | **Untested** | Verify HTTP health response after deployment. |
| MCP protocol/tool calls | **Untested** | Test authenticated MCP connection and each required tool safely. |
| GitHub Pages enabled | **Done** | Source is GitHub Actions; Pages deployment run 44330786982 succeeded. |
| First Pages deployment | **Done** | Run 44330786982, attempt 2: Setup Pages, artifact upload, and Deploy to GitHub Pages all succeeded. Environment URL: https://powerx911.github.io/NOVA/. The earlier failure 44329798929 is resolved. |
| Automated branch/PR/test/merge/deploy lifecycle | **Process agreed; not yet fully validated** | Follow the mandatory lifecycle in section 1 for every future change. |
| Game implementation | **First local playable prototype merged** | Castle/buildings/resources, 7×7 map, bag and relocation simulations, starter quests, and local saving are implemented. React/TypeScript + Vite + Phaser 4 is selected for the next implementation spike; authentication, multiplayer, server-authoritative gameplay, combat, and production schema remain unimplemented. |

### Known risks / checks still required

- The MCP TypeScript/Deno implementation had not yet undergone a confirmed lint, type-check, or integration test at the time of this baseline.
- GitHub token scopes/permissions may be insufficient for Pages or Actions operations; let the workflow/API response identify the exact missing permission.
- Supabase access token permissions may be insufficient for setting Edge Function secrets or deploying functions.
- The MCP access token was previously displayed in the chat history. Treat it as exposed to the conversation history and rotate it to a fresh value after deployment is stable. Never repeat the old value.
- Do not claim autonomous control is fully operational until deployment, authentication, MCP tool calls, and required GitHub actions have been tested successfully.

---

## 8. Change log

### 2026-11-18 — Autonomous product-development mandate

- The user explicitly delegated day-to-day product, design, engineering, quality, and prioritization decisions for NOVA. The assistant should proactively identify and implement necessary features, improvements, fixes, and polish without requiring the user to specify each task.
- Recorded a provisional Android-first adventure-RPG idea as an early proposal. **Superseded on 2026-11-18** by the owner's explicit online-first competitive multiplayer requirements in section 13; it is not the selected genre.
- Added `docs/PRODUCT_VISION.md` as the product decision and quality charter.
- This mandate does not authorize spending money, accepting legal terms, making identity/account ownership declarations, exposing secrets, or destructive production data changes without explicit user approval.
- All implementation continues to follow branch → review/tests → PR → merge → deployment verification. No direct pushes to `main`.
- PR: https://github.com/powerx911/NOVA/pull/6 — merged (squash).
- Merge commit: `9c0b4d7a2dbcb5a96f1cace80cf2adc339c98354`.
- Checks: documentation content and consistency review; runtime tests are not applicable to this documentation-only change. No configured commit status checks were reported for this documentation-only commit.
- Deployment: not applicable; no runtime or deployment configuration changed.


### 2026-11-18 — Android-first standard and game-reuse research

- Added mandatory Android-first product/UX requirements for NOVA.
- Added `docs/REUSE_RESEARCH.md` summarizing the user's prior NEXORA and VORZANE projects and selected external open-source references.
- This is a research/documentation change only: no game code, assets, dependencies, backend schema, secrets, or deployment settings were changed.
- Findings explicitly separate reusable design ideas from incomplete/unsafe legacy implementation paths and third-party assets requiring license review.
- Branch: `research/old-games-and-open-source-systems`.
- PR: https://github.com/powerx911/NOVA/pull/4 — merged (squash).
- Merge commit: `3dc6491bd326c34dc50e0f85077bfc77d84857b7`.
- Checks: source links and repository contents reviewed; documentation consistency review only. Runtime tests are not applicable because no executable code changed. GitHub commit status had no configured status checks for this documentation-only commit.
- Deployment: not applicable; no deployment configuration or runtime code changed.


### 2026-11-18 — Record baseline PR merge

- Updated this file to record PR #2 and its squash merge commit.
- Marked the handover document as present on `main`.
- Confirmed the documentation-only change did not alter application code or deployment behavior.
- Branch: `docs/record-baseline-merge`.
- Checks: reviewed the updated project status content; runtime tests are not applicable to this documentation-only update.
- PR: https://github.com/powerx911/NOVA/pull/2
- Merge commit: `a7a1786f6bedb9f66bf2ffa648b1c4c3e1dd9361`.

### 2026-11-18 — Project handover baseline created

- Added this file: `PROJECT_STATUS.md`.
- Purpose: maintain a durable, detailed handover record for future agents/developers.
- Recorded known architecture, repository inventory, MCP design, workflow behavior, secret names, PR #1 merge details, and all currently unverified deployment/testing items.
- Checks: documentation consistency review against the known project history. No application code was changed by this baseline.
- Branch: `docs/project-state-baseline`.
- PR #2 was opened and merged after this initial entry was written; see the PR #2 record above.

### Earlier history — NOVA Control MCP

- Implemented the NOVA Control MCP Edge Function and its documentation/configuration.
- Added the Supabase deployment GitHub Actions workflow.
- Opened PR #1 from `infra/nova-control-mcp` and squash-merged it into `main`.
- Merge commit: `a51571dbe122cd6a581f1478c085b680fb10ff4f`.
- Deployment and runtime verification remain pending (see section 7).

---

## 9. Handover checklist for the next agent

Before changing anything:

1. Read this file completely.
2. Inspect the latest `main`, open PRs, recent commits, and GitHub Actions runs; this document can lag behind live state.
3. Check the Supabase project and deployed Edge Function state without exposing secrets.
4. Identify the latest unresolved items in section 7.
5. Create a dedicated branch from the latest `main`; never work directly on `main`.
6. Update this document in the same PR as every change.
7. Run and report relevant checks honestly, then merge and verify deployment only when all required gates pass.

**If this document and live GitHub/Supabase state disagree, verify the live state, correct this document in a branch, and preserve the discrepancy in the change log.**


## 10. Android-first product and UX requirements (mandatory)

NOVA is intended to feel like a real Android game/app on a phone, not a conventional responsive website. These requirements apply to every future screen, feature, and gameplay interaction:

- Design mobile-first for Android portrait screens by default; support landscape when the gameplay mode benefits from it.
- Adapt to different Android screen sizes, aspect ratios, densities, and browser/system UI insets without clipping controls or important content.
- Use safe-area-aware layouts and appropriate edge-to-edge/fullscreen behavior. Where the delivery format is an installable PWA, provide a standalone app experience and request fullscreen only through supported Android/user-initiated behavior.
- Make touch the primary input: large finger-friendly targets, clear spacing, readable typography, visible pressed/disabled/loading states, and gestures that do not conflict with browser navigation.
- Keep navigation and core actions comfortable for one-handed use where practical; avoid desktop-style tiny controls and dense admin-dashboard layouts.
- Provide smooth, short transitions and responsive feedback without blocking gameplay or tying animation completion to slow network/save operations.
- Optimize startup, asset loading, memory, rendering, and battery use for mid-range Android devices as well as high-end phones.
- Plan offline behavior intentionally: clear offline status, local progress protection, retry/reconciliation behavior, and no silent loss or overwrite of player progress.
- Test real interactions and layouts across representative Android viewport sizes and at least one real Android device before calling a screen complete. Automated mobile browser tests are useful but do not replace device verification.
- Do not call the experience Android-native or claim an APK exists unless an actual native package has been built and verified.

The selected game engine/rendering stack has not yet been decided. Choose it only after the game genre and interaction model are defined; do not force a desktop-first engine or port a legacy stack merely because it exists.

## 11. Prior-game and open-source research status

Research findings and candidate systems are recorded in `docs/REUSE_RESEARCH.md`.

- Prior projects inspected: `luffyk124-del/nexora-game` (economic/corporate simulation) and `luffyk124-del/vorzane` (fantasy RPG).
- External references inspected: Violencetown, CodingQuests Godot systems, Embervale, and Phaser/PWA/asset licensing documentation.
- Research only: no legacy code, assets, database, authentication provider, deployment configuration, or third-party dependency has been copied into NOVA.
- Reuse decisions are conditional on NOVA's still-unconfirmed game genre, code ownership, dependency compatibility, and per-asset/per-component license review.
- Do not import VORZANE's generic client full-save mutation path or client-computed battle settlement as authoritative game state. Its own audit identifies these as unresolved server-authority blockers.
- Do not import old Firebase or Vercel-specific infrastructure into NOVA. NOVA remains on GitHub + its existing Supabase project; Vercel is prohibited for this project.
- Do not begin the playable game implementation until the online-first foundation and a documented technical/product evaluation identify a justified first vertical slice. The user has delegated ordinary product and engineering decisions; no separate approval is needed for routine technical choices.


## 12. Autonomous product-development mandate

The user has explicitly delegated day-to-day product, design, engineering, prioritization, and quality decisions to the development agent. Do not wait for the user to name every feature or technical task. Proactively inspect the product, identify gaps and risks, propose priorities internally, and implement the highest-value improvements in small reviewable increments.

Current user-defined direction: an online-first persistent multiplayer experience centered on competitive alliances, diplomacy, economy, armies, and wars, with polished profiles, friends, private messages, and global chat as foundational systems. The final genre label, world/theme, camera, combat presentation, session structure, client engine, and launch platform packaging remain intentionally undecided pending a documented evaluation. Do not silently revert to the previously suggested single-player adventure RPG direction. The product vision and requirements live in `docs/PRODUCT_VISION.md` and `docs/ONLINE_GAME_FOUNDATION.md` and must evolve from prototypes, tests, and evidence.

Autonomy boundaries:
- The agent may make ordinary product, UX, architecture, code, test, documentation, and non-destructive development decisions without asking the user each time.
- The agent must not spend money, subscribe to paid services, accept legal terms, make identity/ownership declarations, expose or request secrets in chat, or perform destructive production-data/account actions without explicit user approval.
- Never silently introduce analytics, advertising, invasive tracking, loot-box monetization, pay-to-win mechanics, or purchases. Any monetization must be transparent, fair, age-appropriate, and separately approved.
- Preserve the user's GitHub-only source/merge/deployment preference and existing Supabase project. Vercel remains prohibited.
- Continue to use isolated branches, meaningful tests, reviewable PRs, merge only after checks, and verify actual deployment separately.
- Be honest about what is implemented, tested, deployed, and still incomplete. Never call a prototype production-ready merely because it builds.

Quality gate: no placeholder copy, lorem ipsum, dead controls, fake functionality, unhandled error states, preventable data loss, obvious spelling/grammar defects, or unverified claims. All player-facing text must be reviewed in its target language and context. A feature is not complete until its real user flow, loading/empty/error/offline states, accessibility/touch behavior, and relevant Android layouts have been checked.

Release aspiration: target a polished, stable, store-quality Android game. Google Play release readiness requires separate verification of Android packaging/signing, target API requirements, privacy/data disclosures, content rating, store assets/listing, device compatibility, crash/performance behavior, and Play Console submission. Do not claim Play Store publication or native APK/AAB readiness until those steps have actually been completed and any account-owner approvals obtained.


## 13. Online-first multiplayer requirements (user-confirmed)

The user explicitly requires NOVA to be online and socially connected from its foundations. The experience must include professional player profiles, friend/player connections, private conversations, global chat, organized high-quality menus and visual presentation, competitive alliances, an economy, armies, and wars. The game should create long-term player attachment through meaningful social, economic, diplomatic, and competitive systems.

- The final game category, setting, theme, camera, exact gameplay presentation, and engine must **not** be locked yet. First complete the online-first foundation and technical evaluation.
- The previous adventure-RPG direction is superseded as an unapproved early proposal. Do not treat it as the final category.
- Detailed requirements and architectural principles: `docs/ONLINE_GAME_FOUNDATION.md`.
- Player profile/social baseline: identity and public profile, privacy controls, friend requests, blocking, reporting, online status, private messaging, global chat, and later alliance communications.
- Persistent competitive systems: alliances, memberships/roles, diplomacy, shared goals and treasury, resources, production, trade, armies, conflict resolution, seasons, and fair leaderboards.
- The backend must be authoritative for valuable shared state: currency, resources, inventory, production, market transactions, alliance membership/treasury, military orders, battle outcomes, rankings, and rewards.
- Realtime transport must not be confused with durable storage or trusted game rules. Store durable messages and game events, and authorize private channels by player/alliance/room membership.
- Global and private chat require moderation and abuse controls: rate limiting, mute/block/report, anti-spam, retention controls, and safe escalation processes.
- No real-money purchases, pay-to-win, ads, or personal-data analytics without separate explicit approval.
- Brand/domain/social-share metadata and a properly licensed music/audio plan are required foundations. A short free subdomain may be acceptable as an interim URL, but stability, ownership, and share-preview behavior must be tested before relying on it.
- Current infrastructure audit on 2026-11-18: Supabase project `NOVA` is `ACTIVE_HEALTHY`; public schema contains no game tables yet; Edge Function `nova-control` is listed as ACTIVE version 1. GitHub repository is writable. These facts do not prove Pages is enabled or the game deployment is live.
- A Figma workspace file was created for the product/interface foundation: https://www.figma.com/design/5bVPOQxGkZC8DXpm4yznvy.
- Figma and Context7 have been connected in ChatGPT for design workflow and current technical documentation. No paid Figma AI generation or paid services were invoked.
- Technical research verified Supabase Realtime's intended split: Broadcast for low-latency transient messages/events, Presence for low-frequency online state, and durable Postgres rows for stored messages and canonical game state. Private channels require explicit Realtime Authorization/RLS; public channel access should be disabled for production private topics. See citations/links in `docs/ONLINE_GAME_FOUNDATION.md`.
- No game client, schema, monetization, domain purchase, or production data mutation was made in this foundation-preparation change.

### 2026-11-18 — Online-first competitive multiplayer foundation

- Replaced the provisional adventure-RPG proposal with the user's actual requirements: online-first persistent multiplayer, player profiles/social features, alliances, economy, armies, wars, and sustained competitive play.
- Preserved the final genre, setting, gameplay presentation, and engine as open decisions pending evaluation.
- Added `docs/ONLINE_GAME_FOUNDATION.md` with player/social/gameplay requirements, server-authoritative backend principles, chat safety, realtime architecture, domain/share metadata, licensed audio, and technical decision gates.
- Updated `README.md` so the public project description reflects the confirmed online-first direction without prematurely claiming a final genre or client platform.
- Created Figma workspace: https://www.figma.com/design/5bVPOQxGkZC8DXpm4yznvy.
- Connected Figma and Context7; used Context7 and current Supabase documentation to validate Realtime role separation and private-channel authorization principles.
- Audited current Supabase project: ACTIVE_HEALTHY; no public game tables; nova-control function ACTIVE version 1.
- Branch: `docs/online-world-foundation`.
- Validation: reviewed source docs and Supabase project/table/function state; re-fetched changed documents and checked alignment across README, product vision, foundation requirements, and project status. Runtime game tests are not applicable because no executable game code or database schema was changed.
- Deployment: no runtime code or deployment workflow changed; no deployment is claimed.


## 14. Player experience, alliance governance, and global operations

- The owner requires NOVA to be reviewed from both the operator's perspective (safe, fair, sustainable global service) and the player's perspective (enjoyable play, convenience, clear goals, meaningful long-term progress).
- Added `docs/PLAYER_EXPERIENCE_AND_OPERATIONS.md` covering player onboarding and return journeys, multi-horizon goals, quality-of-life, alliance discovery/invitations/settings/roles/permissions/member removal/succession, support tickets, moderation workflows, staff roles, admin control plane, audit trails, and live operations.
- Alliance governance is server-enforced; invitation links need expiry/quotas; treasury and high-impact actions need auditable approvals; removals need reasoned records and fair appeal paths.
- Support requires searchable self-service help, ticket IDs/status/history, escalation, privacy-safe evidence, and secure account recovery.
- Staff permissions must be least-privilege and separated between moderation, support, economy, content, and platform ownership. Moderators cannot edit balances or battle outcomes.
- Retention design uses meaningful short/medium/long-term goals, social belonging, sustainable events and updates, new-player protection, and fair recovery—not manipulative daily attendance.
- Research references reviewed: Roblox onboarding and LiveOps guidance, Meta's 2026 live-service checklist, Ofcom's interactive-services moderation model, and Fair Play Alliance/ADL reporting and enforcement framework. Links are in the new document.
- No analytics collecting personal data, support portal, moderator console, or game code was implemented by this documentation change.
- Branch: `docs/player-journey-and-live-operations`.
- Validation pending: re-fetch and cross-check documents, compare with main, and review PR before merging. No deployment is claimed.


## 15. Kingdom map, personal castles, and initial game rules (owner-confirmed)

- Clarified the world model: the kingdom is the shared strategic map containing established core cities, villages, regions, neutral territories, and resource/strategic sites. It is not a shared city where players build their own homes.
- Every player owns and develops a separate personal castle/city placed at an eligible site on the kingdom map. The castle contains the player's palace, farms, barracks, production, storage, and upgrades.
- Initial entry flow: sign in/create account → select a kingdom (first: Kingdom 1) → story-led tutorial with a skip option → develop the player's own castle.
- Tutorial premise: invading enemies devastated the player's once-powerful homeland; the player returns with advisors after the invaders leave and rebuilds through guided gameplay objectives.
- Initial army classes: infantry, cavalry, archers, and chariots (مشاة، فرسان، رماة، عجلات).
- Initial alliance-to-alliance diplomatic states are only neutral, war, and peace. More complex treaties are excluded from the initial scope.
- Detailed design recorded in docs/PRODUCT_VISION.md and docs/ONLINE_GAME_FOUNDATION.md.
- This is a documentation-only clarification. No game client, production database schema, or live gameplay behavior was changed. No deployment is claimed.


## 16. Map, player bag, relocation, and quality-of-life systems (design requirements)

- Added the shared kingdom map interaction model: touch zoom/pan, layers, location details, search, bookmarks, recent destinations, alliance markers, and clear distinction between shared locations and personal castles.
- Added persistent player inventory/bag requirements: categories, stacks, sorting/search, capacity, item details, acquisition/consumption history, and server-authoritative idempotent item use.
- Added two intended relocation items: Advanced Relocation (player-selected valid destination) and Random Relocation (server-selected eligible destination), with destination preview, safety, fairness, cooldown, anti-abuse, and atomic-consumption requirements.
- Added player command overview, activity/report inbox, bookmarks, and configurable notifications as core quality-of-life systems.
- Detailed requirements recorded in docs/ONLINE_GAME_FOUNDATION.md, docs/PLAYER_EXPERIENCE_AND_OPERATIONS.md, and docs/PRODUCT_VISION.md.
- Documentation-only change. No gameplay code, database schema, item balances, or live relocation behavior has been implemented. No deployment is claimed.


## 17. First playable castle prototype (2026-11-18)

- Started the first executable NOVA player-facing prototype in branch `feat/first-playable-castle-prototype`; this is the first move from requirements-only work into an interactive game client.
- Replaced the static placeholder landing page with an Arabic-first, RTL, mobile-first castle-management interface.
- Added an original CSS castle scene, resource bar (food, wood, stone, iron, gold), four building cards (keep, farm, lumber mill, barracks), resource collection, upgrade cost checks, and level progression.
- Added a 7×7 kingdom-map prototype with distinct terrain/location types, location inspection, current castle marker, advanced relocation to a selected empty land tile, and random relocation to an eligible tile.
- Added a persistent local inventory prototype with Advanced Relocation, Random Relocation, and Supply Pack items; quantity display, filtering, confirmation dialogs, and local consumption.
- Added starter objectives and rewards, player profile summary, and local browser persistence with a reset option.
- All prototype state is explicitly local to the current browser/device. No authentication, multiplayer, shared world, authoritative server rules, production Supabase schema, combat, or real item economy has been implemented. Relocation and rewards are simulations only and must not be described as live online functionality.
- The client uses dependency-free HTML/CSS/JavaScript for a fast interaction spike; this does **not** lock the final production client/game-engine choice. A technical decision record and online vertical-slice architecture remain necessary before production backend integration.
- Added a pull-request validation workflow for JavaScript syntax, required page assets/anchors, and whitespace checks.
- Updated README to describe the prototype and its limitations accurately.
- Validation: **passed** in GitHub Actions run `44329641543` (job `validate`): JavaScript syntax, required page assets/DOM anchors, and `git diff --check` all completed successfully. Real browser/device interaction and Android device testing are not yet verified.
- PR: https://github.com/powerx911/NOVA/pull/12 — merged (squash) as `22fadc3ff88ee219d076fb89a68a2bfd48f3cbb4`. Deployment: attempted by Pages workflow `44329798929`, but blocked because no Pages site is enabled for the repository. No live deployment is claimed.


## 18. Prototype merge and GitHub Pages deployment blocker (2026-11-18)

- Verified PR #12 is merged to `main` (squash): https://github.com/powerx911/NOVA/pull/12.
- Merge commit: `22fadc3ff88ee219d076fb89a68a2bfd48f3cbb4`.
- The prototype validation workflow passed in run `44329641543`; the follow-up documentation-only PR-head run `44329752584` also completed successfully.
- The merge triggered GitHub Pages workflow run `44329798929`. Checkout passed, but `actions/configure-pages@v5` failed with HTTP 404 because the repository has no Pages site configured. Artifact upload and deployment were skipped.
- This is a repository Pages enablement/configuration blocker, not a game-code build failure. GitHub Pages has not been activated and the game is not publicly deployed.
- Required one-time owner-side setting if no authorized API path is available: repository Settings → Pages → Build and deployment → Source → GitHub Actions. Then rerun the existing Pages workflow.
- Do not set `enablement: true` with the default `GITHUB_TOKEN`: the official configure-pages action documents that automatic enablement requires a token other than `GITHUB_TOKEN` with appropriate repository administration and Pages permissions.
- No paid hosting, Vercel, production database changes, or secrets were introduced.


## 19. Client architecture decision (2026-11-18)

- Added docs/TECHNICAL_DECISIONS.md with architecture decision records for the player client, backend authority, delivery, and first authenticated vertical slice.
- Selected React + TypeScript + Vite for application UI/build tooling and Phaser 4 for 2D map/castle rendering as the next implementation spike. This is not yet a claim that mobile performance, production suitability, or the final client implementation has been verified.
- Kept the current dependency-free HTML/CSS/JavaScript client explicitly as a local interaction prototype, not the production stack.
- Evaluated PixiJS as a lower-level 2D rendering fallback and documented why the current NOVA interaction model favors a React UI plus a dedicated 2D scene framework.
- Confirmed architecture boundaries: Supabase Auth for identity, Postgres for durable canonical state, trusted server-side commands for valuable mutations, Realtime Broadcast for transient delivery, and Presence for low-frequency online state. No production schema or migration was created.
- Defined the next end-to-end vertical slice: authenticated player profile → server-loaded castle/resources → validated building-upgrade command → atomic resource deduction and command receipt → reconnect/reload verification.
- Research references: Phaser official docs and input guide; Vite static deployment/build docs; PixiJS renderer and performance docs. URLs are recorded in docs/TECHNICAL_DECISIONS.md.
- GitHub Pages remains blocked until the repository's Pages source is enabled as documented in section 18.
- Validation: documentation review and consistency check; no runtime code or dependencies changed. PR: pending. Merge/deployment: pending.


## 20. GitHub Pages deployment and server-authoritative player foundation (2026-11-18)

### Pages deployment

- The owner selected GitHub Actions in repository Settings → Pages → Build and deployment.
- Rechecked Pages workflow run 44330786982, attempt 2: overall conclusion success.
- Deployment job 134899489204: Checkout, Setup Pages, Upload artifact, and Deploy to GitHub Pages all succeeded.
- The workflow log emitted the environment URL: https://powerx911.github.io/NOVA/.
- Artifact github-pages uploaded successfully (60,417 bytes).
- Independent external HTTP/browser/Android verification was not possible in this environment. The deployment itself is confirmed by GitHub Actions; do not claim device testing.
- The deployed artifact is still the local-only HTML/CSS/JavaScript prototype. It is not a persistent online multiplayer game.

### First server-authoritative player foundation — in progress

- Created feature branch feat/server-authoritative-player-foundation from latest main.
- Added supabase/migrations/20261118151416_nova_player_core.sql proposing six RLS-protected tables: profiles, economy, personal castles, buildings, idempotent command receipts, and resource ledger.
- Added two authenticated RPC commands: nova_initialize_player and nova_upgrade_building. The upgrade command validates ownership, calculates costs server-side, locks state, deducts resources and increments the building in one transaction, records a ledger, and returns a replay-safe receipt.
- Castle coordinates are allocated uniquely within an initial 1000×1000 kingdom grid. Terrain, map placement rules, and relocation remain future work.
- Added docs/SERVER_AUTHORITATIVE_PLAYER_FOUNDATION.md documenting scope, security, limitations, and the post-merge verification plan.
- Added scripts/check-player-migration.mjs and extended .github/workflows/prototype-checks.yml to statically check table/RLS coverage, RPC grants, idempotency lock, ownership check, ledger, and absence of direct client mutation policies.
- PR #15 merged successfully as 5c062b53c728f5b75dc0123d2286630bb2488a11. The migration was then applied to the existing Supabase NOVA project as version 20261118151416. All six tables were verified present with RLS enabled; each currently has zero rows. This is an additive schema change only.
- PR #15 CI passed in run 44333123249. The schema was applied and table/RLS presence verified. Authenticated multi-user isolation and command idempotency integration tests remain outstanding before client integration.


## 21. Security advisor follow-up for player RPCs (2026-11-18)

- Applied migration version 20261118151416 (nova_player_core) to the existing Supabase project after PR #15 merged. Verified all six tables exist and RLS is enabled on each.
- Supabase security advisor reported two warnings because the public RPC functions were SECURITY DEFINER and callable by authenticated users. This behavior was intentional for atomic authoritative mutations, but the advisor correctly highlighted the exposed-schema risk.
- Created follow-up branch fix/harden-player-command-rpcs. Added a migration to move the privileged SECURITY DEFINER implementations into the non-exposed private schema and replace the public API functions with SECURITY INVOKER wrappers.
- Updated the server-authoritative foundation documentation and CI static checks to enforce this boundary.
- PR #16 merged successfully as c7a63a8efb9ac5af98db770676e70049a7372888. The hardening migration was applied to Supabase as version 20261118151655 (name: 20261118151500_harden_player_rpc_schema).
- Verified function placement and permissions with SQL: private implementations are SECURITY DEFINER; public RPC wrappers are SECURITY INVOKER; authenticated can execute both; anon cannot execute either.
- Re-ran Supabase security advisors: **zero security findings**. Performance advisor reports two INFO-level unused indexes on empty tables; expected before gameplay traffic and to be re-evaluated after usage.


## 22. Player command RPC hardening applied (2026-11-18)

- PR #16 merged as c7a63a8efb9ac5af98db770676e70049a7372888 after CI run 44333723681 passed.
- Applied migration 20261118151500_harden_player_rpc_schema to the existing Supabase project; Supabase recorded version 20261118151655.
- Moved privileged SECURITY DEFINER implementations into the non-exposed private schema. Public RPC functions are SECURITY INVOKER wrappers.
- Verified with a read-only SQL query: both private functions are SECURITY DEFINER and executable by authenticated but not anon; both public wrappers are SECURITY INVOKER and executable by authenticated but not anon.
- Re-ran Supabase security advisors: zero security findings. Performance advisor has two INFO-level unused indexes on currently empty ledger/receipt tables; retain pending real usage data.
- The player schema remains empty. Authenticated player initialization, multi-user isolation, and replay-safe upgrade integration tests still need to be performed using real test accounts before client integration.


## 23. Verification log maintenance

- Added PR #17 to keep the project handover aligned with the live Supabase schema and the zero-warning security-advisor result.
- This documentation-only update does not alter runtime code, database schema, or deployment behavior.


### 2026-11-18 — New 2D world-simulation direction and first visual foundation

- Product direction reset following the owner's request: no nation-state/castle strategy framing. The new concept is a simple-to-enter, persistent shared-world 2D simulation centered on player-owned businesses, economy, a sector map, organizations, and simulated conflicts.
- Replaced the previous castle prototype interface with a new Arabic-first, mobile-first visual foundation: modern dark teal palette, illustrated city hero, player wallet, business management, sector map, simulated market, conflict report, organization overview, missions, and profile.
- Added local preview interactions for buying a business, purchasing materials, navigating sectors, and running a training conflict simulation. These are local demo interactions only and must not be represented as multiplayer/server-backed features.
- Updated README to reflect the new product direction and current implementation limits.
- Files changed: `index.html`, `styles.css`, `app.js`, `README.md`, `PROJECT_STATUS.md`.
- Branch: `feat/new-world-game-foundation`.
- Validation at this point: source content authored and reviewed for responsive structure and explicit local-preview labeling. Automated syntax/DOM checks and browser/device testing are pending; no PR has been opened or merged yet.
- Backend: existing Supabase project and prior secured player foundation are preserved but are not yet connected to this new game experience. No database migration or production data change was made.
- Deployment: not yet triggered; this branch is not deployed to GitHub Pages.


### 2026-11-18 — First CI feedback and correction

- Initial PR #18 validation run `44337798673` found a JavaScript syntax error in the preview wallet updater (an extra closing parenthesis).
- Corrected the syntax in `app.js`; rerun validation is required before merge.
- The initial CI run stopped at the syntax check, so DOM-entry, migration-contract, and whitespace checks did not run in that attempt.
- PR #18 remains open and unmerged. No deployment has been triggered.


### 2026-11-18 — New world-simulation foundation merged

- PR #18: https://github.com/powerx911/NOVA/pull/18 — **merged** (squash).
- Merge commit: `994880276e5a734dcb8f8a9ce752f754b5e33324`.
- The initial CI attempt `44337798673` correctly caught an extra closing parenthesis in `app.js`. The error was fixed and recorded in the feature branch before merge.
- Final validation run `44337925860` — **success**. JavaScript syntax, new UI entry points, existing server-authoritative player migration contract, and patch whitespace all passed.
- GitHub Pages deployment run `44338016649` — **success**. Setup Pages, artifact upload (67,468 bytes), and Deploy to GitHub Pages all passed. GitHub Actions reported the environment URL https://powerx911.github.io/NOVA/. Independent HTTP/browser and real Android device verification remain outstanding.
- The new UI interactions remain a local browser preview. No live multiplayer, player accounts, shared economy, realtime chat, or authoritative conflict simulation is connected yet.
- Existing Supabase project, RLS-protected player foundation, and GitHub Pages infrastructure were preserved. No production data or secrets were changed.



### 2026-11-18 — Mobile-first competitive simulation prototype

- Reframed the client around the owner's clarified product constraints: portrait mobile game, UI-and-number-driven simulation, direct competition between players, and **no world map or open-world character presentation**.
- Replaced the previous sector/city simulation presentation with an original command-center and operations experience. Navigation and screen taxonomy were redesigned independently rather than copying the reference example's labels or tab count.
- Added command metrics, event/activity surfaces, competitive challenges, asset/inventory management, market presentation, player rankings, organization entry points, and profile/settings surfaces.
- Added thumb-oriented bottom navigation, translucent layered panels, touch feedback, optional short vibration where supported, safe-area padding, keyboard focus styles, and reduced-motion support.
- Local interactions remain explicitly demo-only; no live player, server economy, market, rankings, alliance, or combat API is claimed or connected by this change.
- Files changed: `index.html`, `styles.css`, `app.js`, `README.md`, `PROJECT_STATUS.md`.
- Branch: `feature/nova-mobile-competitive-prototype`.
- Validation planned: JavaScript syntax check, HTML structure/ID wiring review, responsive/CSS review, diff whitespace check, and configured GitHub Actions checks. Real Android device verification remains outstanding.
- Backend: existing Supabase project and player foundation preserved; no database migration or production data mutation in this change.
- Deployment: not deployed from this branch. Deployment verification is required after merge.

- Added a lightweight GitHub Actions validation workflow for JavaScript syntax, UI selector wiring, navigation targets, mobile viewport metadata, map-free presentation, and whitespace. Its first PR run is pending.

- Local source validation completed in the development session: JavaScript parsed successfully; HTML IDs are unique; all literal JavaScript ID selectors resolve; all navigation targets have matching screens; no map UI markers remain. These checks were performed against the branch contents. GitHub Actions has not yet reported a run for this PR, so CI is not marked passed.


## 24. NOVA competitive online foundation — implementation in progress (2026-11-18)

- Extended PR #20 on branch `feature/nova-mobile-competitive-prototype` from the latest main with the first real online account/gameplay foundation.
- Added Supabase email/password sign-up and sign-in using the public publishable key and pinned `@supabase/supabase-js@2.119.0` browser import. No service-role or secret key is exposed.
- Added a competitive core migration proposal: player profiles, server-owned wallets, player assets, idempotent command receipts, resource ledger, and a public activity feed. All tables have RLS enabled; direct client writes to wallets/assets/ledger/commands are not granted.
- Added private SECURITY DEFINER implementations with public SECURITY INVOKER wrappers for player initialization, operation simulation, asset upgrades, and a safe public leaderboard. Server commands validate auth ownership, use transaction locks and per-user command IDs, update balances atomically, and write audit entries.
- Enabled Realtime publication for public activity inserts; client subscribes to activity changes and refreshes the activity feed/leaderboard.
- Connected the client to persistent account, wallet, asset, operation, leaderboard, and activity data. Guest mode remains read-only; market purchases, challenges, organizations, and matchmaking are explicitly not represented as live yet.
- Added a migration security-contract test and replaced obsolete CI checks that still expected the retired map/castle prototype. The first PR #20 run had failed only because that legacy workflow searched for old `view-world` and map-based IDs; the current branch replaces those checks with current map-free UI and migration checks.
- Files changed: `index.html`, `styles.css`, `app.js`, `supabase/migrations/20261118170000_nova_competitive_core.sql`, `scripts/check-competitive-migration.mjs`, `.github/workflows/prototype-checks.yml`, `README.md`, and this status log.
- **Not yet done:** the migration has not been applied to the live Supabase database; email-confirmation redirect configuration is not verified; real account creation, two-player isolation, idempotency, Realtime delivery, Android device behavior, and Pages deployment are not yet verified.
- Do not merge until CI passes. After merge, apply the migration, verify RLS/advisors and RPCs, run account/command integration tests, and confirm the GitHub Pages deployment.


## 25. Competitive online core activated on Supabase (2026-11-18)

- PR #20 merged successfully (squash) as `fc52f0420072d6a6484170a71204b34dd09f0a6a`. It includes the map-free mobile UI, Supabase auth client, competitive core migration, server-authoritative RPCs, live public activity, and updated CI checks.
- Both PR checks passed on the final PR head `28769698b8610a44cca7238ce5f7c23b609453d0`: NOVA Prototype Checks run 44343056228 and Validate NOVA run 44343057734.
- The competitive migration was applied to the existing Supabase project `hmrprnjhyzyefocdmnxf` as migration version `20261118160528` (`nova_competitive_core`). No existing tables or player data were deleted or modified.
- Verified all six new competitive tables exist with RLS enabled. The new competitive tables currently contain zero player rows; no player accounts or test data were created.
- Verified wallet access grants: anon cannot read player wallets; authenticated can read only through the RLS policy for their own user_id. Verified public activity is included in `supabase_realtime` publication.
- Verified RPC boundaries: private implementations are SECURITY DEFINER; public wrappers are SECURITY INVOKER. Anonymous execution is denied for initialization, simulation, and asset upgrades; anonymous execution is allowed only for the safe leaderboard RPC. Authenticated execution is granted for player commands.
- Supabase security advisors: **zero findings**. Performance advisor currently reports five INFO-level unused indexes across empty ledger/receipt/activity tables; expected before traffic and to be re-evaluated after usage.
- GitHub Pages deployment run 44343113839 completed successfully on main commit `fc52f0420072d6a6484170a71204b34dd09f0a6a`. All deployment steps passed (Setup Pages, artifact upload, Deploy to GitHub Pages). Artifact `github-pages` was 74,196 bytes. Live URL: https://powerx911.github.io/NOVA/.
- External HTTP/browser verification could not be completed from the development environment. The successful GitHub Pages deployment is verified; independent live page rendering and real Android-device testing are still outstanding.
- Account signup/login, email-confirmation redirect configuration, first-player initialization, two-player isolation, operation/upgrade RPCs under real authenticated sessions, and Realtime client delivery have not yet been integration-tested because no test accounts were created. Supabase Auth redirect allowlist must include `https://powerx911.github.io/NOVA/` before email confirmation can return to the Pages client.
- Next implementation priority: complete real-account smoke tests, then build the shared player market with server-owned listings/orders and atomic transfers. Matchmaking/challenges, organizations, season scoring, and broader PvP systems remain subsequent phases.


## 26. Shared player market — implementation in progress (2026-11-18)

- New branch: `feature/nova-shared-player-market` from latest main; PR will add the first true peer-to-peer economy loop.
- Added migration proposal `20261118172000_nova_shared_market.sql` with player inventory, public active listings, market orders, and inventory movement ledger. Starter inventory is seeded through a private database trigger when a player profile is created; existing profiles are safely backfilled.
- Added server-authoritative RPCs for creating listings, partial purchases, and cancelling remaining listings. Each command uses a per-player idempotency key, checks ownership and stock, locks listing/inventory/wallet rows, updates buyer and seller credits atomically, and writes order, inventory-ledger, credit-ledger, and public activity records.
- Public clients can read only active listings. Players can read only their own inventory/orders/ledger. No client-side INSERT/UPDATE/DELETE policies or grants are added for market state.
- Updated the market screen to display actual player offers, quantity controls, create-listing form, purchase and cancellation actions; inventory counts are loaded from the database. Realtime activity inserts refresh the market and player data.
- Added market migration security-contract checks and UI validation for all market controls. CI will verify syntax, IDs/navigation, RLS and RPC security boundaries, idempotency, atomic wallet transfer, and patch whitespace.
- The market migration is **not applied** to Supabase yet; this branch must pass CI and merge first. Existing live competitive tables/data are untouched by this proposal.
- No real player accounts exist yet, so market concurrency, cross-player settlement, partial fills, and realtime UI behavior still require integration tests with two authenticated accounts after migration.


## 27. Market migration activated and FK index follow-up (2026-11-18)

- PR #22 merged as `ad7d5b96cc758d410de0c7aa99e01c0cf09dc1ba`. Both CI checks passed on head `9d5cec458c03e55a505329d8c7ba2f6f8439d1dc`: NOVA Prototype Checks run 44344248773 and Validate NOVA run 44344248481.
- Applied `20261118172000_nova_shared_market.sql` to existing Supabase project `hmrprnjhyzyefocdmnxf`; recorded migration version `20261118161142` (`nova_shared_market`). The market inventory/listing/order/ledger tables exist with RLS enabled; current row counts remain zero because no player accounts have been created.
- Verified anonymous users can read active listings but cannot read player inventory. Authenticated users have SELECT grants constrained by their own-row RLS policies for inventory and orders. Activity Realtime remains enabled.
- Supabase security advisors remain at zero findings. Performance advisors report three INFO-level unindexed foreign keys (listing seller, order listing, inventory-ledger listing), plus unused-index notices while tables are empty.
- Created follow-up branch `perf/nova-market-fk-indexes` with additive indexes for those three foreign keys and CI assertions. This performance-only migration is pending PR review/merge/application.
- GitHub Pages deployment for PR #22 merge commit `ad7d5b96cc758d410de0c7aa99e01c0cf09dc1ba` succeeded in run 44344339762; all five deployment steps passed and the `github-pages` artifact was 80,990 bytes. The published URL is https://powerx911.github.io/NOVA/. External live-browser and Android-device verification remain outstanding.
- No player accounts or test records have been created. Two-account market settlement, partial fills, cancellations, auth email redirect, realtime delivery, and Android testing remain outstanding.
