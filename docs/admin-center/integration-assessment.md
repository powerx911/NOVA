# Admin Center Integration Assessment

Reviewed against the current `main` tree on 2026-11-22.

## Confirmed current state

- `api/game-feedback.ts` accepts authenticated player feedback and sends it to a fixed email destination through Resend. It supports only `issue` and `suggestion`; it does not persist submissions for an admin queue.
- `supabase/functions/nova-control/index.ts` is explicitly retired and responds with HTTP 410. It is not an admin API.
- `PROJECT_STATUS.md` identifies Firebase Authentication as identity, Supabase PostgreSQL (`nexora`) as authoritative game/economy storage, and `nexora-api` as the deployed Firebase-token-verifying API boundary.
- The existing GitHub Pages workflow publishes the player app's static `dist`; it does not deploy `api/*` server handlers.

## Consequences

1. A durable reports inbox requires a new server-side persistence path and a reviewed data model; the current email delivery cannot provide searchable report status/history.
2. Admin authentication and authorization must be added explicitly. The retired `nova-control` endpoint provides no authorization behavior to reuse.
3. The console needs its own build/deployment target or a deliberately configured multi-app build. It must not be assumed to be live merely because files are added to this repository.
4. Currency adjustments and moderation actions need reviewed server-side operations with immutable audit records. No production schema or data is changed in this foundation branch.

## Immediate implementation work

- Inspect the deployed `nexora-api` action router, database moderation/audit schema, and report-related migrations.
- Decide and document the admin role source and permission model before creating protected endpoints.
- Add the isolated console UI and testable API contracts, then implement the persistence and actions against disposable test data.
