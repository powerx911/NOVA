-- Allow the admin-center Edge Function's service_role to write game-admin messages.
-- Keep privileges scoped to the two conversation tables and required operations.
GRANT SELECT, INSERT, UPDATE ON TABLE nexora.conversations TO service_role;
GRANT INSERT ON TABLE nexora.conversation_messages TO service_role;
