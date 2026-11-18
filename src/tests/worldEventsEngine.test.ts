import { describe, expect, it } from 'vitest';
import {
  buildWorldEventRotationPlan,
  SERVER_WORLD_EVENT_TEMPLATES,
  type ExistingWorldEventRecord,
} from '../../functions/src/worldEventsEngine';

const HOUR = 3_600_000;

describe('NEXORA world event rotation engine', () => {
  it('activates up to the requested cap with unique stack groups', () => {
    const plan = buildWorldEventRotationPlan([], 48 * HOUR, 3);
    expect(plan.toDeactivateIds).toEqual([]);
    expect(plan.toActivate).toHaveLength(3);
    expect(new Set(plan.toActivate.map((event) => event.template.stackGroup)).size).toBe(3);
    expect(plan.toActivate.every((event) => event.startsAtMs === 48 * HOUR)).toBe(true);
  });

  it('clamps requested active event count to the supported range', () => {
    expect(buildWorldEventRotationPlan([], 0, 0).toActivate).toHaveLength(1);
    expect(buildWorldEventRotationPlan([], 0, 99).toActivate).toHaveLength(3);
  });

  it('deactivates events exactly at their expiry boundary', () => {
    const now = 10 * HOUR;
    const events: ExistingWorldEventRecord[] = [
      { id: 'evt_silicon_boom', active: true, stackGroup: 'sector_tech', endsAtMs: now },
    ];
    const plan = buildWorldEventRotationPlan(events, now, 1);
    expect(plan.toDeactivateIds).toContain('evt_silicon_boom');
    expect(plan.toActivate).toHaveLength(1);
    expect(plan.toActivate[0].template.id).not.toBe('evt_silicon_boom');
  });

  it('preserves valid active events and fills only vacant slots', () => {
    const now = 100 * HOUR;
    const events: ExistingWorldEventRecord[] = [
      { id: 'evt_silicon_boom', active: true, stackGroup: 'sector_tech', endsAtMs: now + HOUR },
    ];
    const plan = buildWorldEventRotationPlan(events, now, 3);
    expect(plan.toDeactivateIds).toEqual([]);
    expect(plan.toActivate).toHaveLength(2);
    expect(plan.toActivate.some((event) => event.template.id === 'evt_silicon_boom')).toBe(false);
  });

  it('removes duplicate stack groups and enforces the active cap', () => {
    const now = 200 * HOUR;
    const events: ExistingWorldEventRecord[] = [
      { id: 'evt_silicon_boom', active: true, stackGroup: 'shared', endsAtMs: now + HOUR },
      { id: 'evt_tax_holiday', active: true, stackGroup: 'shared', endsAtMs: now + HOUR },
      { id: 'evt_logistics_boom', active: true, stackGroup: 'logistics', endsAtMs: now + HOUR },
      { id: 'evt_industrial_surge', active: true, stackGroup: 'industry', endsAtMs: now + HOUR },
    ];
    const plan = buildWorldEventRotationPlan(events, now, 2);
    expect(plan.toDeactivateIds).toEqual(['evt_tax_holiday', 'evt_industrial_surge']);
    expect(plan.toActivate).toHaveLength(0);
  });

  it('assigns each activated event its configured duration', () => {
    const now = 300 * HOUR;
    const plan = buildWorldEventRotationPlan([], now, 3);
    for (const activation of plan.toActivate) {
      expect(activation.endsAtMs - activation.startsAtMs).toBe(
        activation.template.durationHours * HOUR
      );
    }
  });

  it('never activates an event whose stack group is already occupied', () => {
    const now = 400 * HOUR;
    const active = SERVER_WORLD_EVENT_TEMPLATES[0];
    const plan = buildWorldEventRotationPlan(
      [{ id: active.id, active: true, stackGroup: active.stackGroup, endsAtMs: now + HOUR }],
      now,
      3
    );
    expect(plan.toActivate.every((event) => event.template.stackGroup !== active.stackGroup)).toBe(true);
  });
});
