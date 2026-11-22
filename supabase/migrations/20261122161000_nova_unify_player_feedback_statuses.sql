alter table nexora.player_feedback drop constraint if exists player_feedback_status_check;
update nexora.player_feedback set status=case status when 'new' then 'open' when 'resolved' then 'closed' when 'dismissed' then 'closed' else status end;
alter table nexora.player_feedback add constraint player_feedback_status_check check (status in ('open','reviewing','closed'));
