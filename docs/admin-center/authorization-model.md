# Admin Center Authorization Model

## Decision

Use Supabase Auth for administrator credentials and sessions. Do not create a custom password column or store plaintext passwords, reversible passwords, or client-generated password hashes. Supabase Auth owns password hashing, recovery, and session lifecycle.

Keep administrator authorization in a dedicated database table linked to the Auth user UUID. Game-player accounts are not automatically administrator accounts.

## Roles

- `admin`: may access the admin center and use explicitly granted operational actions.
- `owner`: may access the admin center, use admin actions, and create or disable administrator accounts.
- Exactly one active `owner` is intended. Enforce this in database constraints/transactional server logic, not just in the UI.
- No public administrator sign-up. The initial Owner is provisioned through a one-time, server-side/bootstrap process after the Owner identity is confirmed.

## Proposed private table

Schema: `private` (not exposed through the public Data API).

```sql
create table private.admin_accounts (
  user_id uuid primary key references auth.users(id) on delete restrict,
  role text not null check (role in ('admin', 'owner')),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);
```

The table must have RLS enabled and no direct table grants for browser roles. Access is through server-side endpoints only. A separate partial unique index on `role` where `role = 'owner' and enabled` can enforce at most one enabled Owner; bootstrap and role-change logic must also prevent removing/disabling the final Owner.

## Request authorization

1. Verify the Supabase Auth access token on the server.
2. Read the matching `private.admin_accounts` row server-side and require `enabled = true`.
3. Check the required role/permission for every endpoint; never trust a role sent by the browser or editable user metadata.
4. Require Owner role for administrator account creation. Create the Auth user server-side with the Supabase Admin API, then insert the role row in a transaction-safe workflow. Never expose the service-role/secret key to the browser.
5. Record account creation, disabling, role changes, and privileged actions in an append-only audit log with actor, target, timestamp, reason, and result.
6. Ensure the final active Owner cannot be disabled or demoted. Password reset and session revocation should use Supabase Auth's supported flows.

## Implementation boundary

This document defines the model only. It does not create tables, provision an Owner, change production Auth settings, or enable live admin access. Before implementation, confirm the intended Supabase project and deployment environment; then add a reviewed migration, server-side endpoints, and tests. Do not place credentials in source control or chat.
