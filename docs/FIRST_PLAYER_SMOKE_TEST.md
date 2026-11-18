# First-player smoke test

The production client is published at https://powerx911.github.io/NOVA/.

## One-time Supabase redirect setting

1. Open the existing NOVA project in the Supabase Dashboard.
2. Go to **Authentication → URL Configuration**.
3. Add this exact URL to **Redirect URLs**: `https://powerx911.github.io/NOVA/`.
4. Save the setting. Do not change the project's Site URL unless the dashboard requires it for your existing auth flow.

## Create two test players

1. Open the Pages URL on a phone.
2. Tap **دخول → حساب جديد**, enter an email you can access, choose a password, and choose a public player name.
3. Open the confirmation email and follow the link. Return to the Pages game and sign in if needed.
4. Repeat with a second email and a different player name on another browser/device.

## Verify the first online loop

- Both players load separate wallets and starter inventory.
- Player A lists some alloy; Player B buys part of the listing; both balances and inventories update.
- Player A cancels the remaining listing; the unsold quantity returns.
- Player A challenges Player B; Player B accepts; both see the same server-generated result.
- Energy decreases on operations/challenges and regenerates over time.
- The leaderboard, market, activity feed, and battle arena refresh without a page reload.

Never share passwords, email confirmation links, or secret keys in chat. If a step fails, share only the visible error message (not private account data).
