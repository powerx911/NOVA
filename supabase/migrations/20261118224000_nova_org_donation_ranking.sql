create or replace function nexora.get_org_donation_ranking(p_org_id text,p_user_id text)
returns jsonb language plpgsql security definer set search_path=nexora,pg_temp as $$
declare v_ranking jsonb;
begin
  if not exists(select 1 from organization_members where org_id=p_org_id and user_id=p_user_id) then raise exception 'UNAUTHORIZED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('uid',q.user_id,'username',q.username,'amount',q.net_amount) order by q.net_amount desc,q.username),'[]'::jsonb)
  into v_ranking
  from (
    select user_id,max(username) as username,
      sum(case when type='deposit' then amount when type='withdraw' then -amount else 0 end)::bigint as net_amount
    from organization_transactions
    where org_id=p_org_id and type in ('deposit','withdraw')
    group by user_id
    having sum(case when type='deposit' then amount when type='withdraw' then -amount else 0 end)>0
  ) q;
  return jsonb_build_object('ranking',v_ranking);
end; $;
revoke all on function nexora.get_org_donation_ranking(text,text) from public,anon,authenticated;
grant execute on function nexora.get_org_donation_ranking(text,text) to service_role;
