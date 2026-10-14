import { defineConfig, devices } from '@playwright/test'

// Browser tests (#157). Run by run.sh inside the tests container, against the e2e compose stack.
const baseURL = process.env.E2E_BASE_URL ?? 'https://localhost'

export default defineConfig({
  testDir: './tests',
  // One stack, one database: tests that edit content must not run against each other.
  workers: 1,
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  // Every limit is bounded: Playwright's navigation and action defaults never time out.
  timeout: 90_000,
  expect: { timeout: 10_000 },
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
  ],
  use: {
    baseURL,
    // Caddy's internal certificate for localhost, and the storage emulator's self-signed one.
    ignoreHTTPSErrors: true,
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
})
