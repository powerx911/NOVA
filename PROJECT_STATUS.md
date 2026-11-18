# NOVA — Project Status & Engineering Log

> **Purpose:** This is the handover source of truth for any developer or AI agent continuing NOVA. Read this file before making changes, then inspect the repository and GitHub Actions for the live state. Update this file in the same change as every project change.

**Last verified/updated:** 2026-11-18  
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
| Static hosting target | GitHub Pages (workflow exists; activation/deployment not yet verified) |
| Backend platform | Supabase |
| Supabase project | `NOVA` |
| Supabase project ref | `hmrprnjhyzyefocdmnxf` |
| Supabase URL | `https://hmrprnjhyzyefocdmnxf.supabase.co` |
| Supabase region | `eu-west-1` |
| Control service | Supabase Edge Function `nova-control` (deployment pending verification) |
| Vercel | **Not used.** The project owner explicitly requires GitHub-based source control, integration, and deployment; do not introduce Vercel. |

The user has requested an online-first competitive multiplayer game foundation before choosing the final game genre, setting, camera, or engine. Prepare and document the social, alliance, economy, war, security, and delivery requirements first; do not lock the final game category or begin the playable implementation prematurely.

---

## 3. Current repository inventory

Known files on `main` as of this baseline:

- `README.md` — project overview and current online multiplayer scope.
- `.gitignore` — ignored files.
- `index.html` — temporary/static placeholder.
- `.github/workflows/pages.yml` — GitHub Pages deployment workflow; Pages enablement and a successful live deployment have not yet been confirmed.
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

The repository API snapshot previously showed `has_pages: false`. Therefore Pages enablement and the first Pages deployment are not confirmed.

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
| First `deploy-nova-control.yml` run | **Pending** | User was asked to manually run it once on `main`; no successful run result has yet been confirmed. |
| Supabase Edge Function deployment | **Unverified** | Check GitHub Actions run and Supabase function list/deployed version. |
| MCP health endpoint | **Untested** | Verify HTTP health response after deployment. |
| MCP protocol/tool calls | **Untested** | Test authenticated MCP connection and each required tool safely. |
| GitHub Pages enabled | **Pending** | `has_pages: false` appeared in an earlier repository snapshot. |
| First Pages deployment | **Unverified** | Check Pages settings, workflow run, and live URL. |
| Automated branch/PR/test/merge/deploy lifecycle | **Process agreed; not yet fully validated** | Follow the mandatory lifecycle in section 1 for every future change. |
| Game implementation | **Not started** | Current work is foundation preparation only. Complete the online-first requirements and technical evaluation before selecting the final game presentation or starting the playable slice. The user has delegated ordinary product/engineering decisions; do not ask for technical choices that can be resolved by research. |

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
