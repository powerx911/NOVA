-- A leading bid reserves a purchase opportunity: while it remains highest, founding is paused.
create or replace function nexora.enforce_company_capacity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owned integer; v_reserved integer;
begin
  perform 1 from nexora.player_profiles where user_id=new.owner_uid for update;
  select count(*) into v_owned from nexora.companies where owner_uid=new.owner_uid and is_deleted=false;
  select count(*) into v_reserved from nexora.company_auctions
    where highest_bidder_uid=new.owner_uid and status='active';
  if v_reserved > 0 then raise exception 'COMPANY_AUCTION_PENDING'; end if;
  if v_owned >= 3 then raise exception 'COMPANY_CAPACITY_REACHED'; end if;
  return new;
end;
$$;
revoke all on function nexora.enforce_company_capacity() from public,anon,authenticated;
