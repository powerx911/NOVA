-- Recheck the active-claim invariant after acquiring the member lock.
-- The second concurrent request must return the domain error, not reach the
-- partial unique index and surface SQLSTATE 23505.
create or replace function nexora.lock_active_org_contract_claim()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.scope = 'organization'
     and new.claimed_by is not null
     and new.status in ('accepted', 'processing', 'ready') then
    perform pg_catalog.pg_advisory_xact_lock(
      724190,
      pg_catalog.hashtext(new.claimed_by)
    );

    if exists (
      select 1
      from nexora.contract_offers active_offer
      where active_offer.scope = 'organization'
        and active_offer.claimed_by = new.claimed_by
        and active_offer.status in ('accepted', 'processing', 'ready')
        and active_offer.id <> new.id
    ) then
      raise exception 'ORG_ACTIVE_CONTRACT_LIMIT';
    end if;
  end if;

  return new;
end;
$$;
