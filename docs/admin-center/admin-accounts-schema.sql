-- Reviewed schema draft; do not apply until the target Supabase project is confirmed.
-- Passwords are owned by Supabase Auth; this table contains authorization metadata only.
create table public.admin_accounts (
  user_id uuid primary key references auth.users(id) on delete restrict,
  role text not null check (role in ('admin', 'owner')),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);
create unique index admin_accounts_single_enabled_owner
  on public.admin_accounts (role)
  where role = 'owner' and enabled = true;
alter table public.admin_accounts enable row level security;
revoke all on public.admin_accounts from anon, authenticated;
grant all on public.admin_accounts to service_role;
-- Provision the first Owner only through a trusted, one-time server-side process.
