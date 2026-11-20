-- Defense in depth for manufacturing jobs and indexes for auction foreign keys.
-- All manufacturing access remains through SECURITY DEFINER RPCs owned by postgres.
alter table nexora.manufacturing_jobs enable row level security;

-- company_auctions has nullable foreign keys to companies and factories.
-- Partial indexes cover all non-null FK values while avoiding entries for nulls.
create index if not exists company_auctions_company_id_idx
  on nexora.company_auctions(company_id)
  where company_id is not null;

create index if not exists company_auctions_factory_id_idx
  on nexora.company_auctions(factory_id)
  where factory_id is not null;
