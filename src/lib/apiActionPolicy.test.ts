import { describe, expect, it } from 'vitest';
import { shouldDispatchGameRefresh } from './apiActionPolicy';

describe('game refresh action policy', () => {
  it.each([
    'fetch_market_listings',
    'fetch_inventory_capacity_usage',
    'fetch_market_activity',
    'fetch_market_price_history',
    'fetch_company_auctions',
    'list_organization_chat_messages',
    'fetch_nexora_daily_sales',
    'bootstrap',
  ])('does not trigger a full game refresh for read-only action %s', (action) => {
    expect(shouldDispatchGameRefresh(action)).toBe(false);
  });

  it.each([
    'create_market_listing',
    'buy_market_listing',
    'cancel_market_listing',
    'sell_to_nexora',
    'buy_missing_resources',
  ])('triggers a game refresh after mutating action %s', (action) => {
    expect(shouldDispatchGameRefresh(action)).toBe(true);
  });

  it('does not trigger a refresh after account deletion', () => {
    expect(shouldDispatchGameRefresh('delete_account')).toBe(false);
  });
});
