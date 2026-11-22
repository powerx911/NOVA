-- Allow the server-only Admin Center service role to review and update player reports.
-- The table remains inaccessible to public and authenticated clients.
grant select, update on table nexora.player_reports to service_role;
