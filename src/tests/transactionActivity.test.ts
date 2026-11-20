import { describe, expect, it } from 'vitest';
import { formatTxDescription, formatTxType, isVisibleActivityType } from '../i18n/translations';

describe('recent activity formatting', () => {
  it('hides technical operating and reversal entries', () => {
    expect(isVisibleActivityType('factory_operating')).toBe(false);
    expect(isVisibleActivityType('company_upgrade_refund_reversal')).toBe(false);
    expect(isVisibleActivityType('company_collect')).toBe(true);
  });

  it('uses Arabic descriptions instead of raw backend text', () => {
    expect(formatTxDescription('Factory operating costs: Alpha', 'factory_operating', 'ar')).toBe('');
    expect(formatTxDescription('Company revenue collected: Alpha', 'company_collect', 'ar')).toBe('تحصيل إيرادات الشركة');
    expect(formatTxDescription('Started upgrade to Lv.13', 'company_upgrade', 'ar')).toBe('ترقية الشركة إلى المستوى 13');
    expect(formatTxType('game_compensation', 'ar')).toBe('تعويض عن مشكلة سابقة');
  });
});
