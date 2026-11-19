import { configDefaults, defineConfig } from 'vitest/config';

// Playwright browser specs are run by the dedicated Playwright runner,
// never by Vitest's unit-test runner.
export default defineConfig({
  test: {
    exclude: [...configDefaults.exclude, 'e2e/**'],
  },
});
