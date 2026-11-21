import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  formatMissionCategory,
  formatOrgRole,
  formatTxType,
} from '../i18n/translations';
import {
  calculateAccruedPayout,
  COMPANY_MAX_LEVEL,
  getAchievementProgress,
  getMissionProgress,
  LISTING_MAX_PRICE,
  LISTING_MAX_QTY,
  sanitizePositiveInt,
} from '../lib/economy';

describe('NEXORA Audit Regression & Security Invariants', () => {
  it('sanitizes positive integers safely and clamps to upper limits', () => {
    expect(sanitizePositiveInt('42.9')).toBe(42);
    expect(sanitizePositiveInt(0, 1)).toBe(1);
    expect(sanitizePositiveInt(-15, 1)).toBe(1);
    expect(sanitizePositiveInt(Number.NaN, 5)).toBe(5);
    expect(sanitizePositiveInt(Number.POSITIVE_INFINITY, 3)).toBe(3);
    expect(sanitizePositiveInt(999_999, 1, LISTING_MAX_QTY)).toBe(LISTING_MAX_QTY);
    expect(sanitizePositiveInt(5_000_000, 1, LISTING_MAX_PRICE)).toBe(LISTING_MAX_PRICE);
  });

  it('guards calculateAccruedPayout against NaN, Infinity, and negative rates', () => {
    const now = Date.now();
    expect(calculateAccruedPayout(-20, now - 3_600_000, now)).toBe(0);
    expect(calculateAccruedPayout(100, Number.NaN, now)).toBe(0);
    expect(calculateAccruedPayout(100, now - 3_600_000, Number.POSITIVE_INFINITY)).toBe(0);
    expect(calculateAccruedPayout(100, now + 10_000, now)).toBe(0);
  });

  it('computes unified mission & achievement progress across all metrics', () => {
    const sampleProfile = {
      level: 4,
      reputation: 85,
      orgId: 'org_123',
      stats: {
        tradesCount: 7,
        companiesOwned: 2,
        totalProduced: 14,
      },
    };

    expect(getMissionProgress('trades', sampleProfile)).toBe(7);
    expect(getMissionProgress('companies', sampleProfile)).toBe(2);
    expect(getMissionProgress('produced', sampleProfile)).toBe(14);
    expect(getMissionProgress('level', sampleProfile)).toBe(4);
    expect(getMissionProgress('org', sampleProfile)).toBe(1);
    expect(getMissionProgress('org', { ...sampleProfile, orgId: null })).toBe(0);

    expect(getAchievementProgress('reputation', sampleProfile)).toBe(85);
    expect(getAchievementProgress('produced', sampleProfile)).toBe(14);
  });

  it('exposes consistent progression and listing ceiling constants', () => {
    expect(COMPANY_MAX_LEVEL).toBe(100);
    expect(LISTING_MAX_QTY).toBe(250);
    expect(LISTING_MAX_PRICE).toBe(1_000_000);
  });

  it('localizes transaction types, mission categories, and org roles in Arabic and English', () => {
    expect(formatTxType('company_hire', 'ar')).toBe('توظيف كوادر');
    expect(formatTxType('company_hire', 'en')).toBe('Staff Hire');
    expect(formatMissionCategory('weekly', 'ar')).toBe('أسبوعية');
    expect(formatMissionCategory('weekly', 'en')).toBe('Weekly');
    expect(formatOrgRole('leader', 'ar')).toBe('القائد');
    expect(formatOrgRole('deputy', 'en')).toBe('Deputy');
  });

  it('verifies hardened Firestore rules security invariants', () => {
    const rulesPath = path.resolve(process.cwd(), 'firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    // No open allow list for any signed-in user
    expect(rules).not.toMatch(/allow\s+list\s*:\s*if\s+isSignedIn\(\)\s*;/);

    // Employee hiring has been removed; timed company and vault upgrades remain supported.
    expect(rules).not.toContain("'company_hire'");
    expect(rules).toContain("'levelUpgradeStartedAt'");
    expect(rules).toContain("'levelUpgradeEndsAt'");
    expect(rules).toContain("'vaultUpgradeStartedAt'");
    expect(rules).toContain("'vaultUpgradeEndsAt'");

    // Market buy fee cap and order receipt verification
    expect(rules).toContain('tx.fee <= (tx.amount * 0.12) + 0.5');
    expect(rules).toContain('incoming().txId == walletNewTxId(request.auth.uid)');
    expect(rules).toContain("newWalletTx(request.auth.uid).type == 'market_buy'");

    // Org join request listing restricted to applicant or manage_members
    expect(rules).toContain("resource.data.status == 'pending' && hasOrgPermission(resource.data.orgId, 'manage_members')");

    // Diagnostics admins strictly locked against client writes or listing
    expect(rules).toContain('allow list, create, update, delete: if false;');
  });

  it('ensures no firebase-admin SDK or private keys appear in client source code', () => {
    const srcRoot = path.resolve(process.cwd(), 'src');
    const files: string[] = [];
    function walk(dir: string) {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          if (entry.name !== 'tests') walk(full);
        } else if (/\.(ts|tsx)$/.test(entry.name)) {
          files.push(full);
        }
      }
    }
    walk(srcRoot);

    for (const file of files) {
      const content = fs.readFileSync(file, 'utf8');
      expect(content).not.toContain('firebase-admin');
      expect(content).not.toContain('BEGIN PRIVATE KEY');
    }
  });
});
