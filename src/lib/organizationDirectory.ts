import type { Organization } from '../types/game';

export type OrganizationSort = 'reputation' | 'members' | 'level' | 'treasury';

function getSortValue(organization: Organization, sortBy: OrganizationSort): number {
  switch (sortBy) {
    case 'members': return organization.memberCount;
    case 'level': return organization.level;
    case 'treasury': return organization.treasuryBalance;
    case 'reputation':
    default: return organization.reputation;
  }
}

export function searchAndSortOrganizations(organizations: Organization[], query: string, sortBy: OrganizationSort = 'reputation'): Organization[] {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  return organizations.filter((organization) => {
    if (!normalizedQuery) return true;
    return [organization.name, organization.tag, organization.leaderName, organization.description]
      .some((value) => value.toLocaleLowerCase().includes(normalizedQuery));
  }).sort((a, b) => {
    const difference = getSortValue(b, sortBy) - getSortValue(a, sortBy);
    return difference !== 0 ? difference : a.name.localeCompare(b.name);
  });
}
