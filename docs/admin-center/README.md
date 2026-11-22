# NOVA Admin Center — Foundation

## Goal

Build an internal moderator/admin console for NOVA in this repository, from a clean implementation rather than reviving the old console. The player-facing game remains separate from the admin interface.

## Current architecture to integrate with

- Player identity is Firebase Authentication.
- Authoritative game/economy data is Supabase PostgreSQL in schema `nexora`.
- The deployed `nexora-api` Edge Function verifies Firebase ID tokens and uses a server-side service-role client.
- The GitHub Pages workflow publishes the root Vite app only; `api/*` is not deployed by that workflow.

The admin center must use the existing trusted API boundary or a separately deployed server-side boundary. It must never access Supabase service-role credentials from browser code.

## Security invariants

1. Require a verified Firebase identity and a server-side admin role/permission check on every protected request. Hiding routes or controls in the UI is not authorization.
2. Use least-privilege permissions for moderation, report review, and economy adjustments; do not grant every operator every capability by default.
3. Record an append-only audit event for each successful or rejected privileged action, including actor, target, action, reason, timestamp, and request/correlation ID where available.
4. Require an explicit reason for moderation and currency adjustments. Validate amount, target, duration, and allowed action on the server.
5. Never accept actor identity, permission level, or balance delta as trusted client assertions.
6. Do not expose service-role keys or privileged database RPCs to the browser.
7. Keep admin-center rollout separate from the public game release. Do not deploy or alter production data as part of initial development.

## Initial product scope

- Review public/general reports and suggestions submitted from game Settings.
- Review player-targeted reports.
- Search/select a player and view only the minimum data needed for moderation.
- Apply temporary/permanent bans and timeouts, with reason and duration where applicable.
- Make controlled currency adjustments through a server-validated, audited operation.
- Provide searchable report/moderation/action history with status and operator attribution.

## Delivery sequence

1. Map the existing report submission, player identity, moderation, and wallet interfaces; identify the authoritative tables/RPCs and current authorization model.
2. Add the admin UI as a separately built app under this repository, with no production access by default.
3. Implement and test server-side authorization, audit logging, and narrowly scoped endpoints/RPCs.
4. Add integration tests using disposable test identities/data and verify unauthorized requests fail.
5. Review the PR and CI results before any deployment or production integration.

## Not in scope for the foundation

- Direct edits to production wallets or player records.
- A public admin URL without server-side authentication and authorization.
- Production deployment, migrations, or enabling admin permissions.
