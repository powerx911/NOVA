create or replace function nexora.list_direct_conversations(p_user_id text)
returns jsonb language sql security definer set search_path=nexora,pg_temp as $$
 select jsonb_build_object('conversations',coalesce(jsonb_agg(jsonb_build_object(
  'id',c.id,'participants',c.participants,'participantNames',c.participant_names,
  'participantAvatars',c.participant_avatars,'lastMessage',c.last_message,
  'lastMessageAt',c.last_message_at,'lastSenderUid',c.last_sender_uid
 ) order by c.last_message_at desc),'[]'::jsonb))
 from (select * from conversations where p_user_id=any(participants) order by last_message_at desc limit 50) c
$$;
revoke all on function nexora.list_direct_conversations(text) from public,anon,authenticated;
grant execute on function nexora.list_direct_conversations(text) to service_role;
