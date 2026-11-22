-- Human-readable admin names and consistent feedback status defaults.
alter table public.admin_accounts
  add column if not exists display_name text;

update public.admin_accounts a
set display_name = case
  when a.role = 'owner' then 'MJNON'
  else coalesce(nullif(split_part(u.email, '@', 1), ''), 'مشرف')
end
from auth.users u
where u.id = a.user_id
  and (a.display_name is null or btrim(a.display_name) = '');

alter table public.admin_accounts
  alter column display_name set default 'مشرف',
  alter column display_name set not null;

-- Keep inserts and status transitions aligned with the allowed states.
alter table nexora.player_feedback
  alter column status set default 'open';

update nexora.player_feedback
set status = 'open'
where status = 'new';

-- Admin Center updates player feedback statuses through the service-role Edge Function.
grant select, update on nexora.player_feedback to service_role;
