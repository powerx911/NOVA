-- Store authenticated in-game issue reports and suggestions.
create table if not exists nexora.player_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  feedback_type text not null check (feedback_type in ('issue', 'suggestion')),
  message text not null check (char_length(btrim(message)) between 10 and 3000),
  status text not null default 'new' check (status in ('new', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);
create index if not exists player_feedback_created_at_idx
  on nexora.player_feedback (created_at desc);
create index if not exists player_feedback_user_id_idx
  on nexora.player_feedback (user_id, created_at desc);
alter table nexora.player_feedback enable row level security;
revoke all on table nexora.player_feedback from anon, authenticated;
grant insert, select on table nexora.player_feedback to service_role;
