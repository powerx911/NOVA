import { describe, expect, it } from 'vitest';
import { getMissionPeriodKey } from '../lib/missionPeriods';

describe('Recurring mission periods', () => {
  it('keys daily trader claims by UTC calendar day', () => {
    expect(getMissionPeriodKey('daily_active_trader', new Date('2026-11-19T23:59:00.000Z'))).toBe('2026-11-19');
    expect(getMissionPeriodKey('daily_active_trader', new Date('2026-11-20T00:01:00.000Z'))).toBe('2026-11-20');
  });

  it('keys weekly missions by ISO week across year boundaries', () => {
    expect(getMissionPeriodKey('weekly_real_estate', new Date('2026-12-31T12:00:00.000Z'))).toBe('2026-W53');
    expect(getMissionPeriodKey('weekly_real_estate', new Date('2027-01-04T12:00:00.000Z'))).toBe('2027-W01');
  });

  it('keys seasonal missions by calendar quarter', () => {
    expect(getMissionPeriodKey('seasonal_syndicate', new Date('2026-03-31T23:00:00.000Z'))).toBe('2026-Q1');
    expect(getMissionPeriodKey('seasonal_syndicate', new Date('2026-04-01T00:00:00.000Z'))).toBe('2026-Q2');
  });

  it('keeps tutorial claims lifetime-only', () => {
    expect(getMissionPeriodKey('tut_first_trade', new Date('2026-11-19T00:00:00.000Z'))).toBe('lifetime');
  });
});
