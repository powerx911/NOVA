export const READ_ONLY_ACTIONS = new Set([
  'bootstrap',
  'username_available',
  'fetch_org_pending_requests',
  'fetch_leaderboards',
  'get_public_player_profile',
  'search_players',
  'list_blocked_players',
  'list_direct_conversations',
  'list_direct_messages',
  'list_global_chat_messages',
  'list_organization_invites',
  'get_players_presence',
  'touch_player_presence',
  'get_org_donation_ranking',
  'validate_transfer_recipient',
  'get_dynamic_contract_board',
  'get_org_weekly_goals',
  'get_manufacturing_job',
  'fetch_market_price_history',
  'fetch_nexora_daily_sales',
  'fetch_market_listings',
  'fetch_inventory_capacity_usage',
  'fetch_market_activity',
  'fetch_company_auctions',
  'list_organization_chat_messages',
]);

export function shouldDispatchGameRefresh(action: string): boolean {
  return !READ_ONLY_ACTIONS.has(action) && action !== 'delete_account';
}
