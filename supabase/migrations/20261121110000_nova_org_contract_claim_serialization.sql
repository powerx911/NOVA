-- Serialize claims for the same organization-contract member before the
-- partial unique index is checked. This also covers concurrent claims made
-- through different RPC paths, not only accept_dynamic_contract().
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
  end if;

  return new;
end;
$$;

revoke all on function nexora.lock_active_org_contract_claim() from public, anon, authenticated;

drop trigger if exists contract_offers_lock_active_org_claim
  on nexora.contract_offers;

create trigger contract_offers_lock_active_org_claim
before insert or update of scope, claimed_by, status
on nexora.contract_offers
for each row
execute function nexora.lock_active_org_contract_claim();
