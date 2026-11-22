-- Support tickets, free-form player reports, and private image attachments.
alter table nexora.player_reports drop constraint if exists player_reports_reason_check;
alter table nexora.player_reports add column if not exists message text;
alter table nexora.player_reports add column if not exists attachment_paths text[] not null default '{}';
alter table nexora.player_feedback add column if not exists attachment_paths text[] not null default '{}';

create table if not exists nexora.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  subject text not null check (char_length(btrim(subject)) between 3 and 120),
  status text not null default 'open' check (status in ('open','claimed','closed')),
  claimed_by uuid references auth.users(id) on delete set null,
  claimed_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists support_tickets_user_created_idx on nexora.support_tickets(user_id, created_at desc);
create index if not exists support_tickets_status_updated_idx on nexora.support_tickets(status, updated_at desc);

create table if not exists nexora.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references nexora.support_tickets(id) on delete cascade,
  sender_type text not null check (sender_type in ('player','admin')),
  sender_id text not null,
  message text not null check (char_length(btrim(message)) between 1 and 3000),
  attachment_paths text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists support_ticket_messages_ticket_created_idx on nexora.support_ticket_messages(ticket_id, created_at asc);

alter table nexora.support_tickets enable row level security;
alter table nexora.support_ticket_messages enable row level security;
revoke all on nexora.support_tickets, nexora.support_ticket_messages from public, anon, authenticated;
grant select, insert, update, delete on nexora.support_tickets, nexora.support_ticket_messages to service_role;

create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('player-support-attachments','player-support-attachments',false,3145728,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=3145728,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
