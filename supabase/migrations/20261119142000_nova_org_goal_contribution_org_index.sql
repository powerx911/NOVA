-- Cover the organization foreign key used by contribution lookups and deletes.
create index if not exists org_goal_contributions_org_id_idx
  on nexora.org_goal_contributions(org_id);
