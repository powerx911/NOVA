-- RECOVERED HISTORICAL SOURCE — DO NOT AUTO-APPLY
-- Remote migration version: 20261118181827
-- Remote migration name: nexora_org_request_pending_unique
-- Source: Supabase postgres_logs at 2026-11-18 18:18:27 UTC
-- Recovered 2026-11-19. SQL body preserved as logged; migration-history wrapper is intentionally excluded.
-- This archive is outside supabase/migrations/ and is not a deployment instruction.

create unique index if not exists organization_requests_one_pending_per_user_org
on nexora.organization_requests(org_id, user_id)
where status = 'pending';
;
