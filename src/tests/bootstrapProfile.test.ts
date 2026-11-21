import { describe, expect, it } from 'vitest';
import { normalizeBootstrapProfile } from '../lib/bootstrapProfile';

describe('normalizeBootstrapProfile', () => {
  it('treats missing profiles as no profile', () => {
    expect(normalizeBootstrapProfile(null)).toBeNull();
    expect(normalizeBootstrapProfile(undefined)).toBeNull();
    expect(normalizeBootstrapProfile('profile')).toBeNull();
  });

  it('rejects the mission-counters-only object returned for brand-new accounts', () => {
    expect(normalizeBootstrapProfile({})).toBeNull();
    expect(normalizeBootstrapProfile({ dailyTradesCount: 0, weeklyTradesCount: 0 })).toBeNull();
  });

  it('rejects profiles without a uid or username', () => {
    expect(normalizeBootstrapProfile({ uid: '', username: 'Ada' })).toBeNull();
    expect(normalizeBootstrapProfile({ uid: 'u1', username: '' })).toBeNull();
  });

  it('keeps a real profile unchanged', () => {
    const profile = { uid: 'u1', username: 'Ada', level: 3, skills: {}, stats: {} };
    expect(normalizeBootstrapProfile(profile)).toBe(profile);
  });
});
