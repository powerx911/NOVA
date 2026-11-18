create unique index if not exists organization_requests_one_pending_per_user_org
on nexora.organization_requests(org_id, user_id)
where status = 'pending';
