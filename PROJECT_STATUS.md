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

The user is preparing infrastructure first. **Do not start building the game itself until explicitly instructed.**

---

## 3. Current repository inventory

Known files on `main` as of this baseline:

- `README.md` — project overview.
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
| Game implementation | **Not started by instruction** | Wait for explicit user direction. |

### Known risks / checks still required

- The MCP TypeScript/Deno implementation had not yet undergone a confirmed lint, type-check, or integration test at the time of this baseline.
- GitHub token scopes/permissions may be insufficient for Pages or Actions operations; let the workflow/API response identify the exact missing permission.
- Supabase access token permissions may be insufficient for setting Edge Function secrets or deploying functions.
- The MCP access token was previously displayed in the chat history. Treat it as exposed to the conversation history and rotate it to a fresh value after deployment is stable. Never repeat the old value.
- Do not claim autonomous control is fully operational until deployment, authentication, MCP tool calls, and required GitHub actions have been tested successfully.

---

## 8. Change log

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
