import { describe, expect, it } from 'vitest';
import { searchAndSortOrganizations } from '../lib/organizationDirectory';
import type { Organization } from '../types/game';

const org = (id: string, name: string, tag: string, leaderName: string, description: string, treasuryBalance: number, memberCount: number, reputation: number, level: number): Organization => ({ id, name, tag, leaderName, description, treasuryBalance, memberCount, reputation, level, leaderUid: 'u' + id, createdAt: null, updatedAt: null });
const organizations = [org('1','North Star','NST','Rami','Trade guild',500,8,120,3), org('2','Red Horizon','RHD','Salem','Builders',900,15,90,5), org('3','Blue Orbit','BLU','Nora','Trade and logistics',200,4,180,2)];

describe('organization directory discovery', () => {
  it('searches names, tags, leaders and descriptions without case sensitivity', () => {
    expect(searchAndSortOrganizations(organizations, 'blu')).toHaveLength(1);
    expect(searchAndSortOrganizations(organizations, 'SALEM')[0].id).toBe('2');
    expect(searchAndSortOrganizations(organizations, 'logistics')[0].id).toBe('3');
  });
  it('sorts by reputation by default', () => expect(searchAndSortOrganizations(organizations, '').map(x => x.id)).toEqual(['3','1','2']));
  it('supports member, level and treasury ranking', () => {
    expect(searchAndSortOrganizations(organizations, '', 'members')[0].id).toBe('2');
    expect(searchAndSortOrganizations(organizations, '', 'level')[0].id).toBe('2');
    expect(searchAndSortOrganizations(organizations, '', 'treasury')[0].id).toBe('2');
  });
  it('returns no results for unmatched queries', () => expect(searchAndSortOrganizations(organizations, 'missing')).toEqual([]));
});
