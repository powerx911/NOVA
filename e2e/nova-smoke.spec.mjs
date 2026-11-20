import { test, expect } from '@playwright/test';

test('Firebase Auth emulator sign-in → character creation → company founding', async ({ page }) => {
  const baseUrl = process.env.NOVA_E2E_BASE_URL;
  const email = process.env.NOVA_E2E_EMAIL;
  const password = process.env.NOVA_E2E_PASSWORD;
  test.skip(!baseUrl || !email || !password, 'Configure a dedicated isolated NOVA E2E environment and credentials.');

  await page.goto('/');
  await expect(page.getByTestId('auth-email')).toBeVisible({ timeout: 60_000 });
  await page.getByTestId('auth-email').fill(email);
  await page.getByTestId('auth-password').fill(password);
  await page.getByTestId('auth-email-submit').click();

  const createCharacter = page.getByTestId('create-character-submit');
  await page.waitForFunction(
    () => document.querySelector('[data-testid="create-character-submit"]') ||
      document.querySelector('[data-testid="nav-tab-home"]'),
    null,
    { timeout: 60_000 },
  );

  // A fresh disposable account exercises onboarding. Re-runs can reuse the same
  // account after the character exists and continue testing the remaining flow.
  if (await createCharacter.isVisible().catch(() => false)) {
    const username = `novae2e${Date.now().toString().slice(-10)}`;
    await page.locator('#nova-username').fill(username);
    await createCharacter.click();
  }

  await expect(page.getByTestId('nav-tab-home')).toBeVisible({ timeout: 60_000 });
  await page.getByTestId('nav-tab-business').click();
  await page.getByTestId('found-company-start').click();
  const companyName = `NOVA E2E ${Date.now().toString().slice(-8)}`;
  await page.getByTestId('company-name').fill(companyName);
  await page.getByTestId('found-company-submit').click();
  await expect(page.getByText(companyName, { exact: true })).toBeVisible({ timeout: 30_000 });
});
