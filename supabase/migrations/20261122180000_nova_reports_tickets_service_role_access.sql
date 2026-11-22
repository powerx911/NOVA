-- Restore server-only write access for player reports and enable owner deletion.
-- These tables remain inaccessible to anon/authenticated clients.
grant select, insert, update, delete on table nexora.player_reports to service_role;
grant select, insert, update, delete on table nexora.player_feedback to service_role;
grant select, insert, update, delete on table nexora.support_tickets to service_role;
grant select, insert, update, delete on table nexora.support_ticket_messages to service_role;
